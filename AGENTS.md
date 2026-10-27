# MaiaEmbedded guidance

MaiaEmbedded is a public source package for native Maia-3 inference with a direct
Swift API and an in-process UCI adapter. Keep documentation written for package
consumers; record release history in CHANGELOG rather than implementation plans
or sign-off logs.

## Layout and boundaries

- `Sources/MaiaEmbedded/`: inference, predictions, sampling and model lifecycle.
- `Sources/MaiaUCI/`: the instance-owned adapter over the same inference API.
- `Sources/MaiaBenchmarkSupport/` and command-line targets: checks and measurements.
- `Examples/MaiaBenchmark/`: the iPhone/iPad/Mac reference app.
- `Tests/`, `Resources/`, `ThirdParty/`, `Scripts/`, `Docs/`: supporting material.

Use public versioned dependencies so package consumers and SPI need no sibling
checkout. Keep chess rules in ChessCore and app policy/UI outside the engine.
Human-move and outcome probabilities must not be described as searched engine
evaluations. Preserve instance-owned state and ordered output; the UCI adapter
must not redirect process-wide streams.

## Validation and documentation

Run `Scripts/validate.sh` for source changes. It covers tests, model checks,
CLI/soak, DocC and platform builds; see Docs/Testing.md. Inference, memory or
lifecycle changes also need relevant physical iPhone/iPad and native Mac checks.
Do Mac/simulator work first. Avoid unattended UI automation. For documentation
changes, check links, DocC and benchmark data consistency; do not create a patch
release solely for documentation. Hosted checks remain optional/manual-only.

Published benchmark results describe physical hardware with CPU/memory/runtime
settings. Keep measurements and limitations clear, without personal machine
references, conversation transcripts or release-approval records.

## Source and assets

Owned source uses AGPL-3.0-only SPDX headers. Preserve upstream notices and pin
source/checkpoint/export/runtime identities. Keep downloaded weights, binaries,
signing state and generated output out of Git. Update current public guides and
CHANGELOG for significant changes. Commits, pushes, tags, releases and visibility
changes require authorization for the relevant work.
