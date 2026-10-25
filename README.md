# MaiaEmbedded

A native Swift package planned for on-device Maia-3 human-move prediction on
iOS/iPadOS and macOS, with a direct Swift API and a UCI adapter over that API.

**Status: repository and package scaffold only.** Neither inference nor UCI
behavior is implemented. No model or inference runtime is bundled, and no
physical-iPhone benchmark has run. The repository is private; publication
requires separate authorization.

## Package structure

| Path | Responsibility |
| --- | --- |
| `Package.swift` | SwiftPM products; initial Swift 6.2, iOS 26 and macOS 26 baseline |
| `Sources/MaiaEmbedded/` | Direct Swift API and inference implementation, planned |
| `Sources/MaiaUCI/` | In-process UCI adapter over the direct API, planned |
| `Tests/` | Correctness and protocol test suites, planned |
| `Examples/iPhoneBenchmark/` | First physical-iPhone experiment, planned |
| `Resources/Models/` | Model provisioning policy; weights stay out of Git |
| `ThirdParty/` | Dependency and upstream provenance policy |
| `Scripts/validate.sh` | Package-scaffold validation only |
| `Docs/` | Architecture, development plan, validation, and provenance |

## First milestone

Prove the pinned Maia-3 79M model on a physical iPhone using an ONNX Runtime CPU
baseline. Compare predictions with upstream reference results and measure cold
startup, warm latency, peak/sustained memory, lifecycle behavior, and a 20-minute
session. Smaller models and acceleration are follow-up comparisons if needed.
See [the development plan](Docs/DevelopmentPlan.md) for gates and scope.

## Local validation

```sh
Scripts/validate.sh
```

This validates the manifest and builds the empty modules in Debug and Release.
It is not an engine test, model-quality check, device benchmark, or platform
compatibility certification. There are no implemented tests yet.

## Architecture

Native apps call `MaiaEmbedded` directly. UCI consumers use `MaiaUCI`, which
calls the same direct API. A future macOS `maia-uci` executable will adapt the
same UCI implementation to standard input/output. No Python process or Flutter
port is planned for Apple apps.

ChessCore will supply rules and legal replay through the sibling
`../SwiftChessTools` package when needed; no dependency is added in this scaffold.
ChessUCI remains a command-formatting/output-parsing helper. App UI, clocks,
storage, training workflows, and electronic-board integration are app concerns.
See [Architecture](Docs/Architecture.md).

## Licensing and provenance

Project-owned source is licensed under **AGPL-3.0-only**; see [LICENSE](LICENSE).
No upstream code, model weights, or runtime binaries have been imported.
Upstream Maia-3 source and checkpoint terms and ONNX Runtime notices must be
verified and retained when those components are introduced. See
[Provenance](Docs/Provenance.md) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

The intended future application is open source and App Store distributed.
Publication and distribution-license review remain future work. This is an
independent project, not an official CSSLab or Mobile Maia release.
