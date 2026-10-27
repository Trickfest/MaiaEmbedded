# Troubleshooting

| Symptom | Action |
| --- | --- |
| Model missing / example build cannot copy it | Run `Scripts/download-model.sh`; use its resulting local URL or bundle copy. |
| Incompatible size/hash/schema | Restore the pinned export. Renaming another Maia model does not make it compatible. |
| Package cannot find ChessCore | Resolve the public SwiftChessTools dependency; remove unintended local overrides and retry package resolution. |
| Runtime binary download fails | Resolve the pinned official ONNX SwiftPM dependency with network access; no runtime download occurs in the app. |
| notLoaded | Await `prepare()` before direct predict/select. UCI clients await readyok. |
| isready never completes | Check MaiaEmbedded error lines and startup timeout; no readyok is sent after failed preparation. |
| go movetime/depth gives immediate result | Maia runs one inference. These controls do not add search or calibrate Elo. |
| Moves repeat | Temperature 0 is deterministic; repeating a direct-call seed restarts sampling. Retain a generator for a sequence. |
| No cp evaluation / one-move PV | Expected default. Maia emits human-move probabilities. OutcomeScores is opt-in and has different semantics. |
| Cancel does not instantly free memory | Native kernels finish before cancellation/unload. Await shutdown and avoid overlapping loaded models. Allocators may retain pages. |
| New screen receives an old result | Keep a request/generation identity in the UI and reject replaced operations. UCI also invalidates internal request identities. |
| Simulator device is unavailable | Use `xcrun simctl list devices available` and pass an installed destination/UDID. |
| Physical signing/lock/trust prompt | Configure ignored local signing and ask the owner to unlock/trust the device. Simulator/unsigned builds do not satisfy physical verification. |

Do not compare host simulator timings to actual mobile performance. Keep logs,
weights, DerivedData, signing files and device identifiers out of commits.
