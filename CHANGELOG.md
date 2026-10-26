# Changelog

## Unreleased

- Add an experimental native FP32 Maia-3 79M CPU inference path using pinned
  ONNX Runtime and sibling ChessCore, with verified local model loading.
- Add upstream PyTorch reference fixtures, non-UI Swift tests, a Mac benchmark
  executable, and a shared SwiftUI iPhone/iPad/Mac benchmark app.
- Add pinned model provisioning, reference regeneration, JSON performance reports,
  and headless simulator launch scripts. Native Mac and physical-iPhone/iPad
  inference acceptance passed; manual mobile lifecycle checks passed per user report.

- Establish a private SwiftPM scaffold for MaiaEmbedded and its MaiaUCI adapter.
- Record the native Apple architecture and physical-iPhone feasibility plan.
- UCI remains an empty scaffold; implementation follows the finalized direct API.
