// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import MaiaBenchmarkSupport

@main struct Runner {
    static func main() async {
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            func value(_ name: String, default fallback: String) throws -> String {
                guard let i = args.firstIndex(of: name) else { return fallback }
                guard i + 1 < args.count else { throw CocoaError(.coderInvalidValue) }
                return args[i + 1]
            }
            let valid = Set(["--model", "--iterations", "--output"])
            guard args.count.isMultiple(of: 2), stride(from: 0, to: args.count, by: 2).allSatisfy({ valid.contains(args[$0]) }),
                  Set(stride(from: 0, to: args.count, by: 2).map { args[$0] }).count == args.count / 2 else {
                throw CocoaError(.coderInvalidValue)
            }
            let path = try value("--model", default: "Resources/Models/maia3-79m.onnx")
            guard let iterations = Int(try value("--iterations", default: "20")) else { throw CocoaError(.coderInvalidValue) }
            let report = try await MaiaPackageChecks.run(modelURL: URL(fileURLWithPath: path), uciRequests: iterations)
            if args.contains("--output") {
                try report.write(to: URL(fileURLWithPath: value("--output", default: "")))
            }
            print("UCI validation passed: \(iterations) legal/terminal requests, infinite stop, teardown and restart.")
        } catch {
            fputs("Maia validation failed: \(error.localizedDescription)\n", stderr); exit(1)
        }
    }
}
