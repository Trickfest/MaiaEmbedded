# Validation

## Current scaffold gate

Run `Scripts/validate.sh` from a macOS host with Swift 6.2 or newer. It validates
Package.swift and builds empty MaiaEmbedded/MaiaUCI modules in Debug and Release.
There are no test targets yet. Passing this gate provides package-scaffold
validation only; it proves no model behavior, iPhone support, or performance.
Generated files stay in ignored .build. No model/network access is needed.

## Planned implementation gates

Add reference-output tests for encoding, legality, history, ratings, sampling,
and outcomes; protocol/lifecycle tests for UCI; and runtime load/unload/soak
checks. Check FP32 reference tolerances before investigating reduced precision.
Add simulator/generic-device builds and physical-iPhone benchmarks with recorded
model/checkpoint/export/runtime identity, device/OS, build configuration,
correctness tolerances, latency distribution, memory, and sustained behavior.
See DevelopmentPlan.md. Test dependent apps when integration changes.

Local validation is required. Hosted validation is optional, manual-only, and
not a release/completion criterion. No hosted workflow is installed yet.
