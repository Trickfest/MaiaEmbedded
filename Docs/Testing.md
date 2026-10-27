# Testing and benchmarking

## Package tests

From a source checkout, run the asset-independent tests with:

```sh
swift test
```

No model or Python installation is required. The real-model lifecycle test skips
when `MAIA_MODEL_PATH` is unset. To include it:

```sh
Scripts/download-model.sh
MAIA_MODEL_PATH="$PWD/Resources/Models/maia3-79m.onnx" swift test
```

The tests cover encoding and legal moves, typed errors, terminal positions,
sampling, session lifecycle and cancellation. UCI tests use a controlled backend
to check readiness, options, command ordering, stop/restart and stale-result
rejection without depending on native inference timing.

For a complete source validation run:

```sh
Scripts/download-model.sh
Scripts/validate.sh
```

The script runs Debug/Release tests, Thread Sanitizer, real-model reference
checks, UCI CLI checks, smoke/soak, a short benchmark, DocC, and Apple-platform
package and reference-app builds. It requires Xcode and the downloaded model.
Thread Sanitizer instruments Swift code; the prebuilt ONNX Runtime binary is not
rebuilt with instrumentation. Local validation does not require GitHub Actions.

## Command-line checks and benchmarks

```sh
swift run maia-smoke --iterations 20 --output .build/results/package.json
swift run maia-soak --iterations 200
Scripts/run-mac-benchmark.sh 30
```

The smoke and soak tools verify the reference corpus and two-rating predictions,
then exercise legal/terminal UCI requests, infinite stop and adapter restart.
They exit nonzero on failure. The benchmark measures model load, warm latency,
paced inference, memory, thermal state and unload/reload behavior. Pass `1200`
instead of `30` to run a 20-minute workload.

Reports are written under ignored `.build/results` paths. Use a successful
process exit and the completed report's timestamp when assessing a run.
[Benchmarks](Benchmarks.md) describes the published physical-hardware results
and the distinction between sampled and kernel peak footprint.

## Native reference app

After provisioning the model, open
`Examples/MaiaBenchmark/MaiaBenchmark.xcodeproj`. The app runs on iPhone, iPad
and Mac and exposes API/UCI checks, a short benchmark and a 20-minute session.
See the [reference app guide](../Examples/MaiaBenchmark/README.md) for signing
and launch options.

For command-line physical-device runs, configure local signing as described in
the example guide, connect and unlock the device, then use:

```sh
Scripts/run-device-benchmark.sh DEVICE_IDENTIFIER 1200
Scripts/collect-device-report.sh DEVICE_IDENTIFIER SIGNED_BUNDLE_IDENTIFIER .build/results/device-benchmark.json

Scripts/run-device-benchmark.sh DEVICE_IDENTIFIER 0 --package-checks
Scripts/collect-device-report.sh DEVICE_IDENTIFIER SIGNED_BUNDLE_IDENTIFIER .build/results/device-api-uci.json maia-validation.json
```

The run helper installs and launches the app. Collect the report after the run
completes, keeping the app in the foreground during a benchmark. Device
identifiers and signing settings belong in local configuration, not source
control. Simulators are useful for functional checks; measure mobile performance
on physical hardware.

Applications integrating the package should also check background/return,
cancellation during inference, restart, stale-result handling and responsive UI.
Cancellation is cooperative around native ONNX work; it does not interrupt a
kernel already executing. See [Architecture](Architecture.md) for the lifecycle
contract.

## Reference accuracy and reproduction

The tracked corpus contains 20 position/rating/history cases covering both
colors, current-only and eight-position history, castling, en passant,
promotions, check and terminal positions. Encoded FP32 tensors must match the
upstream hashes exactly. Raw legal-move/value logits must agree within 1e-4,
probabilities within 1e-5, and probability sums within 1e-6.

`Scripts/prepare-reference.sh` downloads the pinned checkpoint, provisions the
isolated Python tools and regenerates the fixtures. These tools run on the
development Mac, not inside an application. [Provenance](Provenance.md) records
the model, source and tool versions. Recheck accuracy and device measurements
when changing the model export, precision, runtime or execution provider.
