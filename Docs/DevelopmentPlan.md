# Remaining development work

## Starting point

The feasibility experiment is complete on the tested Mac, iPhone and iPad.
Reference correctness, sustained CPU latency/memory, and user-reported mobile
lifecycle checks passed. See [ExperimentResults](ExperimentResults.md).
The current `MaiaExperiment*` API is provisional; `MaiaUCI` is still empty.

Verified inference, checksum-checked local loading, model provisioning scripts,
reference fixtures and benchmark clients already exist. Build on that work rather
than repeating the experiment or treating those pieces as unimplemented.

This roadmap describes remaining work; it is not authorization to implement,
release or change visibility. The repository stays private until explicitly
approved otherwise.

## 1. Production direct Swift API and model integration

- Replace the experimental API with reviewed public types and documented behavior.
  Keep ONNX types/internal details behind the Swift interface.
- Separate position prediction from move selection. Expose legal-move model
  probabilities and human-game outcome predictions separately from sampled moves.
- Define rating validation/defaults, history reconstruction/padding, and terminal
  position behavior. Use ChessCore for rules and validated replay.
- Implement temperature and Top-P selection, deterministic argmax, and seeded
  randomness for reproducible callers/tests. Keep base probabilities distinct
  from the sampling-adjusted distribution.
- Define loading, readiness, model replacement, unloading and shutdown; decide
  request serialization/model reuse and memory-pressure behavior. Preserve ordered
  results, cancellation semantics and stale-result suppression.
- Provide typed failures for invalid inputs, missing/incompatible/corrupt assets,
  runtime failures and canceled work. Specify what cancellation can actually
  interrupt; do not promise instantaneous native-kernel termination.
- Finalize the caller-owned local model URL/metadata contract, compatibility and
  checksum validation, and supported model/runtime/platform policy. Keep implicit
  network downloads out of inference; document bundling versus app-owned storage.
- Promote the proven asset/export tooling and provenance into the supported setup
  workflow. Keep the initial 79M CPU model as the measured baseline; additional
  model sizes/acceleration are optional follow-ups rather than release blockers.

Deliverable: one reusable, documented Swift inference/selection library with
meaningful reference, sampling, failure and lifecycle tests.

## 2. UCI adapter and macOS command-line engine

- Implement MaiaUCI over the same direct Swift API; do not duplicate inference or
  sampling logic. Use instance-owned command state and ordered line output.
- Implement handshake/readiness, options, startpos/FEN plus moves, new-game/reset,
  go, stop and quit with correct request ownership and no late output from old work.
- Follow pinned upstream options: Elo, SelfElo, OppoElo, Temperature, TopP and
  MultiPV. Document defaults, validation and intentional deviations.
- Define honest behavior for clock/movetime limits, depth/nodes, searchmoves,
  infinite analysis and pondering. Clearly reject or document unsupported modes;
  do not fabricate search depth or turn move probability into centipawn evaluation.
- Preserve the distinction between human-move likelihood, human-game outcome
  predictions, and any upstream-compatible score representation.
- Add a thin macOS `maia-uci` stdin/stdout executable over the in-process adapter,
  plus smoke/soak tools and protocol transcript tests.

Deliverable: one UCI implementation usable in-process on Apple platforms and as
a desktop engine executable, with a documented supported protocol surface.

## 3. Validate real consumers

- Add Maia as a UCI engine choice in SwiftChessDemo. Respect its existing transport
  and readiness lifecycle and avoid unnecessary changes to other engines.
- Validate both player sides, custom positions, reset/takeback, interrupted work,
  terminal positions and engine-vs-engine play against Stockfish/Arasan.
- Ensure app displays do not label Maia human probabilities/outcomes as searched
  Stockfish evaluations. Reuse ChessUCI helpers without moving engine scheduling
  or app-specific policy into SwiftChessTools.
- Add a focused direct-API example showing move probabilities and two-rating
  comparison. It must exercise the same core as the UCI path.
- Validate final integrations on the physical Mac, iPhone and iPad, including
  lifecycle behavior; preserve sibling dependencies during current development.

Deliverable: working UCI and direct-API reference clients with recorded local
integration evidence, beyond standalone package tests.

## 4. Package hardening and documentation

- Expand the local validation entry point with unit/reference/protocol tests,
  invalid-input/model tests, cancellation/reset races, repeated load/unload,
  instance isolation, smoke/soak checks and relevant platform builds.
- Recheck correctness and measured performance after material runtime, encoding,
  precision, sampling or lifecycle changes. Broaden to consumers when shared
  behavior changes. UI automation is not required by this roadmap; continue to
  respect the user's testing preferences.
- Document installation and dependency setup, public API/DocC, lifecycle and
  cancellation contracts, model assets, UCI behavior, troubleshooting, updating
  upstreams, licensing/provenance, supported platforms and measured limitations.
- Verify clean-checkout reproducibility, that weights/build products/signing
  state stay out of source, and that required notices accompany distribution.
  Resolve the eventual consumer dependency setup explicitly before publication;
  do not silently replace existing sibling path dependencies.
- Check public API compatibility/versioning policy before declaring a stable API.
  Keep GitHub-hosted validation optional and manual-only.

Deliverable: a reproducible Swift package ready for an intentionally chosen first
release, with source and documentation aligned to actual behavior.

## 5. Distribution, when separately authorized

- Review the final source/model/runtime licenses and notices for the intended
  package/app distribution, including the App Store plan.
- Choose the initial version and source/model provisioning release policy; tag
  and publish only after the local gate passes and publication is requested.
- Keep GitHub private until the user explicitly authorizes public visibility.
  Consider Swift Package Index listing only after public package distribution is
  chosen and its consumer setup works.

## Separate downstream Apple app

MaiaEmbedded does not deliver a complete Mobile Maia-equivalent application.
That later project needs its own scope and design for gameplay/clocks, game
storage and PGN exchange, analysis/review/variation workflows, Maia/Stockfish
comparisons, training features, accessibility/localization and optional physical
board support, followed by device testing and App Store preparation/submission.
The benchmark UI is not that product. Bluetooth and full Android feature parity
are not requirements for completing the embedded library.

## Optional follow-ups

Core ML/Neural Engine acceleration, quantization, smaller/additional models,
batching and further memory/performance tuning can follow demonstrated need.
Every changed model/export/backend must repeat relevant correctness and device
checks. None is required simply to establish the already-proven CPU baseline.
