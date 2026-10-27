# MaiaEmbedded

[![Swift versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FTrickfest%2FMaiaEmbedded%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/Trickfest/MaiaEmbedded) [![Supported platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FTrickfest%2FMaiaEmbedded%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/Trickfest/MaiaEmbedded)

MaiaEmbedded runs Maia-3 79M in-process from an iOS, iPadOS or macOS app. A
native Swift API returns human-move probabilities and selects moves; `MaiaUCI`
wraps the same core for clients that already speak UCI.

Maia predicts human play at requested Lichess rating levels. Its
probabilities and human-game outcomes have different meanings from searched
engine evaluations. Releases contain source; consumers build the package locally.

## Before you start

- **License:** AGPL-3.0-only package/model, with MIT dependencies and preserved
  upstream notices. See [Licensing](#licensing).
- **Requirements:** Swift 6.2+, Xcode 26+, iOS/iPadOS 26+ or macOS 26+. Current
  validation covers Apple silicon and arm64 simulators. Intel is unqualified.
- **Model:** explicitly provision the pinned 316 MB FP32 ONNX export. The
  library accepts a caller-owned local URL and never downloads during inference.
- **Memory:** physical-device measurements peaked around 754–756 MiB on the tested
  mobile devices. Supporting older devices needs additional evidence. See
  [measured results](Docs/Benchmarks.md).

## Installation

In Xcode, choose **File > Add Package Dependencies**, enter
`https://github.com/Trickfest/MaiaEmbedded.git`, and select `MaiaEmbedded` for
direct calls and/or `MaiaUCI` for line-based clients. A manifest client can use:

```swift
dependencies: [
    .package(url: "https://github.com/Trickfest/MaiaEmbedded.git", from: "1.1.0"),
],
targets: [.target(name: "MyApp", dependencies: [
    .product(name: "MaiaEmbedded", package: "MaiaEmbedded"),
    .product(name: "MaiaUCI", package: "MaiaEmbedded"),
])]
```

ONNX Runtime's official SwiftPM distribution is pinned to 1.24.2. No Python,
Flutter, Android bridge, subprocess or inference service is embedded in an app.
SwiftChessTools resolves from its public release; no sibling checkout is needed.
Package builds and asset-independent tests work without model weights. SPI badges
report its separate compatibility processing, which may initially be pending.

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

Applications should observe the throwing task, present errors and unload
on success **and** failure. See [Examples](Docs/Examples.md) for that pattern and
[Architecture](Docs/Architecture.md) for all input, sampling and outcome contracts.

### Send UCI commands

```swift
import MaiaEmbedded
import MaiaUCI

let engine = MaiaEngine(configuration: .init(model: .init(modelURL: localModelURL))) {
    line in print(line) // Forward to the host's ordered protocol handling.
}
try engine.start()
engine.sendCommand("uci")
```

Keep the engine alive and drive the sequence from its output callback: after
`uciok`, send `isready`; after `readyok`, send a `position` command followed by
`go`. Observe the resulting `bestmove` before changing position. When the feature
closes, `await engine.shutdown()` to drain callbacks and release native resources.
`start()` opens the protocol; it does not load the model. The callback runs off
the main actor and should return promptly. A complete example with a response
deadline and cleanup on failure is in [Examples](Docs/Examples.md).

## Runtime assets

```sh
Scripts/download-model.sh
```

Run the helper from a clone of this repository. It verifies byte count/SHA-256
and installs the ignored file under
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
not a complete chess trainer. [SwiftChessDemo](https://github.com/Trickfest/SwiftChessDemo)
demonstrates Maia beside Stockfish and Arasan. Follow the Demo's setup instructions for its app-owned model.

## Testing and troubleshooting

```sh
Scripts/validate.sh
swift run maia-smoke --output .build/package.json
swift run maia-soak --iterations 200
swift run maia-uci --model Resources/Models/maia3-79m.onnx
```

The local gate covers Debug/Release/Thread Sanitizer tests, actual-model
reference/API/UCI checks, CLI protocol, soak, benchmark and unsigned platform
builds. [Benchmarks](Docs/Benchmarks.md) reports latency and memory measured on
physical Apple hardware. [Testing](Docs/Testing.md) explains how to run checks
and reproduce measurements;
[Troubleshooting](Docs/Troubleshooting.md) covers assets, lifecycle and scores.
GitHub-hosted validation is optional; no workflow is required or automatically run.

## Maintenance and provenance

- [Architecture](Docs/Architecture.md): modules, inputs, outcomes, sampling and ownership
- [Examples](Docs/Examples.md): direct/UCI lifecycle and command-line tools
- [UCI](Docs/UCI.md): options and supported protocol
- [Testing](Docs/Testing.md): local and device validation
- [Provenance](Docs/Provenance.md), [Updating Maia](Docs/UpdatingMaia.md): upstream/assets
- [Benchmarks](Docs/Benchmarks.md): physical hardware, latency, memory and methodology

## Licensing

Project-owned source is **AGPL-3.0-only**, as are the adapted upstream Maia code
and separately provisioned model. See [LICENSE](LICENSE),
[third-party notices](THIRD_PARTY_NOTICES.md) and [Provenance](Docs/Provenance.md).
ONNX Runtime and SwiftChessTools retain their MIT licenses. This is independent
work, not an official CSSLab or Mobile Maia release. Preserve the source/model
licenses and their corresponding-source obligations when distributing derived
packages or applications.
