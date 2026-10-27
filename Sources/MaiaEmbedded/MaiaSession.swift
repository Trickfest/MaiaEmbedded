// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import CryptoKit
import OnnxRuntimeBindings

/// Serializes model ownership and inference away from the main actor.
/// Cancellation suppresses results before/after a run; it does not promise to
/// interrupt an ONNX kernel. Unload waits behind an in-flight run.
public actor MaiaSession {
    /// SHA-256 of the single supported Maia-3 79M FP32 ONNX export.
    public static let modelSHA256 = "3454b03ae78baa64a87b345fdb1a457265d912caec531039b074f07eda0d8010"
    /// Expected model file size in bytes, verified before opening the runtime session.
    public static let modelByteCount = 316_034_244
    private var environment: ORTEnv?
    private var session: ORTSession?
    /// Configuration value used to create this session.
    public typealias Configuration = MaiaConfiguration
    /// The immutable configuration snapshot supplied at initialization.
    public let configuration: Configuration
    /// Creates an unloaded session without validating or opening the model.
    ///
    /// - Parameter configuration: A local model URL and CPU thread settings. Each
    ///   prepared session owns a separate native model and its associated memory.
    public init(configuration: Configuration) { self.configuration = configuration }
    /// Whether this actor currently retains a successfully prepared native session.
    public var isReady: Bool { session != nil }
    /// Verifies and loads the pinned model, or reuses the already prepared session.
    ///
    /// Call with `try await` from outside the actor. Validation checks the local file
    /// URL, thread range, byte count, SHA-256 and required ONNX tensor names. Failure
    /// while loading leaves the session unloaded so the asset can be fixed and retried.
    /// - Throws: `MaiaError` for invalid resources/configuration/runtime failures, or
    ///   `CancellationError` at cooperative checkpoints. No download is performed.
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

    /// Releases the native model and permits preparation again with the same configuration.
    ///
    /// Call with `await` from outside the actor. Actor serialization waits for native
    /// work already executing. Cleanup itself does not check task cancellation. Native
    /// allocators may retain pages after unload, so process footprint can stay elevated.
    public func unload() { autoreleasepool { session = nil; environment = nil } }

    /// Predicts legal move likelihoods and human-game outcomes for a validated line.
    ///
    /// - Parameter request: Root FEN, recorded legal moves, history mode and ratings.
    /// - Returns: The original model policy, or a known outcome with an empty policy
    ///   for an automatic terminal position. Preparation is required in either case.
    /// - Throws: `MaiaError` for an unprepared session, invalid input or native/model
    ///   failure; `CancellationError` before or after native work. Cancellation cannot
    ///   interrupt an ONNX kernel. Hosts must reject results for replaced requests.
    public func predict(_ request: MaiaRequest) throws -> MaiaPrediction {
        try translateErrors { try autoreleasepool { try predictWithinPool(request) } }
    }

    /// Predicts once and selects a move using the supplied sampling settings.
    ///
    /// - Parameters:
    ///   - request: Position/history and side-relative conditioning ratings.
    ///   - options: Selection controls; a supplied seed starts a fresh per-call stream.
    /// - Returns: A move with its unchanged prediction and adjusted distribution.
    ///   Terminal positions return a nil move.
    /// - Throws: The validation, model and cancellation errors of `predict(_:)` and
    ///   sampling errors from `MaiaSampler`. To retain an RNG stream, call `predict(_:)`
    ///   then the sampler overload accepting a generator.
    public func selectMove(_ request: MaiaRequest, options: MaiaSamplingOptions = .init()) throws -> MaiaSelection {
        try options.validate()
        let prediction = try predict(request)
        return try MaiaSampler.select(from: prediction, options: options)
    }

    // Preserve cancellation as cancellation so hosts can suppress superseded work
    // without misclassifying it as a model/runtime failure.
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
            // ORT owns the buffer; decoding must not assume Swift Float alignment.
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
