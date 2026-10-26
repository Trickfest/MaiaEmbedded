// SPDX-License-Identifier: AGPL-3.0-only
// Experimental API for the cross-platform feasibility harness; not API-stable.
// Encoding/move vocabulary follow pinned CSSLab Maia-3 (see ThirdParty/Maia3).
import ChessCore
import CryptoKit
import Foundation
import OnnxRuntimeBindings

public enum MaiaExperimentError: Error, LocalizedError, Sendable {
    case invalidRequest(String)
    case incompatibleModel(String)
    case notLoaded
    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let message), .incompatibleModel(let message): return message
        case .notLoaded: return "Load the model before requesting inference."
        }
    }
}

public struct MaiaExperimentRequest: Codable, Sendable {
    public var initialFEN: String
    public var moves: [String]
    public var useHistory: Bool
    public var selfRating: Int
    public var opponentRating: Int
    public init(initialFEN: String, moves: [String] = [], useHistory: Bool = false,
                selfRating: Int = 1600, opponentRating: Int = 1600) {
        self.initialFEN = initialFEN; self.moves = moves; self.useHistory = useHistory
        self.selfRating = selfRating; self.opponentRating = opponentRating
    }
}

public struct MaiaExperimentInput: Sendable {
    public let tokens: [Float]
    public let legalMoves: [String]
    public let terminal: Bool
    public let blackToMove: Bool
    public var tokenSHA256: String {
        tokens.withUnsafeBytes { SHA256.hash(data: Data($0)).map { String(format: "%02x", $0) }.joined() }
    }
}

public enum MaiaExperimentEncoding {
    public static func prepare(_ request: MaiaExperimentRequest) throws -> MaiaExperimentInput {
        guard (600...2600).contains(request.selfRating), (600...2600).contains(request.opponentRating) else {
            throw MaiaExperimentError.invalidRequest("Ratings must be in 600...2600.")
        }
        let position = try FENSerializer().validatedPosition(from: request.initialFEN)
        let game = Game(position: position)
        var history = [position]
        for move in request.moves {
            try game.applyLegal(move: move)
            history.append(game.position)
        }
        let boards = request.useHistory ? Array(history.suffix(8)) : [game.position]
        let padded = Array(repeating: boards[0], count: 8 - boards.count) + boards
        var tokens = [Float](repeating: 0, count: 64 * 97)
        let kinds: [PieceKind] = [.pawn, .knight, .bishop, .rook, .queen, .king]
        for (h, board) in padded.enumerated() {
            let black = board.state.turn == .black
            for (square, piece) in board.board.enumeratedPieces() {
                let rank = black ? 7 - square.rank : square.rank
                let modelSquare = rank * 8 + square.file
                let ownColor = black ? piece.color == .black : piece.color == .white
                let channel = kinds.firstIndex(of: piece.kind)! + (ownColor ? 0 : 6)
                tokens[modelSquare * 97 + h * 12 + channel] = 1
            }
        }
        return MaiaExperimentInput(tokens: tokens, legalMoves: game.legalMoves.map(\.description).sorted(),
                                   terminal: game.status.outcome != nil, blackToMove: game.position.state.turn == .black)
    }

    public static func moveIndex(_ uci: String, blackToMove: Bool) throws -> Int {
        let move = try Move(string: uci)
        let fromRank = blackToMove ? 7 - move.from.rank : move.from.rank
        let toRank = blackToMove ? 7 - move.to.rank : move.to.rank
        if let promotion = move.promotion {
            guard fromRank == 6, toRank == 7,
                  let kind = [PieceKind.queen, .rook, .bishop, .knight].firstIndex(of: promotion) else {
                throw MaiaExperimentError.invalidRequest("Invalid promotion vocabulary entry: \(uci)")
            }
            return 4096 + move.from.file * 32 + move.to.file * 4 + kind
        }
        return (fromRank * 8 + move.from.file) * 64 + toRank * 8 + move.to.file
    }

    public static func softmax(_ values: [Float]) throws -> [Double] {
        guard let maximum = values.max(), values.allSatisfy(\.isFinite) else {
            throw MaiaExperimentError.incompatibleModel("Non-finite or empty model output.")
        }
        let weights = values.map { exp(Double($0 - maximum)) }
        let total = weights.reduce(0, +)
        guard total.isFinite, total > 0 else {
            throw MaiaExperimentError.incompatibleModel("Invalid probability distribution.")
        }
        return weights.map { $0 / total }
    }
}

