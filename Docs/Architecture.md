# Architecture

Status: the direct inference experiment is implemented; production API and UCI
adapter remain proposed. The experimental API must not be treated as stable.

```text
Native Swift app          UCI consumer
       |                       |
       |                    MaiaUCI
       |                       |
       +------ MaiaEmbedded ---+
                       |
             Encoding and inference
                       |
             Runtime + local model
```

## Direct API

Separate prediction from move selection. Prediction should expose legal-move
probabilities and supported human-game outcome predictions. Selection should
apply temperature/Top-P to a prediction without confusing adjusted sampling
probabilities with the model's base distribution.

Requests will include a validated position, optional validated history, and
side-to-move/opponent ratings. Design async loading and inference, reproducible
sampling, typed errors, cancellation/stale-result suppression, and explicit
load/unload/shutdown. Reuse one loaded model for sequential rating comparisons.
Current `MaiaExperiment*` names/types are provisional. The actor-based session
implements verified loading, validated replay/encoding, prediction and unload.
FP32 softmax is applied only over legal moves; value outcomes are separate.
Objective-C temporary lifetimes are scoped per operation using autorelease pools.
Cancellation is checked before and after inference; native kernels are not
forcibly interrupted. Final API and sampling follow physical-device acceptance.

## UCI adapter

Wrap the direct API. Follow a pinned upstream Maia-3 implementation for options
such as Elo, SelfElo, OppoElo, Temperature, TopP, and MultiPV, with deviations
explicitly documented. Define readiness, history reconstruction, stopping,
new-game/reset, and shutdown; ensure old requests cannot emit into new positions.
Specify the handling of clock limits, depth/nodes, searchmoves, infinite analysis,
and pondering before claiming support. Do not fake search depth or translate
move likelihood into a centipawn evaluation. Any WDL-derived compatibility score
must be identified as a human-game outcome estimate.

The in-process adapter uses instance-owned command state and ordered output.
A later macOS executable can adapt that same layer to stdin/stdout; Apple mobile
apps use it in process. No subprocess-based Python runtime is planned.

## Dependencies and ownership

The experiment uses pinned ONNX Runtime 1.24.2 CPU inference; benchmark acceleration if
needed rather than assuming Core ML or Neural Engine acceleration works. Keep
runtime types internal. Model identity and encoding must match the checkpoint.

The experiment uses ChessCore for rules, legality, FEN, and replay.
Preserve the sibling SwiftChessTools path during development. ChessUCI stays a
formatting/parsing helper, not an engine scheduler. UI, clocks, persisted games,
review/training workflows, and board transport belong to consuming apps.
