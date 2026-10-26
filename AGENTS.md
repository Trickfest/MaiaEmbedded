# MaiaEmbedded guidance

## Current scope

This is a private repository with an authorized native inference experiment for
iPhone, iPad, and Mac. Implement/validate the experiment with CLI checks and
simulator builds/runs first; leave physical mobile-device access until the final
stage when devices can be unlocked. Avoid UI automation/XCTest UI tests.
UCI, production API finalization, publication, and visibility changes remain
outside this experiment. Simulator/Mac results do not satisfy physical mobile
acceptance. Commit and push authorization is separate from experiment execution.

## Layout and boundaries

- `Sources/MaiaEmbedded/`: experimental direct prediction API; production API/sampling remain planned.
- `Sources/MaiaUCI/`: planned adapter over that API; no duplicate inference path.
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
builds separately. Read Docs/Validation.md for reference tolerances and the
physical acceptance checklist. Local checks are required;
GitHub-hosted checks are optional and manual-only. Do not add automatic push,
pull-request, or scheduled validation workflows.

Physical-iPhone and physical-iPad correctness/performance evidence, plus native
Mac evidence, must precede finalizing the production API. Simulator results do not satisfy the device gate. Initial
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
