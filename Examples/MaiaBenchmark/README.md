# MaiaBenchmark reference app

A SwiftUI client for iPhone, iPad and Mac that demonstrates the direct API,
two-rating policies, UCI checks and inference measurements.

## Setup

From the package root, run `Scripts/download-model.sh`, then open
`Examples/MaiaBenchmark/MaiaBenchmark.xcodeproj`. Choose the MaiaBenchmark scheme
and a Mac, iPhone or iPad destination. The app bundles the downloaded model;
no inference-time network connection is required.

For physical iPhone/iPad builds, copy `Configurations/Signing.local.xcconfig.example`
to `Configurations/Signing.local.xcconfig` inside this example and set a development
team and bundle-ID prefix belonging to the developer account used for signing.
Keep that local file out of source control. macOS and simulator builds do not
require these personal signing values.

## Controls

- **Check Swift API & UCI:** validates the reference corpus, previews two rating
  policies from one loaded session, and checks legal UCI moves, stop and restart.
- **Run Checks & Benchmark:** measures correctness, load time and warm inference.
- **20-Minute Session:** measures a sustained workload with paced predictions.

Cancellation or backgrounding invalidates the current operation. Start a new run
after cleanup to avoid applying old results. Completed JSON reports can be shared
using the app's export controls.

## Launch options and reports

| Arguments | Report in the app's Documents directory |
| --- | --- |
| `--package-checks` | `maia-validation.json` |
| `--autorun --iterations 100 --duration 30` | `maia-benchmark.json` |

Use a completed report and successful checks when assessing a run. See
[Testing](../../Docs/Testing.md) for command-line installation/report collection
and [Benchmarks](../../Docs/Benchmarks.md) for physical-hardware measurements.
