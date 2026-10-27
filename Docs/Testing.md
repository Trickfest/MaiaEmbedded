# Testing

## Local gate

```sh
Scripts/download-model.sh
Scripts/validate.sh
```

The required gate validates the manifest, Debug/Release builds and non-UI Swift
Testing checks, Thread Sanitizer, real-model direct session reuse/independence,
CLI stdin/stdout/quit, 20-request smoke, 200-request soak, a 30-second measured
benchmark and Release reference-app builds for native Mac, simulator and unsigned
iOS device. It uses no accessibility automation, UI-test target or hosted workflow.
Thread Sanitizer instruments Swift ownership/queues; the official runtime binary
is not rebuilt with instrumentation.

`swift test` also works without the model/Python: the explicitly asset-dependent
session test is skipped unless MAIA_MODEL_PATH is set. The complete gate sets
that variable and requires the provisioned asset. Reference fixtures are tracked;
Python is only needed to regenerate them.

Protocol tests use a controlled backend to test readiness failures/retry,
invalid command isolation, rating propagation, searchmoves/MultiPV, held infinite
results, stop during native work, position replacement, seeded instance isolation,
cleanup/restart barriers and stale-result rejection without timing guesses.
Sampling tests check reproducible streams, argmax, filtering, TopP boundaries,
invalid values and terminal selection. Real-model checks verify the same paths
against the runtime and legal corpus, rather than asserting engine strength.

Reports go to `.build/results/`; failure exits nonzero. Check timestamps and
process status: an older JSON at the same path is not proof of a failed new run.
The benchmark checks 20 PyTorch reference cases, warm timing, two ratings,
sustained behavior, pre-cancellation and load/unload cycles.

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
see [ExperimentResults](ExperimentResults.md) and the manual lifecycle evidence JSON. This closes
feasibility acceptance, not production-package qualification. Keep physical identifiers/signing details
out of committed reports.

With local signing configured and the device unlocked/trusted, use:

