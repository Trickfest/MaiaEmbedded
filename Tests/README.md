# Tests

MaiaEmbeddedTests covers reference encoding/legality/terminal state, promotion
vocabulary, stable softmax, typed validation/model failures, unloaded inference,
cancellation and sampling. The optional real-model test checks session reuse,
independent instances and unload/reload when MAIA_MODEL_PATH is set.

MaiaUCITests uses a controlled async backend for deterministic readiness,
option/position validation, search restriction, stop, replacement, restart,
seeded isolation and outcome-compatibility tests. It requires no model or Python.
No UI-test target exists.

`swift test` runs the asset-independent gate. `Scripts/validate.sh` requires the
provisioned model and adds Debug/Release/sanitizer, actual-model reference/API/UCI,
CLI, smoke/soak, measured benchmark, DocC and Apple-platform builds. See
[Testing](../Docs/Testing.md).
