// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import Darwin
import MaiaEmbedded

/// One upstream-generated position, expected encoding and reference prediction.
public struct ReferenceCase: Codable, Sendable {
    /// Stable fixture identifier used in validation diagnostics.
    public let id: String
    /// Six-field root FEN for the recorded line.
    public let initialFEN: String
    /// Legal coordinate-UCI moves replayed from the root.
    public let moves: [String]
    /// Whether this fixture encodes recorded board history.
    public let useHistory: Bool
    /// Conditioning rating for the final side to move.
    public let selfRating: Int
    /// Conditioning rating for the final opposing side.
    public let opponentRating: Int
    /// Expected SHA-256 of the encoded input tensor's FP32 bytes.
    public let tokenSHA256: String
    /// Whether the line has an automatic terminal outcome.
    public let terminal: Bool
    /// Expected coordinate-UCI legal moves in lexical order.
    public let legalMoves: [String]
    /// Expected raw logits for legal policy moves.
    public let logits: [String: Float]
    /// Expected probabilities normalized over legal policy moves.
    public let probabilities: [String: Double]
    /// Expected raw loss/draw/win logits, or an empty array for terminal fixtures.
    public let valueLogits: [Float]
    /// A direct-API request reproducing this fixture's position and ratings.
    public var request: MaiaRequest {
        MaiaRequest(initialFEN: initialFEN, moves: moves, useHistory: useHistory,
                              selfRating: selfRating, opponentRating: opponentRating)
    }
}
/// The bundled, independently generated model-correctness corpus.
public struct ReferenceCorpus: Codable, Sendable {
    /// Fixture format version; the loader supports version 1.
    public let schemaVersion: Int
    /// Pinned upstream Maia source revision used to generate these fixtures.
    public let upstreamRevision: String
    /// Expected SHA-256 of the supported model export.
    public let modelSHA256: String
    /// Maximum permitted absolute error for policy and value logits.
    public let logitTolerance: Double
    /// Maximum permitted absolute error for legal policy probabilities.
    public let probabilityTolerance: Double
    /// Maximum checkpoint-versus-ONNX error recorded during fixture generation.
    public let maxPythonONNXError: Double
    /// Reference positions, rating pairs, encoded input hashes and output values.
    public let cases: [ReferenceCase]
    /// Loads the bundled corpus and verifies its schema/model identity.
    ///
    /// - Returns: A corpus containing at least one nonterminal position.
    /// - Throws: `MaiaError` for missing/incompatible corpus metadata, or underlying
    ///   file/JSON decoding errors. No model or Python installation is required.
    public static func load() throws -> Self {
        guard let url = Bundle.module.url(forResource: "reference", withExtension: "json") else {
            throw MaiaError.invalidRequest("Reference corpus missing.")
        }
        let corpus = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        guard corpus.schemaVersion == 1, corpus.modelSHA256 == MaiaSession.modelSHA256,
              corpus.cases.contains(where: { !$0.terminal }) else {
            throw MaiaError.invalidRequest("Reference corpus/model identity mismatch.")
        }
        return corpus
    }
}