```sh
Scripts/run-device-benchmark.sh DEVICE_IDENTIFIER 1200
Scripts/collect-device-report.sh DEVICE_IDENTIFIER SIGNED_BUNDLE_IDENTIFIER .build/results/physical-device.json
# Final API/UCI integration check and its separate report:
Scripts/run-device-benchmark.sh DEVICE_IDENTIFIER 0 --package-checks
Scripts/collect-device-report.sh DEVICE_IDENTIFIER SIGNED_BUNDLE_IDENTIFIER .build/results/physical-package.json maia-validation.json
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

## Final package/consumer acceptance

The original feasibility runs above are historical. After implementation, verify
this current package again on Mac and iPhone/iPad simulators, then on physical
iPhone and iPad. Simulator reports explicitly say isSimulator=true; installation
or successful launch alone is not a result.

The native example's `--package-checks` run writes Documents/maia-validation.json:
20 direct reference checks, two rating policies from one loaded session, UCI
legal/terminal requests, infinite stop and teardown/restart. Its separate benchmark
records timing/memory. Collect fresh completed reports from each platform.

On each physical mobile device, finally verify responsive scrolling, background
cancellation, cancel/restart with no stale UI result, and these Demo workflows:

- Play human versus Maia from both colors, including a promotion/custom position
  when practical; adjust ratings/sampling/history while idle and verify replies.
- Show several Maia suggestion arrows/likelihoods and confirm the independent Stockfish evaluation
  bar stays in place as the move engines change; switch Maia → Stockfish/Arasan → Maia.
- Step/play Maia versus Stockfish and Arasan with swapped colors, pause, reset and
  leave/reenter the game, confirming one legal move per turn and responsive UI.

Use the existing signed development configuration with the owner present to
unlock/trust devices. No release, provisioning-account change or UI automation is
part of this gate. Current implementation evidence and any pending physical gate
are recorded below; original feasibility reports cannot substitute for it.

### Current implementation evidence — 2026-10-26

The final source passed the complete local package gate: 23 tests with the
actual model in Debug, Release and Thread Sanitizer; both DocC catalogs; real
stdin/stdout/quit checks; 20-request smoke and 200-request soak; measured Mac
benchmark; native Mac, simulator and unsigned iOS Release app builds. A separate
source copy without weights/signing/build state passed its model-free test gate.
Stockfish's ObjC/Swift CLI smoke builds/runs also passed.

SwiftChessDemo's Maia branch passed all 106 non-UI app-hosted unit/integration
tests and generic iOS Release/asset validation. This includes real Maia against
Stockfish and Arasan in both color assignments. UI automation was deliberately
excluded under the user's testing preference, not reported as passed.

Fresh API/UCI reports passed all 20 reference cases and 20 UCI requests on this
Mac, iPhone 18 Pro simulator (iOS 27), iPad Pro simulator (iPadOS 27), and iPhone
Air simulator (iOS 26.5). Maximum logit/probability errors remained within the
predeclared 1e-4/1e-5 thresholds. Simulator reports identify their hardware and
isSimulator=true. The Mac benchmark also met its latency/memory screening targets.

- [Working source identity and gate scope](Benchmarks/2026-10-26/production-environment.json)
- [Mac API/UCI report](Benchmarks/2026-10-26/package-mac.json)
- [Mac benchmark](Benchmarks/2026-10-26/production-mac.json)
- [iPhone simulator](Benchmarks/2026-10-26/package-iphone-simulator.json)
- [iPad simulator](Benchmarks/2026-10-26/package-ipad-simulator.json)
- [Minimum-version iOS simulator](Benchmarks/2026-10-26/package-ios26-simulator.json)

### Physical iPhone final regression — 2026-10-26

The current signed Release harness ran on the physical iPhone 16 Pro Max,
iOS 27.0.1. Fresh completed reports were retrieved and verified against the
expected physical hardware, model hash and run timestamps. All 20 upstream
reference cases and 20 UCI requests passed, including infinite stop and adapter
teardown/restart. Maximum logit/probability errors were 2.29e-5 / 4.95e-6.

The short 30-second performance regression passed: cold verification/load plus
first prediction 0.448 s, warm median/p95 16.1/16.5 ms, kernel peak 754.8 MiB,
194 paced predictions, nominal thermal state, two reload cycles and pre-canceled
request rejection. This short run supplements the historical 20-minute physical
feasibility run; it is not a new battery-life or long-duration qualification.

- [iPhone API/UCI report](Benchmarks/2026-10-26/package-iphone-physical.json)
- [iPhone benchmark](Benchmarks/2026-10-26/production-iphone-physical.json)

The user reports normal scrolling/no unusual warmth on this iPhone and working
Demo gameplay, settings/suggestions, engine switching, engine-vs-engine and
background/reset. The user identified a layout issue: hiding the evaluation bar
on Maia turns shifts the board. The correction keeps its geometry stable and
uses separate Stockfish scores while Maia continues to choose its moves. No
extra visible source label is added.

The corrected Demo passes 105 non-UI unit/integration tests, generic iOS Release
validation and Stockfish CLI smokes. Its signed Release build was installed and
launched on the physical iPhone. The user then confirmed the focused bar/layout
and live-score recheck: “Fixed; the board stays steady.” This is direct manual
feedback, separate from the automated package/benchmark reports.

Final iPhone verification is complete on the tested device. The iPad results
follow below. Source is maintained on development branches; MaiaEmbedded remains
private with no release.

### Physical iPad final regression — 2026-10-26 (America/Chicago)

The current signed Release harness ran on the physical iPad Pro 13-inch (M4),
iPadOS 27.0.1. Fresh completed reports were retrieved and matched to the expected
physical hardware, pinned model hash and current run timestamps. Raw report
timestamps use UTC. All 20 reference cases and 20 UCI requests passed, including
infinite stop and adapter teardown/restart. Maximum logit/probability errors
were 2.29e-5 / 4.95e-6.

The short performance regression passed: cold verification/load plus first
prediction 0.409 s, warm median/p95 14.3/14.5 ms, kernel peak 756.0 MiB, 212
paced predictions over 30 seconds, nominal thermal state, two reload cycles and
pre-canceled request rejection. This supplements the original 20-minute iPad
feasibility run; it is not a battery-life or new long-duration qualification.
The user reports normal scrolling and no unusual warmth.

- [iPad API/UCI report](Benchmarks/2026-10-26/package-ipad-physical.json)
- [iPad benchmark](Benchmarks/2026-10-26/production-ipad-physical.json)

The corrected signed Demo was installed and successfully launched on this iPad
with Maia selected and its model size/hash verified. The user confirmed the
manual gameplay/settings/suggestions, engine switching, mixed-engine play,
stable bar/board layout, rotation and background/reset check: “All iPad checks
passed.” This is direct user evidence, separate from automated numerical reports.

The approved implementation and final verification are complete on the tested
Mac, iPhone and iPad. The package's 23 tests, Demo's 106 non-UI tests, platform
builds, actual-model gates and device/manual evidence are recorded above. No
UI-automation result, battery-life measurement or broader hardware qualification
is claimed. Public distribution, release tags and App Store work remain separate
future authorization. MaiaEmbedded remains private and unreleased; the Demo
integration is maintained on its separate development branch.

### Final-review settings regression — 2026-10-26

Final review found that Maia settings were disabled after an engine-demo game
ended. The eligibility guard now allows edits before Play Again, which preserves
the updated ratings, sampling and history settings. Settings remain locked while
play or analysis is active. The new regression test failed before the fix and
passed afterward; the complete 106-test headless Demo gate and unsigned iOS
Release/asset checks then passed.

This small app eligibility change was verified locally after the physical-device
checks above. No further physical or UI-automation run is claimed. Native Maia
behavior is unchanged; final staging removed two trailing blank lines, and the
complete package gate passed again. The source-identity report retains both
physical-tested source fingerprints and records the post-review fingerprints
separately.
