// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import MaiaUCI
import MaiaEmbedded

@main struct MaiaCLI {
    static func main() async {
        setbuf(stdout, nil)
        let args = Array(CommandLine.arguments.dropFirst())
        if args == ["--help"] {
            print("Usage: maia-uci --model /local/maia3-79m.onnx [--outcome-scores]")
            return
        }
        var modelPath: String?
        var scores = false
        var index = 0
        while index < args.count {
            switch args[index] {
            case "--model" where modelPath == nil && index + 1 < args.count && !args[index + 1].hasPrefix("--"):
                modelPath = args[index + 1]; index += 2
            case "--outcome-scores" where !scores:
                scores = true; index += 1
            default:
                fputs("Usage: maia-uci --model PATH [--outcome-scores]\n", stderr); exit(2)
            }
        }
        guard let modelPath else {
            fputs("Usage: maia-uci --model PATH [--outcome-scores]\n", stderr); exit(2)
        }
        let configuration = MaiaEngine.Configuration(model: .init(modelURL: URL(fileURLWithPath: modelPath)),
            emitsOutcomeScores: scores)
        let engine = MaiaEngine(configuration: configuration) { print($0) }
        do {
            try engine.start()
            await Task.detached {
                while let line = readLine() {
                    engine.sendCommand(line)
                    if line.split(whereSeparator: \.isWhitespace).first == "quit" { break }
                }
            }.value
            // EOF completes a held infinite result as if the client sent stop.
            engine.sendCommand("stop")
            await engine.waitForIdle()
            await engine.shutdown()
        } catch {
            fputs("MaiaEmbedded: \(error.localizedDescription)\n", stderr)
            await engine.shutdown(); exit(1)
        }
    }
}