/// Timing, correctness and process-memory measurements from a benchmark run.
///
/// Durations are seconds, footprint values are bytes, and budget values are MiB.
/// Kernel peaks cover process lifetime; sampled peaks only observe checkpoints.
/// Screening booleans are harness thresholds, not operating-system guarantees.
public struct BenchmarkReport: Codable, Sendable {
    /// JSON report format version.
    public var schemaVersion = 1
    /// Wall-clock start timestamp for the report.
    public var startedAt = Date()
    /// Completion timestamp, set only after the benchmark finishes successfully.
    public var completedAt: Date?
    /// Operating-system version of the benchmark process.
    public var os = ProcessInfo.processInfo.operatingSystemVersionString
    /// Runtime platform, such as macOS or iOS/iPadOS.
    public var platform = ""
    /// Whether this process is running in an Apple simulator.
    public var isSimulator = false
    /// Generic hardware identifier; macOS may report an architecture such as arm64.
    public var hardware = ""
    /// SHA-256 of the benchmarked model export.
    public var modelSHA256 = MaiaSession.modelSHA256
    /// Runtime version, execution provider, precision and CPU settings.
    public var runtime = "ONNX Runtime 1.24.2 CPU; FP32; 2 intra-op threads; basic graph optimization"
    /// Model verification and preparation duration, excluding the first prediction.
    public var coldLoadSeconds = 0.0
    /// First nonterminal prediction duration after preparation.
    public var firstPredictionSeconds = 0.0
    /// Number of reference cases checked successfully.
    public var correctnessCases = 0
    /// Largest absolute policy/value-logit error observed against the corpus.
    public var maxLogitError = 0.0
    /// Largest absolute legal-policy probability error against the corpus.
    public var maxProbabilityError = 0.0
    /// Number of timed warm predictions.
    public var warmIterations = 0
    /// Median warm prediction duration.
    public var warmMedianSeconds = 0.0
    /// 95th-percentile warm prediction duration.
    public var warmP95Seconds = 0.0
    /// Combined duration of two sequential predictions at different self ratings.
    public var twoRatingSeconds = 0.0
    /// Actual elapsed duration of the paced phase, including its pauses.
    public var sustainedSeconds = 0.0
    /// Predictions completed during the paced phase; not unrestricted throughput.
    public var sustainedPredictions = 0
    /// Prediction p95 over the first up-to-100 paced samples, excluding pauses.
    public var sustainedFirstP95Seconds = 0.0
    /// Prediction p95 over the last up-to-100 paced samples, excluding pauses.
    public var sustainedLastP95Seconds = 0.0
    /// Current process footprint before model preparation.
    public var footprintBeforeLoadBytes: UInt64 = 0
    /// Current process footprint immediately after model preparation.
    public var footprintAfterLoadBytes: UInt64 = 0
    /// Largest current footprint observed at benchmark checkpoints.
    public var sampledPeakFootprintBytes: UInt64 = 0
    /// Kernel process-lifetime peak physical footprint, or zero if unavailable.
    public var kernelPeakFootprintBytes: UInt64 = 0
    /// Kernel process-lifetime maximum resident size, or zero if unavailable.
    public var peakResidentBytes: UInt64 = 0
    /// Current footprint at the beginning of the paced phase.
    public var sustainedInitialFootprintBytes: UInt64 = 0
    /// Current footprint at the end of the paced phase.
    public var sustainedFinalFootprintBytes: UInt64 = 0
    /// Current footprint after the first unload; allocator pages may remain resident.
    public var footprintAfterUnloadBytes: UInt64 = 0
    /// Positive harness screening budget in MiB; not an OS process limit.
    public var memoryBudgetMiB = 1024
    /// Distinct thermal-state raw values sampled during paced inference.
    ///
    /// Values follow `ProcessInfo.ThermalState`: 0 nominal, 1 fair, 2 serious, 3 critical.
    public var thermalStates: [Int] = []
    /// Number of completed prepare/predict/unload verification cycles.
    public var reloadCycles = 0
    /// Whether a task canceled before prediction produced `CancellationError`.
    public var preCanceledRequestRejected = false
    /// Current footprints after prediction in each reload cycle.
    public var reloadLoadedFootprints: [UInt64] = []
    /// Current footprints after unloading in each reload cycle.
    public var reloadUnloadedFootprints: [UInt64] = []
    /// Whether model preparation plus first prediction took at most five seconds.
    public var coldTargetMet = false
    /// Whether warm prediction p95 was at most one second.
    public var warmTargetMet = false
    /// Whether a positive sampled footprint peak fits the configured screening budget.
    public var sampledMemoryBudgetMet = false
    /// Whether an available positive kernel peak fits the configured screening budget.
    public var kernelMemoryBudgetMet = false
    /// Whether a requested paced run ended within 64 MiB of its initial footprint.
    ///
    /// This compares endpoints and is not proof that every workload is leak-free.
    public var sustainedMemoryGrowthWithin64MiB = false
    /// Measurement-method and runtime-context notes accompanying the numeric data.
    public var notes: [String] = []
    /// Writes pretty-printed, sorted JSON atomically, with ISO-8601 timestamps.
    ///
    /// - Parameter url: Output file URL; missing parent directories are created.
    /// - Throws: File-system or JSON encoding errors.
    public func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}

