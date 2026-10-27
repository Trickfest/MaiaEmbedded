// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import MaiaEmbedded

/// Sanitized, portable evidence for the final package API/UCI verification.
public struct MaiaPackageReport: Codable, Sendable {
    public let schemaVersion: Int
    public let platform: String
    public let hardware: String
    public let runtime: String
    public let startedAt: Date
    public let completedAt: Date
    public let os: String
    public let isSimulator: Bool
    public let modelSHA256: String
    public let referenceCases: Int
    public let maxLogitError: Double
    public let maxProbabilityError: Double
    public let uciRequests: Int
    public let ratings: [MaiaRatingPreview]
    public func write(to url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
public struct MaiaRatingPreview: Codable, Sendable {
    public let rating: Int
    public let opponentRating: Int
    public let moves: [String]
    public let probabilities: [String: Double]
    public let selectedMove: String?
}
public enum MaiaPackageChecks {
    /// Runs sequentially to avoid retaining multiple native models on mobile.
    public static func run(modelURL: URL, uciRequests: Int = 20) async throws -> MaiaPackageReport {
        let started = Date()
        let session = MaiaSession(configuration: .init(modelURL: modelURL))
        var logitError = 0.0, probabilityError = 0.0
        var previews: [MaiaRatingPreview] = []
        let corpus = try ReferenceCorpus.load()
        do {
            try await session.prepare()
            for fixture in corpus.cases {
                try Task.checkCancellation()
                let prediction = try await session.predict(fixture.request)
                let errors = try MaiaBenchmark.check(fixture, prediction: prediction, corpus: corpus)
                logitError = max(logitError, errors.0); probabilityError = max(probabilityError, errors.1)
            }
            let fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
            for rating in [1200, 2000] {
                let request = MaiaRequest(initialFEN: fen, moves: ["e2e4", "e7e5", "g1f3"], useHistory: true,
                                          selfRating: rating, opponentRating: 1600)
                let selection = try await session.selectMove(request, options: .init(seed: 42))
                previews.append(.init(rating: rating, opponentRating: 1600,
                    moves: Array(selection.prediction.rankedMoves.prefix(5)),
                    probabilities: selection.prediction.probabilities, selectedMove: selection.move))
            }
            await session.unload()
            try Task.checkCancellation()
            try await MaiaUCIChecks.run(modelURL: modelURL, iterations: uciRequests)
            try Task.checkCancellation()
        } catch {
            await session.unload(); throw error
        }
        #if targetEnvironment(simulator)
        let simulator = true
        #else
        let simulator = false
        #endif
        #if os(macOS)
        let platform = "macOS"
        #else
        let platform = "iOS/iPadOS"
        #endif
        let hardware = simulator ? ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "simulator" : MaiaBenchmark.hardware()
        return MaiaPackageReport(schemaVersion: 1, platform: platform, hardware: hardware,
            runtime: "ONNX Runtime 1.24.2 CPU; FP32; 2 intra-op threads; basic graph optimization", startedAt: started, completedAt: Date(),
            os: ProcessInfo.processInfo.operatingSystemVersionString, isSimulator: simulator,
            modelSHA256: MaiaSession.modelSHA256, referenceCases: corpus.cases.count,
            maxLogitError: logitError, maxProbabilityError: probabilityError,
            uciRequests: uciRequests, ratings: previews)
    }
}