public struct MaiaExperimentPrediction: Codable, Sendable {
    public let terminal: Bool
    public let logits: [String: Float]
    public let probabilities: [String: Double]
    /// Raw value-head order is loss, draw, win for the side to move.
    public let valueLogits: [Float]
    public let outcomeProbabilities: [Double]
    public var topMove: String? {
        probabilities.keys.sorted().max { probabilities[$0]! < probabilities[$1]! }
    }
}

/// Serializes model ownership and inference away from the main actor.
/// Cancellation suppresses results before/after a run; it does not promise to
/// interrupt an ONNX kernel. Unload waits behind an in-flight run.
public actor MaiaExperimentSession {
    public static let modelSHA256 = "3454b03ae78baa64a87b345fdb1a457265d912caec531039b074f07eda0d8010"
    public static let modelByteCount = 316_034_244
    private var environment: ORTEnv?
    private var session: ORTSession?
    public init() {}

    public func load(modelURL: URL) throws {
        try autoreleasepool { try loadWithinPool(modelURL: modelURL) }
    }

    private func loadWithinPool(modelURL: URL) throws {
        try Task.checkCancellation()
        guard session == nil else { return }
        guard modelURL.isFileURL else { throw MaiaExperimentError.invalidRequest("Use a local model URL.") }
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
            throw MaiaExperimentError.incompatibleModel("Model size or SHA-256 does not match the pinned 79M export.")
        }
        let env = try ORTEnv(loggingLevel: .warning)
        let options = try ORTSessionOptions()
        try options.setIntraOpNumThreads(2)
        try options.setGraphOptimizationLevel(.basic)
        let loaded = try ORTSession(env: env, modelPath: modelURL.path, sessionOptions: options)
        guard Set(try loaded.inputNames()) == ["tokens", "self_elo", "opponent_elo"],
              Set(try loaded.outputNames()).isSuperset(of: ["move_logits", "value_logits"]) else {
            throw MaiaExperimentError.incompatibleModel("Unexpected ONNX model schema.")
        }
        try Task.checkCancellation()
        environment = env; session = loaded
    }

    public func unload() { autoreleasepool { session = nil; environment = nil } }

    public func predict(_ request: MaiaExperimentRequest) throws -> MaiaExperimentPrediction {
        try autoreleasepool { try predictWithinPool(request) }
    }

    private func predictWithinPool(_ request: MaiaExperimentRequest) throws -> MaiaExperimentPrediction {
        try Task.checkCancellation()
        guard let session else { throw MaiaExperimentError.notLoaded }
        let input = try MaiaExperimentEncoding.prepare(request)
        if input.terminal {
            try Task.checkCancellation()
            return MaiaExperimentPrediction(terminal: true, logits: [:], probabilities: [:], valueLogits: [], outcomeProbabilities: [])
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
            guard let output = outputs[name] else { throw MaiaExperimentError.incompatibleModel("Missing \(name)") }
            let data = try output.tensorData() as Data
            guard data.count == expected * MemoryLayout<Float>.size else {
                throw MaiaExperimentError.incompatibleModel("Unexpected \(name) tensor size.")
            }
            return data.withUnsafeBytes { bytes in
                (0..<expected).map { bytes.loadUnaligned(fromByteOffset: $0 * 4, as: Float.self) }
            }
        }
        let logits = try floats("move_logits", expected: 4352)
        let values = try floats("value_logits", expected: 3)
        let legalLogits = try input.legalMoves.map { logits[try MaiaExperimentEncoding.moveIndex($0, blackToMove: input.blackToMove)] }
        let probabilities = try MaiaExperimentEncoding.softmax(legalLogits)
        let outcomes = try MaiaExperimentEncoding.softmax(values)
        try Task.checkCancellation()
        return MaiaExperimentPrediction(terminal: false,
            logits: Dictionary(uniqueKeysWithValues: zip(input.legalMoves, legalLogits)),
            probabilities: Dictionary(uniqueKeysWithValues: zip(input.legalMoves, probabilities)),
            valueLogits: values, outcomeProbabilities: outcomes)
    }
}