/// Reference-corpus checks and model measurements for a host process.
public enum MaiaBenchmark {
    /// Returns the process's current physical footprint in bytes, or zero if unavailable.
    public static func footprint() -> UInt64 { memoryMetrics().current }

    private static func memoryMetrics() -> (current: UInt64, peak: UInt64, residentPeak: UInt64) {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        var basic = mach_task_basic_info_data_t()
        var basicCount = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        let basicResult = withUnsafeMutablePointer(to: &basic) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(basicCount)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &basicCount)
            }
        }
        return (result == KERN_SUCCESS ? info.phys_footprint : 0,
                result == KERN_SUCCESS ? UInt64(max(0, info.ledger_phys_footprint_peak)) : 0,
                basicResult == KERN_SUCCESS ? basic.resident_size_max : 0)
    }
    static func hardware() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var value = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &value, &size, nil, 0)
        return String(decoding: value.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
    private static func percentile(_ values: [Double], _ fraction: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[max(0, min(sorted.count - 1, Int(ceil(Double(sorted.count) * fraction)) - 1))]
    }

    /// Compares an encoded fixture and prediction against independent reference data.
    ///
    /// - Parameters:
    ///   - fixture: Expected encoding, legal moves and model outputs.
    ///   - prediction: The corresponding direct-API result.
    ///   - corpus: Reference identity and numeric tolerances.
    /// - Returns: Maximum absolute logit and legal-policy probability errors; a
    ///   correctly empty terminal policy returns `(0, 0)`.
    /// - Throws: `MaiaError` for encoding, legal-policy, schema or numeric mismatches.
    public static func check(_ fixture: ReferenceCase, prediction: MaiaPrediction,
                             corpus: ReferenceCorpus) throws -> (Double, Double) {
        let input = try MaiaEncoding.prepare(fixture.request)
        guard input.tokenSHA256 == fixture.tokenSHA256,
              input.legalMoves == fixture.legalMoves, input.terminal == fixture.terminal,
              prediction.terminal == fixture.terminal else {
            throw MaiaError.invalidRequest("Encoding, legality, or terminal mismatch: \(fixture.id)")
        }
        if fixture.terminal {
            guard prediction.probabilities.isEmpty, prediction.valueLogits.isEmpty else {
                throw MaiaError.invalidRequest("Terminal position produced predictions: \(fixture.id)")
            }
            return (0, 0)
        }
        guard Set(prediction.logits.keys) == Set(fixture.logits.keys),
              Set(prediction.probabilities.keys) == Set(fixture.probabilities.keys),
              prediction.valueLogits.count == fixture.valueLogits.count else {
            throw MaiaError.invalidRequest("Prediction schema mismatch: \(fixture.id)")
        }
        var logitError = zip(prediction.valueLogits, fixture.valueLogits).map { abs(Double($0 - $1)) }.max() ?? 0
        var probabilityError = 0.0
        for move in fixture.legalMoves {
            logitError = max(logitError, abs(Double(prediction.logits[move]! - fixture.logits[move]!)))
            probabilityError = max(probabilityError, abs(prediction.probabilities[move]! - fixture.probabilities[move]!))
        }
        guard logitError.isFinite, probabilityError.isFinite,
              logitError <= corpus.logitTolerance, probabilityError <= corpus.probabilityTolerance,
              abs(prediction.probabilities.values.reduce(0, +) - 1) < 1e-6,
              abs(prediction.outcomeProbabilities.reduce(0, +) - 1) < 1e-6 else {
            throw MaiaError.invalidRequest("Numerical mismatch: \(fixture.id); logits=\(logitError), probabilities=\(probabilityError)")
        }
        return (logitError, probabilityError)
    }

    /// Runs reference checks and measurements without driving or inspecting UI.
    ///
    /// - Parameters:
    ///   - modelURL: File URL for the pinned export; no asset is downloaded.
    ///   - iterations: Positive warm-prediction count, defaulting to 100.
    ///   - sustainedSeconds: Nonnegative, finite paced-run duration; 0 disables it.
    ///   - memoryBudgetMiB: Positive screening budget, defaulting to 1024 MiB.
    ///   - progress: Status callback on the runner's execution context; dispatch
    ///     UI updates to the main actor and return promptly.
    /// - Returns: A completed report for this process. The paced phase inserts
    ///   a 100 ms pause between predictions. Simulator measurements describe
    ///   the host, not physical mobile-device performance.
    /// - Throws: Configuration, model, reference or cancellation errors. The
    ///   function is asynchronous but does not interrupt a running ONNX kernel.
    public static func run(modelURL: URL, iterations: Int = 100, sustainedSeconds: Double = 0,
                           memoryBudgetMiB: Int = 1024,
                           progress: @Sendable (String) -> Void = { _ in }) async throws -> BenchmarkReport {
        guard iterations > 0, sustainedSeconds >= 0, sustainedSeconds.isFinite, memoryBudgetMiB > 0 else {
            throw MaiaError.invalidRequest("Invalid benchmark configuration.")
        }
        let corpus = try ReferenceCorpus.load()
        var report = BenchmarkReport()
        report.hardware = hardware(); report.memoryBudgetMiB = memoryBudgetMiB
        #if targetEnvironment(simulator)
        report.isSimulator = true
        report.hardware = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "simulator"
        #endif
        #if os(macOS)
        report.platform = "macOS"
        #else
        report.platform = "iOS/iPadOS"
        #endif
        report.notes = ["MaiaSession direct API; MaiaUCI uses the same pinned inference core.",
                        "Footprint peak is sampled between operations; allocations within an inference may be higher.",
                        "Background/resume and user-visible responsiveness require a later manual device check.",
                        "Memory budget is an explicit experiment budget, not an OS process limit.",
                        "Cold means the first session in this process; filesystem caches were not evicted.",
                        "Kernel high-water metrics include transient allocations and the full process lifetime."]
        if report.isSimulator { report.notes.append("Simulator performance is host-Mac performance, not physical mobile-device evidence.") }
        let session = MaiaSession(configuration: .init(modelURL: modelURL))
        report.footprintBeforeLoadBytes = footprint()
        let loadStart = ProcessInfo.processInfo.systemUptime
        try await session.prepare()
        report.coldLoadSeconds = ProcessInfo.processInfo.systemUptime - loadStart
        report.footprintAfterLoadBytes = footprint()
        report.sampledPeakFootprintBytes = max(report.footprintBeforeLoadBytes, report.footprintAfterLoadBytes)
        let first = corpus.cases.first { !$0.terminal }!
        let firstStart = ProcessInfo.processInfo.systemUptime
        _ = try await session.predict(first.request)
        report.firstPredictionSeconds = ProcessInfo.processInfo.systemUptime - firstStart
        progress("Model loaded; checking \(corpus.cases.count) upstream reference cases.")
        for fixture in corpus.cases {
            let prediction = try await session.predict(fixture.request)
            let (logitError, probabilityError) = try check(fixture, prediction: prediction, corpus: corpus)
            report.maxLogitError = max(report.maxLogitError, logitError)
            report.maxProbabilityError = max(report.maxProbabilityError, probabilityError)
            report.correctnessCases += 1
            report.sampledPeakFootprintBytes = max(report.sampledPeakFootprintBytes, footprint())
        }
        let playable = corpus.cases.filter { !$0.terminal }
        var times: [Double] = []
        for i in 0..<iterations {
            try Task.checkCancellation()
            let start = ProcessInfo.processInfo.systemUptime
            _ = try await session.predict(playable[i % playable.count].request)
            times.append(ProcessInfo.processInfo.systemUptime - start)
            report.sampledPeakFootprintBytes = max(report.sampledPeakFootprintBytes, footprint())
        }
        report.warmIterations = times.count
        report.warmMedianSeconds = percentile(times, 0.5)
        report.warmP95Seconds = percentile(times, 0.95)
        var secondRating = first.request
        secondRating.selfRating = 2400
        let pairStart = ProcessInfo.processInfo.systemUptime
        _ = try await session.predict(first.request)
        _ = try await session.predict(secondRating)
        report.twoRatingSeconds = ProcessInfo.processInfo.systemUptime - pairStart
        progress("Correctness passed; warm p95 \(String(format: "%.3f", report.warmP95Seconds)) s. Sustained test: \(Int(sustainedSeconds)) s.")
        let sustainedStart = ProcessInfo.processInfo.systemUptime
        report.sustainedInitialFootprintBytes = footprint()
        var sustainedTimes: [Double] = []
        var lastProgress = sustainedStart
        while ProcessInfo.processInfo.systemUptime - sustainedStart < sustainedSeconds {
            try Task.checkCancellation()
            let i = report.sustainedPredictions
            var request = playable[i % playable.count].request
            if i % 2 == 1 { request.selfRating = 2400 }
            let start = ProcessInfo.processInfo.systemUptime
            _ = try await session.predict(request)
            sustainedTimes.append(ProcessInfo.processInfo.systemUptime - start)
            report.sustainedPredictions += 1
            report.sampledPeakFootprintBytes = max(report.sampledPeakFootprintBytes, footprint())
            let thermal = ProcessInfo.processInfo.thermalState.rawValue
            if !report.thermalStates.contains(thermal) { report.thermalStates.append(thermal) }
            if ProcessInfo.processInfo.systemUptime - lastProgress >= 30 {
                progress("Sustained \(Int(ProcessInfo.processInfo.systemUptime - sustainedStart)) s; \(report.sustainedPredictions) predictions; footprint \(footprint() / 1_048_576) MiB.")
                lastProgress = ProcessInfo.processInfo.systemUptime
            }
            // A reproducible workload rather than an unrestricted thermal stress test.
            try await Task.sleep(for: .milliseconds(100))
        }
        report.sustainedSeconds = ProcessInfo.processInfo.systemUptime - sustainedStart
        report.sustainedFinalFootprintBytes = footprint()
        let window = min(100, sustainedTimes.count)
        report.sustainedFirstP95Seconds = percentile(Array(sustainedTimes.prefix(window)), 0.95)
        report.sustainedLastP95Seconds = percentile(Array(sustainedTimes.suffix(window)), 0.95)
        // A task canceled before inference starts must never return a prediction.
        let canceled = Task { () throws -> MaiaPrediction in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await session.predict(first.request)
        }
        canceled.cancel()
        do { _ = try await canceled.value } catch is CancellationError { report.preCanceledRequestRejected = true }
        await session.unload()
        report.footprintAfterUnloadBytes = footprint()
        for _ in 0..<2 {
            try await session.prepare()
            _ = try await session.predict(first.request)
            let loadedFootprint = footprint()
            report.sampledPeakFootprintBytes = max(report.sampledPeakFootprintBytes, loadedFootprint)
            await session.unload()
            report.reloadLoadedFootprints.append(loadedFootprint)
            report.reloadUnloadedFootprints.append(footprint())
            report.reloadCycles += 1
        }
        let memory = memoryMetrics()
        report.kernelPeakFootprintBytes = memory.peak
        report.peakResidentBytes = memory.residentPeak
        report.kernelMemoryBudgetMet = memory.peak > 0 && memory.peak <= UInt64(memoryBudgetMiB) * 1_048_576
        report.completedAt = Date()
        report.coldTargetMet = report.coldLoadSeconds + report.firstPredictionSeconds <= 5
        report.warmTargetMet = report.warmP95Seconds <= 1
        report.sampledMemoryBudgetMet = report.sampledPeakFootprintBytes > 0 && report.sampledPeakFootprintBytes <= UInt64(memoryBudgetMiB) * 1_048_576
        report.sustainedMemoryGrowthWithin64MiB = sustainedSeconds > 0 && report.sustainedFinalFootprintBytes <= report.sustainedInitialFootprintBytes + 64 * 1_048_576
        progress("Benchmark complete.")
        return report
    }
}
