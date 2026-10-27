# Examples

## Direct probabilities and two ratings

```swift
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
import MaiaEmbedded
import MaiaUCI

func oneMove(modelURL: URL) async throws -> String? {
    let (lines, continuation) = AsyncStream<String>.makeStream()
    let engine = MaiaEngine(configuration: .init(model: .init(modelURL: modelURL))) {
        continuation.yield($0)
    }
    do {
        try engine.start()
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
                await engine.shutdown()
                continuation.finish()
                return String(line.dropFirst(9))
            }
        }
        await engine.shutdown(); continuation.finish()
        return nil
    } catch {
        await engine.shutdown(); continuation.finish()
        throw error
    }
}
```

This focused example has no startup deadline; a production owner needs a timeout
and must observe its throwing task. SwiftChessDemo's provider session illustrates
readiness, cancellation, deadlines and stale-request rejection. See [UCI](UCI.md).

## Native reference app

Open `Examples/MaiaBenchmark/MaiaBenchmark.xcodeproj` after downloading the model.
**Check Swift API & UCI** checks the upstream corpus, displays two rating policies
using the same loaded session, then checks UCI legality, stop and restart.
**Run Checks & Benchmark** measures load/warm performance. **20-Minute Session**
retains the original paced feasibility workload. Completed reports are shareable.
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

Both validation tools check the reference corpus and direct two-rating API first,
then perform the requested number of legal/terminal UCI operations plus infinite
stop and restart. They exit nonzero on failure. Use a current completion timestamp
and successful process exit when recording evidence; an old JSON file is not proof.
