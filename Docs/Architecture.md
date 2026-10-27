# Architecture

```text
Native Swift app         UCI consumer / maia-uci
       |                         |
       |                     MaiaUCI
       +----- MaiaEmbedded ------+
                      |
            ChessCore + ONNX Runtime
                      |
             Caller-owned local model
```

## Modules and source organization

`Sources/MaiaEmbedded` holds configuration, requests, encoding, predictions,
sampling and session ownership in separate Swift files. `Sources/MaiaUCI`
holds the instance-owned adapter. `MaiaCLI` is a thin stdin/stdout host;
`MaiaSmoke` and `MaiaSoak` share checks in `MaiaBenchmarkSupport`. The support
module and native example own measurements/reports; the engine core has no UI,
clocks, game storage or networking. Public module catalogs provide Xcode DocC.

ChessCore supplies semantic FEN validation, move replay, legality and outcomes.
ONNX types stay internal. SwiftChessTools resolves from its public semantic-version
dependency; applications may supply a matching local checkout during development.
CPU FP32, basic graph optimization and two intra-op threads are the measured
default. Threads may be configured from 1 through 16 before session creation;
other settings/model sizes/providers require separate measurement.

## Direct API contracts

`MaiaConfiguration` accepts a local model URL. `MaiaSession.prepare()` validates
configuration, size, SHA-256 and tensor names, then retains one runtime session.
It is idempotent. `unload()` clears it and allows another prepare; create a new
session to change configuration/model URL. No implicit model acquisition occurs.

`MaiaRequest` contains the initial six-field FEN, coordinate UCI moves, history
mode and side-to-move/opponent ratings. Both ratings default to 1600 and must
be 600...2600. These are human Lichess conditioning levels, not calibrated
playing-strength guarantees. FEN input is limited to 1024 UTF-8 bytes, history
to 20,000 moves; every supplied move is legally replayed. Validation does not
prove historical reachability of a FEN.

History mode uses the last eight replayed positions and pads a short line with
its earliest position. Current-only mode repeats the final board. Earlier
history cannot be inferred from a standalone FEN. Encoding mirrors Black's
ranks/colors per history board, matches the pinned 64×97 tensor and 4352-entry
move vocabulary, and masks policy logits to legal moves.

`MaiaPrediction` exposes original legal logits/probabilities, stable likelihood
ranking and a loss/draw/win human-game outcome distribution relative to the side
to move. The value head predicts outcomes of human games; it is not searched
position evaluation. Terminal ChessCore outcomes return an empty policy and
known outcome without native inference. Preparation is still required. Claims,
resignation, timeout and history before the supplied root are caller-owned.

`MaiaSampler` separates selection from prediction. Temperature 0 gives stable
argmax; otherwise it rescales logits, restricts to an optional legal-move
intersection and applies TopP. TopP follows the pinned upstream convention:
retain cumulative probabilities **<= TopP**, retaining at least one move;
TopP=1 keeps all. Thus it can exclude the candidate crossing the threshold.
Temperature must be finite in 0...5; TopP finite in (0,1]. Original probabilities
are preserved; `selectionProbabilities` contains the adjusted distribution.
An empty nonterminal intersection throws. Terminal selection returns nil.

A provided seed is reproducible per call using SplitMix64. Use the generic
`using:` overload with a retained generator for a reproducible series. Sampling
reproducibility assumes identical logits; floating-point inference differences
near boundaries can change choices across platforms.

## Ownership, cancellation and errors

Actor isolation serializes load/predict/unload. Native calls do not suspend;
unload waits behind work already executing. Temporary Objective-C allocations
are scoped per operation. A canceled Swift task throws `CancellationError` at
checkpoints before/after work; native kernels are not forcibly terminated.
Callers should invalidate old request identities when a screen or position
changes, cancel its task and observe completion before reusing UI results.

`MaiaError` distinguishes invalid requests, missing/incompatible models,
unprepared sessions and runtime failures. Error details are diagnostic text,
not a stable parser format. Failed preparation leaves the session unloaded;
fix the asset and retry. Serialized calls on one session reuse its weights;
independent instances each consume substantial memory.

The UCI adapter adds request/instance identities and ordered callbacks around
this same API. See [UCI](UCI.md) for restart, readiness and stop semantics. The
Demo's shared lifecycle coordinator also awaits Maia cleanup before creating a
replacement transport, avoiding overlapping model loads during engine switches.
