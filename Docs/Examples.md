# Examples

## Direct probabilities and two ratings

```swift
import Foundation
import MaiaEmbedded

func compare(modelURL: URL, fen: String) async throws -> [MaiaPrediction] {
    let session = MaiaSession(configuration: .init(modelURL: modelURL))
    do {
        try await session.prepare()
        var results: [MaiaPrediction] = []
        for rating in [1200, 2000] {
            results.append(try await session.predict(
                MaiaRequest(initialFEN: fen, selfRating: rating, opponentRating: 1600)))
        }
        await session.unload()
        return results
    } catch {
        await session.unload()
        throw error
    }
}
```

Reuse one session rather than loading a second model for each rating. For
multiple moves, retain a `MaiaSeededGenerator` and pass it to
`MaiaSampler.select(from:options:using:)`. A fixed `options.seed` alone restarts
the random stream on each direct select call.

## One UCI search with cleanup

```swift
import Foundation
import MaiaEmbedded
import MaiaUCI

enum UCIExampleError: Error {
    case timeout
    case streamClosed
}

func oneMove(modelURL: URL) async throws -> String? {
    let (lines, continuation) = AsyncStream<String>.makeStream()
    let engine = MaiaEngine(configuration: .init(model: .init(modelURL: modelURL))) {
        continuation.yield($0)
    }
    do {
        try engine.start()
        let move = try await withThrowingTaskGroup(of: String?.self) { group in
            group.addTask {
                engine.sendCommand("uci")
                for await line in lines {
                    try Task.checkCancellation()
                    if line.hasPrefix("info string MaiaEmbedded error:") {
                        throw MaiaError.runtimeFailure(line)
                    }
                    if line == "uciok" { engine.sendCommand("isready") }
                    if line == "readyok" {
                        engine.sendCommand("position startpos")
                        engine.sendCommand("go depth 1")
                    }
                    if line.hasPrefix("bestmove ") {
                        let move = String(line.dropFirst(9))
                        return move == "0000" ? nil : move
                    }
                }
                try Task.checkCancellation()
                throw UCIExampleError.streamClosed
            }
            group.addTask {
                try await Task.sleep(for: .seconds(10))
                throw UCIExampleError.timeout
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw UCIExampleError.streamClosed
            }
            return result
        }
        await engine.shutdown()
        continuation.finish()
        return move
    } catch {
        await engine.shutdown()
        continuation.finish()
        throw error
    }
}
```

The 10-second deadline covers readiness and the move response. Cancellation of
its stream task stops waiting for output; cleanup still awaits native work, so
this is not a hard kernel-interruption deadline. A terminal `bestmove 0000`
becomes nil; diagnostic errors are handled first. Applications should retain
request identities when positions/screens change and observe the throwing task.
See [UCI](UCI.md) for command and lifecycle contracts.

## Native reference app

Open `Examples/MaiaBenchmark/MaiaBenchmark.xcodeproj` after downloading the model.
**Check Swift API & UCI** checks the upstream corpus, displays two rating policies
using the same loaded session, then checks UCI legality, stop and restart.
**Run Checks & Benchmark** measures load/warm performance. **20-Minute Session**
runs a paced sustained workload. Completed reports are shareable.
Cancel/background invalidates the current operation; returning allows a fresh run.

Launch with `--package-checks` for a headless API/UCI report in
`Documents/maia-validation.json`, or `--autorun --iterations 100 --duration 30`
for `Documents/maia-benchmark.json`. No XCTest UI target is involved.

## Command-line tools

```sh
swift run maia-uci --model Resources/Models/maia3-79m.onnx
swift run maia-smoke --iterations 20 --output .build/package.json
swift run maia-soak --iterations 200
Scripts/run-mac-benchmark.sh 30
```

| Executable | Options and defaults |
| --- | --- |
| `maia-uci` | Required `--model PATH`; optional `--outcome-scores`; `--help` prints usage. |
| `maia-smoke` | `--model PATH` defaults to `Resources/Models/maia3-79m.onnx`; `--iterations` defaults to 20; optional `--output PATH`. |
| `maia-soak` | Same options as smoke; default iteration count is 200. Both accept 1...100,000 iterations. |
| `maia-benchmark` | Required `--model PATH` and `--output PATH`; defaults: `--iterations 100`, `--duration 0` seconds and `--memory-mib 1024`. |

Smoke and soak tools validate the reference corpus and direct two-rating API,
then perform the requested UCI operations plus infinite stop/restart checks.
They exit nonzero on failure. The benchmark's positive memory budget is a
screening threshold, not an OS memory limit. Duration 0 disables its paced phase.

## Benchmark support in a client

```swift
import Foundation
import MaiaBenchmarkSupport

func benchmark(modelURL: URL, reportURL: URL) async throws {
    let report = try await MaiaBenchmark.run(
        modelURL: modelURL, iterations: 100, sustainedSeconds: 30)
    try report.write(to: reportURL)
}
```

This optional library product supports reference clients and measurements.
Regular chess applications use MaiaEmbedded and/or MaiaUCI. Keep reports in
app-owned storage, measure physical hardware for deployment decisions, and see
[Benchmarks](Benchmarks.md) for interpretation of latency and footprint fields.
