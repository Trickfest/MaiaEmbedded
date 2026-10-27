# Native Maia reference harness

One SwiftUI app for iPhone, iPad and Mac. Download the pinned model with
`Scripts/download-model.sh`, then open `MaiaBenchmark.xcodeproj`.

**Check Swift API & UCI** verifies the reference corpus, shows move probabilities
at two ratings from one loaded session, and verifies UCI moves/stop/restart.
**Run Checks & Benchmark** measures correctness/latency; **20-Minute Session**
uses the original paced sustained workload. Cancel/background suppresses the
current result and permits a fresh run after cleanup. All inference is offline.

Launch with `--package-checks` to write Documents/maia-validation.json, or
`--autorun --iterations 100 --duration 30` for Documents/maia-benchmark.json.
Export completed reports with their share controls. A current completion timestamp
and successful checks are required; installation or a stale report is not evidence.
No XCTest UI target or UI automation is involved.

Physical signing uses the ignored Configurations/Signing.local.xcconfig, copied
from its example. Shared configuration includes no personal team ID or UDID.
Original physical feasibility passed; final package/device verification is a
separate gate. See [Testing](../../Docs/Testing.md) and [Examples](../../Docs/Examples.md).
