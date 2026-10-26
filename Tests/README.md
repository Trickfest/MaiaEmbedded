# Tests

`MaiaEmbeddedTests` uses Swift Testing for upstream encoding/legality/terminal
fixtures, promotion indexing, stable softmax, request validation, failed model
loading, unloaded inference, and pre-canceled prediction rejection. No UI test
target exists. Run `swift test` or `Scripts/validate.sh`.

Real-model numeric comparisons, repeated load/unload, latency and sustained
memory checks run through `maia-benchmark` and the shared app harness. Those
checks require the separately downloaded verified 79M model. See
[Validation](../Docs/Validation.md).
