// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import Darwin
import MaiaEmbedded

public struct ReferenceCase: Codable, Sendable {
    public let id: String
    public let initialFEN: String
    public let moves: [String]
    public let useHistory: Bool
    public let selfRating: Int
    public let opponentRating: Int
    public let tokenSHA256: String
    public let terminal: Bool
    public let legalMoves: [String]
    public let logits: [String: Float]
    public let probabilities: [String: Double]
    public let valueLogits: [Float]
    public var request: MaiaRequest {
        MaiaRequest(initialFEN: initialFEN, moves: moves, useHistory: useHistory,
                              selfRating: selfRating, opponentRating: opponentRating)
    }
}
public struct ReferenceCorpus: Codable, Sendable {
    public let schemaVersion: Int
    public let upstreamRevision: String
    public let modelSHA256: String
    public let logitTolerance: Double
    public let probabilityTolerance: Double
    public let maxPythonONNXError: Double
    public let cases: [ReferenceCase]
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

public struct BenchmarkReport: Codable, Sendable {
    public var schemaVersion = 1
    public var startedAt = Date()
    public var completedAt: Date?
    public var os = ProcessInfo.processInfo.operatingSystemVersionString
    public var platform = ""
    public var isSimulator = false
    public var hardware = ""
    public var modelSHA256 = MaiaSession.modelSHA256
    public var runtime = "ONNX Runtime 1.24.2 CPU; FP32; 2 intra-op threads; basic graph optimization"
    public var coldLoadSeconds = 0.0
    public var firstPredictionSeconds = 0.0
    public var correctnessCases = 0
    public var maxLogitError = 0.0
    public var maxProbabilityError = 0.0
    public var warmIterations = 0
    public var warmMedianSeconds = 0.0
    public var warmP95Seconds = 0.0
    public var twoRatingSeconds = 0.0
    public var sustainedSeconds = 0.0
    public var sustainedPredictions = 0
    public var sustainedFirstP95Seconds = 0.0
    public var sustainedLastP95Seconds = 0.0
    public var footprintBeforeLoadBytes: UInt64 = 0
    public var footprintAfterLoadBytes: UInt64 = 0
    public var sampledPeakFootprintBytes: UInt64 = 0
    public var kernelPeakFootprintBytes: UInt64 = 0
    public var peakResidentBytes: UInt64 = 0
    public var sustainedInitialFootprintBytes: UInt64 = 0
    public var sustainedFinalFootprintBytes: UInt64 = 0
    public var footprintAfterUnloadBytes: UInt64 = 0
    public var memoryBudgetMiB = 1024
    public var thermalStates: [Int] = []
    public var reloadCycles = 0
    public var preCanceledRequestRejected = false
    public var reloadLoadedFootprints: [UInt64] = []
    public var reloadUnloadedFootprints: [UInt64] = []
    public var coldTargetMet = false
    public var warmTargetMet = false
    public var sampledMemoryBudgetMet = false
    public var kernelMemoryBudgetMet = false
    public var sustainedMemoryGrowthWithin64MiB = false
    public var notes: [String] = []
    public func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}

public enum MaiaBenchmark {
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

    /// Runs inference without driving or inspecting UI. Results are measured on
    /// the current process; simulator results are explicitly identified.
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
