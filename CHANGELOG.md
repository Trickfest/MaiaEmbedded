# Changelog

## Unreleased

- Replace the experimental types with the actor-owned MaiaSession API, typed
  configuration/requests/errors, legal human-move predictions, outcome access,
  temperature/TopP selection and reproducible random streams.
- Implement the restartable, instance-owned MaiaUCI adapter and maia-uci,
  maia-smoke and maia-soak tools over the same inference core.
- Add protocol/cancellation/restart tests, real-session lifecycle tests, CLI
  integration and a complete local platform validation gate.
- Extend the native reference harness with two-rating probabilities and API/UCI
  reports; document the sibling SwiftChessDemo integration branch.
- Align source organization, examples, testing, troubleshooting, update/provenance
  documentation and DocC with the embedded-engine package family.

- Add an experimental native FP32 Maia-3 79M CPU inference path using pinned
  ONNX Runtime and sibling ChessCore, with verified local model loading.
- Add upstream PyTorch reference fixtures, non-UI Swift tests, a Mac benchmark
  executable, and a shared SwiftUI iPhone/iPad/Mac benchmark app.
- Add pinned model provisioning, reference regeneration, JSON performance reports,
  and headless simulator launch scripts. Native Mac and physical-iPhone/iPad
  inference acceptance passed; manual mobile lifecycle checks passed per user report.

- Establish a private SwiftPM scaffold for MaiaEmbedded and its MaiaUCI adapter.
- Record the native Apple architecture and physical-iPhone feasibility plan.
