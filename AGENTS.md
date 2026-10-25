# MaiaEmbedded guidance

## Current scope

This is a private repository and SwiftPM scaffold only. Do not change visibility,
publish releases, import weights/runtime dependencies, implement inference/UCI,
or start the device experiment without the user's authorization for that work.
Repository creation is complete setup, not evidence that the model works.

## Layout and boundaries

- `Sources/MaiaEmbedded/`: planned direct Swift prediction and sampling API.
- `Sources/MaiaUCI/`: planned adapter over that API; no duplicate inference path.
- `Examples/iPhoneBenchmark/`: planned physical-device feasibility harness.
- `Tests/`, `Resources/`, `ThirdParty/`, `Scripts/`, `Docs/`: supporting material.

Reuse ChessCore for rules and validated move replay and ChessUCI for appropriate
formatting/parsing helpers. Preserve sibling path dependencies when introduced.
Do not add UI, clocks, game storage, or Bluetooth transport to the engine core.
Do not represent human-move probabilities or human-game outcome predictions as
searched Stockfish evaluations. Prefer instance-owned state and ordered output;
do not redirect process-wide streams for the in-process UCI adapter.

## Validation

Run `Scripts/validate.sh` for scaffold changes. It currently checks the manifest
and Debug/Release builds only, with no tests or inference evidence. Expand it
with real checks as implementation arrives. Local checks are required;
GitHub-hosted checks are optional and manual-only. Do not add automatic push,
pull-request, or scheduled validation workflows.

Physical-iPhone correctness and performance evidence must precede finalizing the
production API. Simulator results do not satisfy the device gate. Initial
latency targets in the plan are proposals, not measured capabilities.

## Source and assets

Project-owned source uses AGPL-3.0-only SPDX headers. Preserve all upstream
notices. Pin upstream revisions, export tools, checkpoint identities, hashes,
and runtime versions before introducing them. Keep model files, downloaded
binaries, signing state, DerivedData, and build products out of Git. No secrets
or personal Apple team identifiers belong in this repository.

Update README, architecture/validation/provenance docs, and CHANGELOG under
Unreleased for significant changes. Retire completed development plans after
useful operating guidance has moved into current docs. Commits, pushes, tags,
releases, and visibility changes require authorization for the relevant work.
