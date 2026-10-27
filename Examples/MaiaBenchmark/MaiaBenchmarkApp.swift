// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import MaiaBenchmarkSupport

@MainActor @Observable final class BenchmarkModel {
    var status = "Ready. Run the reference checks and CPU benchmark on this device."
    var packageReport: MaiaPackageReport?
    var packageReportURL: URL?
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
    func checkPackage() {
        guard !running else { return }
        let runID = UUID(); generation = runID; running = true
        packageReport = nil; packageReportURL = nil
        status = "Checking the direct API, two ratings, UCI, stop and restart…"
        task = Task {
            do {
                guard let url = Bundle.main.url(forResource: "maia3-79m", withExtension: "onnx") else {
                    throw CocoaError(.fileNoSuchFile)
                }
                let result = try await MaiaPackageChecks.run(modelURL: url)
                try Task.checkCancellation()
                guard generation == runID else { return }
                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let reportURL = documents.appendingPathComponent("maia-validation.json")
                try result.write(to: reportURL)
                packageReport = result; packageReportURL = reportURL
                status = "API and UCI checks passed. Two rating predictions used one loaded model."
                print("MAIA_PACKAGE_COMPLETE: \(reportURL.lastPathComponent)")
            } catch is CancellationError {
                if generation == runID { status = "Canceled. No new package report was produced." }
            } catch {
                if generation == runID {
                    status = "Failed: \(error.localizedDescription)"
                    print("MAIA_PACKAGE_FAILED: \(error.localizedDescription)")
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
                    Text("Maia Embedded").font(.largeTitle)
                    Text("Native CPU inference · FP32 · iPhone, iPad and Mac").foregroundStyle(.secondary)
                    Text(model.status).textSelection(.enabled)
                    if model.running { ProgressView() }
                    Button("Check Swift API & UCI") { model.checkPackage() }.disabled(model.running)
                    if let package = model.packageReport {
                        ForEach(package.ratings.indices, id: \.self) { index in
                            let preview = package.ratings[index]
                            Text("Side to move \(preview.rating) · opponent \(preview.opponentRating)").font(.headline)
                            Text(preview.moves.map { "\($0): \(Int(((preview.probabilities[$0] ?? 0) * 100).rounded()))%" }.joined(separator: " · "))
                            Text("Sampled move: \(preview.selectedMove ?? "none")").font(.caption)
                        }
                        Text("These percentages predict human choices; they are not engine evaluations.").font(.caption)
                        if let url = model.packageReportURL { ShareLink("Export API/UCI Report", item: url) }
                    }
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
                    Text("The model is bundled for offline testing. This reference harness exercises the package without a game UI. Foreground sessions pause by cancellation when the app enters the background. Physical-device results are required before claiming mobile performance.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(24).frame(maxWidth: 800, alignment: .leading)
            }
            .frame(minWidth: 320, minHeight: 400)
            .task {
                #if os(iOS)
                UIApplication.shared.isIdleTimerDisabled = true
                #endif
                if CommandLine.arguments.contains("--package-checks") {
                    model.checkPackage()
                } else if CommandLine.arguments.contains("--autorun") {
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
