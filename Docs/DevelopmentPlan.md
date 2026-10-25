# Development plan

Status: planned; only repository setup is complete. No model benchmarks exist.

## 1. Physical-iPhone feasibility

Build a small native harness for a pinned Maia-3 79M ONNX model. Establish CPU
inference before testing acceleration. Compare 5M/23M models if warranted;
passing a smaller model does not prove the 79M model suitable.

Pin upstream code/checkpoint/export/runtime versions and verify model hashes.
Generate reference inputs/outputs from the pinned upstream implementation.
Cover both colors and ratings, opening/middlegame/endgame positions, castling,
en passant, promotions/underpromotions, terminal positions, current-only input,
and reconstructed history. Define numerical tolerances before comparison;
check legality, finite/normalized probabilities, and output orientation.

Measure Release builds on a named physical iPhone/OS: cold startup and first
prediction, warm median/p95, peak/sustained memory, repeat load/unload,
background/resume, cancellation, and a 20-minute inference session including
two-rating predictions. Keep the UI responsive. Record thermal/battery
observations without claiming precise battery life from a short run.

Proposed targets: cold startup within five seconds and warm prediction p95
within one second on the selected baseline phone; no memory termination or
continuing memory growth. These targets are not measured results. Choose and
record the baseline device and memory budget before running the gate.

Deliver reproducible evidence and a proceed/optimize/smaller-model/stop decision.
Simulator or Mac results cannot substitute for the physical-iPhone gate.

## 2. Package and asset integration

After the device gate, establish the runtime integration and caller-supplied
local model URL/metadata contract. Keep large weights out of Git. Add pinned,
checksum-verified model acquisition/export tooling and required notices.

## 3. Direct Swift API

Implement prediction separately from sampled move selection, typed request and
result models, validated history, ratings, seeded sampling, errors, async
lifecycle, cancellation, and stale-result suppression. Keep runtime details
private and share one implementation across consumers.

## 4. UCI layer

Implement the adapter over that API, pin upstream option/protocol semantics,
and test handshakes, history, options, terminal positions, limits, stopping,
resetting, and teardown. Add a thin macOS maia-uci executable using the adapter.
Keep move probability, outcome prediction, and searched evaluation distinct.

## 5. Consumer validation

Add Maia to SwiftChessDemo via UCI when authorized. Validate both player sides,
custom positions, resets/takebacks, interrupted requests, and engine-vs-engine
play on a physical device. Add a direct-API probability comparison example.

## 6. Reusable package readiness

Complete local unit/reference/protocol/soak checks, supported-platform builds,
physical-device acceptance, model provisioning, lifecycle/API docs, provenance,
and license review. GitHub validation stays optional/manual-only. Public GitHub
publication and App Store submission require separate authorization.

## Outside this setup

No application feature parity work, Bluetooth integration, training UI,
release/tag, public visibility change, or App Store submission is authorized by
repository creation alone.
