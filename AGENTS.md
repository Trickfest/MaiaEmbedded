# MaiaEmbedded guidance

## Current scope

The approved direct Swift API, UCI layer, SwiftChessDemo integration, tests and
documentation are implemented. Local gates and final verification passed on the
tested Mac, physical iPhone and physical iPad; see Docs/Testing.md. Keep this
repository private and do not tag or publish a release. For future changes,
complete Mac/simulator work before requesting final physical-device access.
Avoid unattended UI automation. Commit/push still require authorization.

## Layout and boundaries

- `Sources/MaiaEmbedded/`: direct Swift inference, prediction and sampling API.
- `Sources/MaiaUCI/`: restartable instance-owned adapter over that API; no duplicate inference path.
- `Sources/MaiaBenchmarkSupport/` and `Sources/MaiaBenchmarkCLI/`: shared checks and Mac runner.
- `Examples/MaiaBenchmark/`: native iPhone/iPad/Mac feasibility harness.
- `Tests/`, `Resources/`, `ThirdParty/`, `Scripts/`, `Docs/`: supporting material.

Reuse ChessCore for rules and validated move replay and ChessUCI for appropriate
formatting/parsing helpers. Preserve sibling path dependencies when introduced.
Do not add UI, clocks, game storage, or Bluetooth transport to the engine core.
Do not represent human-move probabilities or human-game outcome predictions as
searched Stockfish evaluations. Prefer instance-owned state and ordered output;
do not redirect process-wide streams for the in-process UCI adapter.

## Validation

Run `Scripts/validate.sh` for source changes: manifest, non-UI Swift Testing
checks, and Release build. Run the real-model CLI benchmark and relevant app
builds separately. Read Docs/Testing.md for reference tolerances and the
physical acceptance checklist. Local checks are required;
GitHub-hosted checks are optional and manual-only. Do not add automatic push,
pull-request, or scheduled validation workflows.

Physical-iPhone and physical-iPad correctness/performance evidence, plus native
Mac evidence, must precede finalizing the production API. Simulator results do not satisfy the device gate. The original feasibility evidence is historical; final integration verification is separate.

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
