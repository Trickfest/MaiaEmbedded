# ``MaiaBenchmarkSupport``

Reference-corpus validation and inference measurements for native clients.

## Overview

This optional support product powers the command-line tools and the
MaiaBenchmark reference app. Ordinary chess applications can depend directly on
MaiaEmbedded and/or MaiaUCI. Use this product to check the pinned reference
corpus, compare rating policies, validate UCI behavior or collect numeric reports.

```swift
import Foundation
import MaiaBenchmarkSupport

func measure(modelURL: URL, reportURL: URL) async throws {
    let report = try await MaiaBenchmark.run(
        modelURL: modelURL, iterations: 100, sustainedSeconds: 30)
    try report.write(to: reportURL)
}
```

The caller provisions the model and supplies an output URL in app-owned storage.
No asset is downloaded. The benchmark's asynchronous progress callback is not a
main-actor UI callback; dispatch UI updates appropriately.

### Measurement units

Durations are seconds, footprint values are bytes, and memory budgets are MiB.
The report separates `coldLoadSeconds` from `firstPredictionSeconds`; add them
to obtain combined cold startup. Warm median/p95 values exclude paced-run pauses. The sustained workload pauses
100 ms between predictions, so its count is not maximum throughput.

Sampled footprint is observed between operations. Kernel peaks span process
lifetime and include transient allocations. Unload does not guarantee that native
allocators immediately return all pages. Budget and growth flags are screening
thresholds, not OS limits or proof of absence of leaks. Physical-hardware results
and methodology are in the [Benchmarks guide](https://github.com/Trickfest/MaiaEmbedded/blob/main/Docs/Benchmarks.md).

## Topics

### Reference data
- ``ReferenceCase``
- ``ReferenceCorpus``

### Measurements
- ``MaiaBenchmark``
- ``BenchmarkReport``

### API and UCI checks
- ``MaiaPackageChecks``
- ``MaiaPackageReport``
- ``MaiaRatingPreview``
- ``MaiaUCIChecks``
- ``MaiaLineCapture``
