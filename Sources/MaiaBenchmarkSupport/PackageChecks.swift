// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import MaiaEmbedded

/// Portable numeric summary of direct-API and UCI validation checks.
public struct MaiaPackageReport: Codable, Sendable {
    /// JSON report format version.
    public let schemaVersion: Int
    /// Runtime platform name.
    public let platform: String
    /// Generic hardware product identifier or host architecture.
    public let hardware: String
    /// Model precision, runtime version and CPU configuration.
    public let runtime: String
    /// Validation start timestamp.
    public let startedAt: Date
    /// Successful completion timestamp.
    public let completedAt: Date
    /// Operating-system version used for this run.
    public let os: String
    /// Whether the run used a simulator rather than physical hardware.
    public let isSimulator: Bool
    /// SHA-256 of the verified model export.
    public let modelSHA256: String
    /// Number of independently generated reference cases verified.
    public let referenceCases: Int
    /// Largest absolute policy/value-logit error against reference data.
    public let maxLogitError: Double
    /// Largest absolute legal-policy probability error against reference data.
    public let maxProbabilityError: Double
    /// Requested finite UCI operations, separate from stop/restart checks.
    public let uciRequests: Int
    /// Two-rating policy previews generated sequentially from one loaded session.
    public let ratings: [MaiaRatingPreview]
    /// Writes this report atomically as sorted JSON with ISO-8601 dates.
    ///
    /// - Parameter url: Destination file URL; missing parent directories are created.
    /// - Throws: File-system or JSON encoding errors.
    public func write(to url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
/// A rating-conditioned sample and likelihood summary for the shared preview line.
public struct MaiaRatingPreview: Codable, Sendable {
    /// Conditioning rating for the preview position's side to move.
    public let rating: Int
    /// Conditioning rating for the opponent.
    public let opponentRating: Int
    /// Up to five highest-likelihood coordinate-UCI moves, in policy rank order.
    public let moves: [String]
    /// Original probabilities for all legal moves, not just the displayed top five.
    public let probabilities: [String: Double]
    /// Seeded sampled move, which may differ from the top policy candidate.
    public let selectedMove: String?
}
/// Combined direct-API, rating-preview and UCI correctness checks for reference clients.
public enum MaiaPackageChecks {
    /// Checks the reference corpus, previews two ratings and exercises the UCI adapter.
    ///
    /// - Parameters:
    ///   - modelURL: A local pinned model export; no download is performed.
    ///   - uciRequests: Finite UCI operations, from 1 through 100,000; defaults to 20.
    /// - Returns: A completed report, including policy previews and numeric errors.
    /// - Throws: Reference, model, protocol or cancellation errors.
    ///
    /// Direct and UCI sessions run sequentially to avoid overlapping native model
    /// memory. The check unloads its sessions on success and failure. It does not
    /// drive UI or measure interactive responsiveness.
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
