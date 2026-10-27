// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import CryptoKit
import OnnxRuntimeBindings

/// Serializes model ownership and inference away from the main actor.
/// Cancellation suppresses results before/after a run; it does not promise to
/// interrupt an ONNX kernel. Unload waits behind an in-flight run.
public actor MaiaSession {
    public static let modelSHA256 = "3454b03ae78baa64a87b345fdb1a457265d912caec531039b074f07eda0d8010"
    public static let modelByteCount = 316_034_244
    private var environment: ORTEnv?
    private var session: ORTSession?
    public typealias Configuration = MaiaConfiguration
    public let configuration: Configuration
    public init(configuration: Configuration) { self.configuration = configuration }
    public var isReady: Bool { session != nil }
    public func prepare() throws { try load(modelURL: configuration.modelURL) }

    private func load(modelURL: URL) throws {
        try translateErrors { try autoreleasepool { try loadWithinPool(modelURL: modelURL) } }
    }

    private func loadWithinPool(modelURL: URL) throws {
        try Task.checkCancellation()
        try configuration.validate()
        guard session == nil else { return }
        guard modelURL.isFileURL else { throw MaiaError.invalidRequest("Use a local model URL.") }
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw MaiaError.modelNotFound
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: modelURL.path)
        guard (attributes[.size] as? NSNumber)?.intValue == Self.modelByteCount else {
            throw MaiaError.incompatibleModel("Model byte count does not match Maia-3 79M.")
        }
        let handle = try FileHandle(forReadingFrom: modelURL)
        defer { try? handle.close() }
        var hash = SHA256()
        var count = 0
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            try Task.checkCancellation()
            hash.update(data: chunk); count += chunk.count
        }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        guard count == Self.modelByteCount, digest == Self.modelSHA256 else {
            throw MaiaError.incompatibleModel("Model size or SHA-256 does not match the pinned 79M export.")
        }
        let env = try ORTEnv(loggingLevel: .warning)
        let options = try ORTSessionOptions()
        try options.setIntraOpNumThreads(Int32(configuration.intraOpThreads))
        try options.setGraphOptimizationLevel(.basic)
        let loaded = try ORTSession(env: env, modelPath: modelURL.path, sessionOptions: options)
        guard Set(try loaded.inputNames()) == ["tokens", "self_elo", "opponent_elo"],
              Set(try loaded.outputNames()).isSuperset(of: ["move_logits", "value_logits"]) else {
            throw MaiaError.incompatibleModel("Unexpected ONNX model schema.")
        }
        try Task.checkCancellation()
        environment = env; session = loaded
    }

    public func unload() { autoreleasepool { session = nil; environment = nil } }

    public func predict(_ request: MaiaRequest) throws -> MaiaPrediction {
        try translateErrors { try autoreleasepool { try predictWithinPool(request) } }
    }

    public func selectMove(_ request: MaiaRequest, options: MaiaSamplingOptions = .init()) throws -> MaiaSelection {
        try options.validate()
        let prediction = try predict(request)
        return try MaiaSampler.select(from: prediction, options: options)
    }

    private func translateErrors<T>(_ body: () throws -> T) throws -> T {
        do { return try body() }
        catch let error as CancellationError { throw error }
        catch let error as MaiaError { throw error }
        catch { throw MaiaError.runtimeFailure(error.localizedDescription) }
    }

    private func predictWithinPool(_ request: MaiaRequest) throws -> MaiaPrediction {
        try Task.checkCancellation()
        guard let session else { throw MaiaError.notLoaded }
        let input = try MaiaEncoding.prepare(request)
        if input.terminal {
            try Task.checkCancellation()
            return MaiaPrediction(terminal: true, logits: [:], probabilities: [:], valueLogits: [], outcomeProbabilities: input.terminalOutcome)
        }
        func tensor<T>(_ values: [T], type: ORTTensorElementDataType, shape: [NSNumber]) throws -> ORTValue {
            let bytes = values.withUnsafeBytes { NSMutableData(bytes: $0.baseAddress!, length: $0.count) }
            return try ORTValue(tensorData: bytes, elementType: type, shape: shape)
        }
        let outputs = try session.run(withInputs: [
            "tokens": tensor(input.tokens, type: .float, shape: [1, 64, 97]),
            "self_elo": tensor([Int64(request.selfRating)], type: .int64, shape: [1]),
            "opponent_elo": tensor([Int64(request.opponentRating)], type: .int64, shape: [1]),
        ], outputNames: ["move_logits", "value_logits"], runOptions: nil)
        func floats(_ name: String, expected: Int) throws -> [Float] {
            guard let output = outputs[name] else { throw MaiaError.incompatibleModel("Missing \(name)") }
            let data = try output.tensorData() as Data
            guard data.count == expected * MemoryLayout<Float>.size else {
                throw MaiaError.incompatibleModel("Unexpected \(name) tensor size.")
            }
            return data.withUnsafeBytes { bytes in
                (0..<expected).map { bytes.loadUnaligned(fromByteOffset: $0 * 4, as: Float.self) }
            }
        }
        let logits = try floats("move_logits", expected: 4352)
        let values = try floats("value_logits", expected: 3)
        let legalLogits = try input.legalMoves.map { logits[try MaiaEncoding.moveIndex($0, blackToMove: input.blackToMove)] }
        let probabilities = try MaiaEncoding.softmax(legalLogits)
        let outcomes = try MaiaEncoding.softmax(values)
        try Task.checkCancellation()
        return MaiaPrediction(terminal: false,
            logits: Dictionary(uniqueKeysWithValues: zip(input.legalMoves, legalLogits)),
            probabilities: Dictionary(uniqueKeysWithValues: zip(input.legalMoves, probabilities)),
            valueLogits: values, outcomeProbabilities: outcomes)
    }
}
