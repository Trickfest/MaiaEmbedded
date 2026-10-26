# Native Maia benchmark

One SwiftUI app for iPhone, iPad, and Mac, sharing the same Swift prediction and
benchmark code as the native Mac CLI. No XCTest UI target or UI automation is
required. Download the pinned model with `Scripts/download-model.sh` from the
repository root, then open `MaiaBenchmark.xcodeproj`.

The project copies the local model into the bundle. Run **Checks & Benchmark**
for upstream reference checks and warm timing, or **20-Minute Session** for the
paced sustained run. **Cancel** suppresses results after native inference
returns; backgrounding also cancels. Export completed JSON reports with the
share control. These operations remain fully offline.

For unattended simulator runs, launch with `--autorun --iterations 100 --duration
30`. The JSON goes to the app's Documents/maia-benchmark.json. A completed report
must have the expected start/completion timestamps; an old file is not evidence
that a later run succeeded.

Physical-device signing uses an ignored `Configurations/Signing.local.xcconfig`;
copy the adjacent example and set your own DEVELOPMENT_TEAM and unique bundle
prefix. The shared scheme runs Release builds. No team ID or UDID is tracked.

Mobile physical acceptance is pending. Simulator reports identify themselves and
cannot substitute for iPhone/iPad runtime, memory, thermal, or lifecycle testing.
See [Validation](../../Docs/Validation.md).
