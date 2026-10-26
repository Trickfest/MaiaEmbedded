# MaiaEmbedded

Experimental native Swift Maia-3 inference for iPhone, iPad, and Mac. The intended
architecture is a direct Swift API with a UCI adapter over the same core.

**Status:** the CPU inference experiment is implemented. Its API is provisional;
native Mac, physical-iPad and physical-iPhone inference/performance checks pass.
Remaining mobile lifecycle acceptance is still pending. `MaiaUCI` remains
an empty reserved module. The repository is private and has no release. See
[experiment results](Docs/ExperimentResults.md) for measured Mac, physical-iPhone/iPad and simulator evidence
and the remaining acceptance checks.

## Layout

| Path | Responsibility |
| --- | --- |
| `Sources/MaiaEmbedded/` | Experimental model loading, validated encoding and prediction |
| `Sources/MaiaUCI/` | Reserved UCI adapter; not implemented |
| `Sources/MaiaBenchmarkSupport/` | Shared reference corpus, checks and measured benchmark |
| `Sources/MaiaBenchmarkCLI/` | Native Mac command-line benchmark |
| `Tests/MaiaEmbeddedTests/` | Non-UI Swift Testing checks |
| `Examples/MaiaBenchmark/` | SwiftUI iPhone/iPad/Mac experiment app |
| `Resources/Models/` | Pinned model metadata; downloaded weights ignored |
| `Tools/` | Isolated Python/PyTorch reference generation; not part of the app |
| `ThirdParty/` | Upstream licenses and attribution |
| `Scripts/` | Asset provisioning and local validation/benchmark helpers |
| `Docs/` | Architecture, validation, provenance and remaining development plan |

The package uses Swift 6.2+, iOS/iPadOS 26+, macOS 26+, sibling
`../SwiftChessTools` for ChessCore, and ONNX Runtime's official SwiftPM package
pinned to 1.24.2. The current experiment uses the original FP32 Maia-3 79M ONNX
export on CPU with two intra-op threads. No Core ML acceleration is enabled.

## Run the experiment

```sh
Scripts/download-model.sh
Scripts/validate.sh
Scripts/run-mac-benchmark.sh 1200
```

Model provisioning is explicit and checksum-verified. Benchmark inference is
fully local; it never fetches models. Large model/checkpoint/build files remain
ignored. Reference fixtures are included; Python is needed only to regenerate
them with `Scripts/prepare-reference.sh` (Python 3.13).

Open `Examples/MaiaBenchmark/MaiaBenchmark.xcodeproj` for the app. It bundles the
verified local model for offline testing on iPhone, iPad and Mac. Copy its
`Configurations/Signing.local.xcconfig.example` to the ignored local signing
file before physical-device development. No personal team ID is tracked.

For a booted simulator, `Scripts/run-simulator-benchmark.sh SIMULATOR_UDID 30`
launches the app with arguments and writes a JSON report without XCTest or UI
automation. Simulator latency is host-Mac performance, not a mobile-device gate.
See [Validation](Docs/Validation.md) for commands, thresholds and limitations.

## API and boundaries

`MaiaExperimentSession` owns one verified model session. Its async actor methods
load, predict and unload; inputs include a validated starting FEN, legal move
sequence, ratings and optional history. Predictions expose legal move
probabilities and a loss/draw/win human-game outcome distribution. These are
not Stockfish search evaluations. Cancellation suppresses results before/after
inference; it does not promise immediate native-kernel interruption.

This experiment does not yet implement move sampling, UCI, game UI, clocks,
storage, training workflows, or Bluetooth. Those remain separate steps. See
[Architecture](Docs/Architecture.md) and [DevelopmentPlan](Docs/DevelopmentPlan.md).

## Licensing

Project-owned source is **AGPL-3.0-only**; see [LICENSE](LICENSE). Maia's encoding
and vocabulary adaptation and model retain their upstream notices; ONNX Runtime
and ChessCore retain their own licenses. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
and [Provenance](Docs/Provenance.md). This independent project is not an official
CSSLab or Mobile Maia release. Public publication and App Store distribution
remain separately authorized future work.
