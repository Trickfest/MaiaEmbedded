# Changelog

## Unreleased

## 1.1.0 - 2026-10-27

- Rewrite public guides around package installation, API use, testing and model
  provenance; remove obsolete implementation/release sign-off records.
- Publish physical-hardware benchmark summaries with CPU/memory specifications,
  preserving numeric measurements and removing simulator results.
- Expand Quick Help documentation for the direct API, UCI adapter and benchmark
  helpers, including lifecycle, cancellation, sampling and measurement units.
- Add a DocC guide for benchmark support and improve the runnable API examples.
  Runtime behavior and existing public API signatures are unchanged.

## 1.0.0 - 2026-10-27

- Introduce native Maia-3 79M FP32 inference with pinned ONNX Runtime and public
  SwiftChessTools dependencies for iOS, iPadOS and macOS.
- Provide the actor-owned MaiaSession API, typed requests/errors, legal human-move
  probabilities, outcome access, history, temperature/TopP selection and seeded RNGs.
- Provide a restartable in-process UCI adapter and maia-uci desktop executable
  over the same inference core.
- Include explicit model provisioning and checksum checks, independent PyTorch
  reference fixtures, package tests, CLI smoke/soak tools and a native benchmark app.
- Include architecture, examples, testing, troubleshooting, provenance and DocC
  documentation with Swift Package Index configuration.
