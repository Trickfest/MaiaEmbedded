# MaiaEmbedded

MaiaEmbedded runs Maia-3 79M in-process from an iOS, iPadOS or macOS app. A
native Swift API returns human-move probabilities and selects moves; `MaiaUCI`
wraps the same core for clients that already speak UCI.

The package follows the StockfishEmbedded/ArasanEmbedded layout and lifecycle
examples. Maia predicts human play at requested Lichess rating levels. Its
probabilities and human-game outcomes have different meanings from searched
engine evaluations. This private development package has no release.

## Before you start

- **License:** AGPL-3.0-only package/model, with MIT dependencies and preserved
  upstream notices. See [Licensing](#licensing).
- **Requirements:** Swift 6.2+, Xcode 26+, iOS/iPadOS 26+ or macOS 26+. Current
  validation covers Apple silicon and arm64 simulators. Intel is unqualified.
- **Model:** explicitly provision the pinned 316 MB FP32 ONNX export. The
  library accepts a caller-owned local URL and never downloads during inference.
- **Memory:** physical feasibility runs peaked around 754–756 MiB on the tested
  mobile devices. Supporting older devices needs additional evidence. See
  [measured results](Docs/ExperimentResults.md).

## Installation

Keep `MaiaEmbedded` and `SwiftChessTools` as sibling checkouts. Add the local
package in Xcode, choosing `MaiaEmbedded` for direct calls and/or `MaiaUCI` for
line-based clients. A manifest client can use:

```swift
dependencies: [.package(path: "../MaiaEmbedded")],
targets: [.target(name: "MyApp", dependencies: [
    .product(name: "MaiaEmbedded", package: "MaiaEmbedded"),
    .product(name: "MaiaUCI", package: "MaiaEmbedded"),
])]
```

ONNX Runtime's official SwiftPM distribution is pinned to 1.24.2. No Python,
Flutter, Android bridge, subprocess or inference service is embedded in an app.
There is no public package version or Swift Package Index listing to install.

## Quick start with Swift Package Manager

### Predict and select through Swift

```swift
import MaiaEmbedded

let session = MaiaSession(configuration: .init(modelURL: localModelURL))
try await session.prepare()
let request = MaiaRequest(
    initialFEN: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    moves: ["e2e4"], useHistory: true, selfRating: 1400, opponentRating: 1800)
let prediction = try await session.predict(request)
for move in prediction.rankedMoves.prefix(5) {
    print(move, prediction.probabilities[move]!)
}
let selection = try MaiaSampler.select(from: prediction, options: .init(seed: 42))
print(selection.move as Any)
await session.unload()
```

A UI owner should keep and observe the throwing task, present errors and unload
on success **and** failure. See [Examples](Docs/Examples.md) for that pattern and
[Architecture](Docs/Architecture.md) for all input, sampling and outcome contracts.

### Send UCI commands

```swift
import MaiaEmbedded
import MaiaUCI

let engine = MaiaEngine(configuration: .init(model: .init(modelURL: localModelURL))) {
    line in print(line)
}
try engine.start()
engine.sendCommand("uci")
engine.sendCommand("isready")
// After readyok:
engine.sendCommand("position startpos moves e2e4")
engine.sendCommand("go movetime 1000")
// After bestmove, or when leaving the feature:
await engine.shutdown()
```

Keep the engine alive, wait for `uciok`/`readyok`, handle errors/deadlines, and
return promptly from its ordered callback. `start()` opens the protocol; it does
not send a handshake or load the model. Full examples and protocol limitations
are in [Examples](Docs/Examples.md) and [UCI](Docs/UCI.md).

## Runtime assets

```sh
Scripts/download-model.sh
```

The helper verifies byte count/SHA-256 and installs the ignored file under
`Resources/Models`. Bundle that file in an app or place a verified copy in
app-owned storage. The runtime independently verifies it before loading. Keep
it stable until unload. Only the pinned 79M export is supported; changing a
model requires a new compatibility/correctness qualification.

[Provenance](Docs/Provenance.md) records source, checkpoint, export, runtime and
reference-tool identities. See [Updating Maia](Docs/UpdatingMaia.md) before
changing any of them.

## Lifecycle and threading

`MaiaSession` is an actor that serializes model ownership and inference away
from the UI actor. Reuse one prepared session for sequential rating comparisons.
`prepare()` is idempotent, and `unload()` permits preparation again. Cancellation
is checked before and after native work; it cannot forcibly interrupt a kernel.
Direct clients own their screen/request generation checks.

`MaiaEngine` owns ordered command and callback queues. Its `stop()` closes the
current protocol generation and schedules cleanup; `shutdown()` also awaits
cleanup and callback drainage. It is restartable. It does not redirect process
standard streams and does not share the other wrappers' single-stream-owner
restriction. Independent sessions each retain a large model; budget memory.

## Reference app

`Examples/MaiaBenchmark` is the iPhone/iPad/Mac reference harness: direct API,
two-rating probabilities, UCI checks and measured inference benchmarks. It is
not a complete chess trainer. The `branch/maia-integration` development branch
of sibling SwiftChessDemo adds Maia beside Stockfish and Arasan; it requires
this private sibling checkout and downloaded model. No changes have been
published to the Demo's public main branch.

## Testing and troubleshooting

```sh
Scripts/validate.sh
swift run maia-smoke --output .build/package.json
swift run maia-soak --iterations 200
swift run maia-uci --model Resources/Models/maia3-79m.onnx
```

The local gate covers Debug/Release/Thread Sanitizer tests, actual-model
reference/API/UCI checks, CLI protocol, soak, benchmark and unsigned platform
builds. Final verification passed on the tested native Mac, physical iPhone 16
Pro Max and physical iPad Pro 13-inch (M4), including user-reported mobile
gameplay/layout/lifecycle checks.
[Testing](Docs/Testing.md) describes evidence and manual checks;
[Troubleshooting](Docs/Troubleshooting.md) covers assets, lifecycle and scores.
GitHub-hosted validation is optional; no workflow is required or automatically run.

## Maintenance and provenance

- [Architecture](Docs/Architecture.md): modules, inputs, outcomes, sampling and ownership
- [Examples](Docs/Examples.md): direct/UCI lifecycle and command-line tools
- [UCI](Docs/UCI.md): options and supported protocol
- [Testing](Docs/Testing.md): local and device validation
- [Provenance](Docs/Provenance.md), [Updating Maia](Docs/UpdatingMaia.md): upstream/assets
- [Future features](Docs/FutureFeatures.md): optional work and separately authorized distribution

## Licensing

Project-owned source is **AGPL-3.0-only**, as are the adapted upstream Maia code
and separately provisioned model. See [LICENSE](LICENSE),
[third-party notices](THIRD_PARTY_NOTICES.md) and [Provenance](Docs/Provenance.md).
ONNX Runtime and SwiftChessTools retain their MIT licenses. This is independent
work, not an official CSSLab or Mobile Maia release. The repository remains
private; visibility, release and App Store distribution require separate authorization.
