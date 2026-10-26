// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import MaiaBenchmarkSupport

@main struct BenchmarkCLI {
    static func main() async {
        setbuf(stdout, nil)
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            func option(_ name: String, default fallback: String? = nil) throws -> String {
                guard let index = args.firstIndex(of: name), index + 1 < args.count else {
                    if let fallback { return fallback }
                    throw NSError(domain: "Arguments", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing \(name). Use --model PATH --output PATH [--iterations 100] [--duration 0] [--memory-mib 1024]."])
                }
                return args[index + 1]
            }
            guard let iterations = Int(try option("--iterations", default: "100")),
                  let duration = Double(try option("--duration", default: "0")),
                  let budget = Int(try option("--memory-mib", default: "1024")) else {
                throw NSError(domain: "Arguments", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid numeric argument."])
            }
            let output = URL(fileURLWithPath: try option("--output"))
            let report = try await MaiaBenchmark.run(modelURL: URL(fileURLWithPath: try option("--model")),
                iterations: iterations, sustainedSeconds: duration, memoryBudgetMiB: budget,
                progress: { print($0) })
            try report.write(to: output)
            print("Report: \(output.path)")
        } catch {
            fputs("Benchmark failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
