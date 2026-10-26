// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import MaiaBenchmarkSupport

@MainActor @Observable final class BenchmarkModel {
    var status = "Ready. Run the reference checks and CPU benchmark on this device."
    var report: BenchmarkReport?
    var running = false
    var reportURL: URL?
    private var task: Task<Void, Never>?
    private var generation = UUID()

    func start(duration: Double = 0, iterations: Int = 100) {
        guard !running else { return }
        let runID = UUID()
        generation = runID; running = true; report = nil
        task = Task {
            do {
                guard let modelURL = Bundle.main.url(forResource: "maia3-79m", withExtension: "onnx") else {
                    throw CocoaError(.fileNoSuchFile)
                }
                let result = try await MaiaBenchmark.run(modelURL: modelURL, iterations: iterations,
                    sustainedSeconds: duration, progress: { [weak self] text in
                        print("MAIA_BENCHMARK: \(text)")
                        Task { @MainActor in
                            guard let self, self.generation == runID, self.running else { return }
                            self.status = text
                        }
                    })
                try Task.checkCancellation()
                guard generation == runID else { return }
                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let url = documents.appendingPathComponent("maia-benchmark.json")
                try result.write(to: url)
                report = result; reportURL = url
                status = "Complete. \(result.correctnessCases) reference cases passed."
                print("MAIA_BENCHMARK_COMPLETE: \(url.path)")
            } catch is CancellationError {
                if generation == runID { status = "Canceled. No completed report was produced for this run." }
            } catch {
                if generation == runID {
                    status = "Failed: \(error.localizedDescription)"
                    print("MAIA_BENCHMARK_FAILED: \(error.localizedDescription)")
                }
            }
            if generation == runID { running = false }
        }
    }
    func cancel() {
        task?.cancel()
        // Keep running true until the current native operation returns, so a
        // new task cannot overlap the canceled run's remaining cleanup.
        if running { status = "Canceling after the current native operation…" }
    }
}

@main struct MaiaBenchmarkApp: App {
    @State private var model = BenchmarkModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Maia 79M Experiment").font(.largeTitle)
                    Text("Native CPU inference · FP32 · iPhone, iPad and Mac").foregroundStyle(.secondary)
                    Text(model.status).textSelection(.enabled)
                    if model.running { ProgressView() }
                    HStack {
                        Button("Run Checks & Benchmark") { model.start() }.disabled(model.running)
                        Button("Run 20-Minute Session") { model.start(duration: 1200) }.disabled(model.running)
                    }
                    Button("Cancel", role: .cancel) { model.cancel() }.disabled(!model.running)
                    if let report = model.report {
                        Divider()
                        Text("Reference cases: \(report.correctnessCases)")
                        Text("Load + first result: \(report.coldLoadSeconds + report.firstPredictionSeconds, specifier: "%.3f") s")
                        Text("Warm median / p95: \(report.warmMedianSeconds, specifier: "%.3f") / \(report.warmP95Seconds, specifier: "%.3f") s")
                        Text("Two ratings: \(report.twoRatingSeconds, specifier: "%.3f") s")
                        Text("Kernel / sampled peak: \(Double(report.kernelPeakFootprintBytes) / 1_048_576, specifier: "%.1f") / \(Double(report.sampledPeakFootprintBytes) / 1_048_576, specifier: "%.1f") MiB")
                        Text("Sustained: \(report.sustainedSeconds, specifier: "%.0f") s · \(report.sustainedPredictions) predictions")
                        if report.isSimulator { Text("Simulator timing reflects the host Mac, not an iPhone or iPad.").foregroundStyle(.orange) }
                        if let url = model.reportURL { ShareLink("Export JSON Report", item: url) }
                    }
                    Divider()
                    Text("The model is bundled for offline testing. This is a feasibility harness, not a chess-playing app. Foreground sessions pause by cancellation when the app enters the background. Physical-device results are required before claiming mobile performance.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(24).frame(maxWidth: 800, alignment: .leading)
            }
            .frame(minWidth: 320, minHeight: 400)
            .task {
                #if os(iOS)
                UIApplication.shared.isIdleTimerDisabled = true
                #endif
                if CommandLine.arguments.contains("--autorun") {
                    func argument(_ name: String, fallback: String) -> String {
                        let args = CommandLine.arguments
                        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return fallback }
                        return args[i + 1]
                    }
                    model.start(duration: Double(argument("--duration", fallback: "0")) ?? 0,
                                iterations: Int(argument("--iterations", fallback: "20")) ?? 20)
                }
            }
            .onChange(of: phase) { _, newPhase in
                if newPhase == .background { model.cancel() }
            }
        }
    }
}
