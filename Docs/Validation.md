# Validation

## Non-UI local checks

```sh
Scripts/validate.sh
Scripts/download-model.sh
Scripts/run-mac-benchmark.sh 1200
```

`validate.sh` runs manifest validation, non-UI Swift Testing checks, and a Release
build. It uses no UI-test target, accessibility automation, or hosted workflow.
The real-model benchmark separately checks 20 PyTorch reference cases, performs
100 warm predictions, a same-model two-rating comparison, a sustained workload,
pre-canceled request rejection, and two load/predict/unload cycles. Reports go
to `.build/results/`; a failed run exits nonzero and does not produce a completed
report. An older report at the same output path is not evidence for a failed run;
check timestamps and command exit status.

A fixed corpus covers low/high and asymmetric ratings, both colors, opening
sequences, current-only/eight-position history and short-history padding,
castling, en passant, quiet/capture promotions and underpromotions, check,
checkmate, stalemate, and insufficient material. Swift-generated FP32 tensor
bytes must exactly match upstream SHA-256; legal move sets and terminal status
must agree. Max absolute raw legal-move/value logit error is <= 1e-4, probability
error <= 1e-5, and probability sums must differ from one by < 1e-6. These
thresholds were set before reading Swift inference results. The fixture generator
also compares all exported heads to PyTorch at 1e-4, including the unused ponder
head. The predictor requests only move/value heads.

## App builds

After downloading the model:

```sh
xcodebuild -project Examples/MaiaBenchmark/MaiaBenchmark.xcodeproj -scheme MaiaBenchmark -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/xcode-maia -clonedSourcePackagesDirPath .build/xcode-maia/SourcePackages CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Examples/MaiaBenchmark/MaiaBenchmark.xcodeproj -scheme MaiaBenchmark -configuration Release -destination 'generic/platform=iOS' -derivedDataPath .build/xcode-device -clonedSourcePackagesDirPath .build/xcode-device/SourcePackages CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Examples/MaiaBenchmark/MaiaBenchmark.xcodeproj -scheme MaiaBenchmark -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/xcode-mac -clonedSourcePackagesDirPath .build/xcode-mac/SourcePackages CODE_SIGNING_ALLOWED=NO build
```

Build success is distinct from runtime acceptance. The existing simulator script
uses the booted device's UDID and starts the app with `--autorun --iterations 100
--duration 30`; it does not drive UI. Retrieve the report after completion:

```sh
simulator_container=$(xcrun simctl get_app_container SIMULATOR_UDID org.maiaembedded.experiment.MaiaBenchmark data)
cp "$simulator_container/Documents/maia-benchmark.json" .build/results/simulator.json
```

The JSON explicitly marks simulator results. The same iOS binary supports iPhone
and iPad. Runtime model files and the support resource bundle must be present
in the built app.

## Physical feasibility acceptance (passed on tested devices)

Use a Release build on the actual iPhone, iPad, and this Mac. Record device model,
OS, model hash, runtime settings and workload. Initial targets are cold model
verification/load plus first prediction <= 5 s and warm p95 <= 1 s. The experiment
uses an explicit 1024 MiB footprint budget; it is not an OS process limit
or a universal iOS allowance. Record memory warnings/termination and revise the
supported-device policy based on actual evidence rather than raising a budget to
make a result pass.

The paced 20-minute foreground test adds a 100 ms pause after each inference,
alternates ratings, and records sampled footprint, early/late latency windows,
and thermal-state transitions. First/last footprint difference <= 64 MiB is a
screening metric, not proof of no leak. Inspect repeated cycles and long-run
behavior. Native allocators can retain pages after unload; freeing a model does
not promise an immediate drop in physical footprint. Both between-call samples and kernel-reported lifetime peak footprint/resident
memory are recorded. Samples alone miss transient intra-kernel peaks. The
`kernelMemoryBudgetMet` field uses the kernel footprint peak; use Instruments
if headroom is tight or memory metrics are unavailable. Cold timings mean a
fresh model session, without filesystem-cache eviction.

Manually verify background/resume and responsive controls at the final physical
stage. Backgrounding cancels the current run; resuming permits a fresh run.
Cancellation suppresses results but does not immediately interrupt native ONNX
execution. Pre-canceled rejection is automated; in-flight cancellation, graceful
background behavior, and stale-result UI suppression require physical review
when behavior changes. The current experiment passed these manual checks per
the user report.
Do not claim battery life from these short runs. Core inference and sustained performance have passed on the tested physical
iPhone and iPad. The user reports all prescribed manual lifecycle checks passed on both devices;
see ExperimentResults.md and the manual lifecycle evidence JSON. This closes
feasibility acceptance, not production-package qualification. Keep physical identifiers/signing details
out of committed reports.

With local signing configured and the device unlocked/trusted, use:

```sh
Scripts/run-device-benchmark.sh DEVICE_IDENTIFIER 1200
Scripts/collect-device-report.sh DEVICE_IDENTIFIER SIGNED_BUNDLE_IDENTIFIER .build/results/physical-device.json
```

The run helper installs/launches through devicectl and does not request account
provisioning updates or drive UI. Keep the device foreground for the duration.
These helpers will not bypass device locks, trust requests, or signing/keychain
prompts. Unlock/trust devices and finish local signing when their owner is present.
The collection helper is a separate action after completion; it does not infer
success from installation or launch. Both helpers have been verified on the physical iPad; the same build/install,
console launch and collection flow has also passed on the physical iPhone.

## Reference reproduction

`Scripts/prepare-reference.sh` provisions the pinned checkpoint and isolated
Python 3.13 tools, verifies hashes/source revision, and regenerates the fixture.
The reference tools use upstream PyTorch on CPU; they are never embedded in the
Apple app. Runtime output comparisons must pass again for changed model exports,
precision, runtime version, or execution providers.

Local validation is required. GitHub-hosted validation is optional/manual-only.
There is no hosted workflow and no XCTest UI suite for this experiment.
