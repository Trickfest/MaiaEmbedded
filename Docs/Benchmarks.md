# Benchmarks

Maia-3 79M FP32 inference measurements on physical Apple hardware. These results
help estimate response time and memory requirements for applications embedding
the package. Measurements were collected in October 2026; raw report timestamps
use UTC.

## Hardware and inference settings

| Platform | Hardware | Operating system |
| --- | --- | --- |
| Mac | Apple M5 Max, 18 CPU cores, 48 GiB RAM | macOS 27.0.1 |
| iPhone | iPhone 16 Pro Max | iOS 27.0.1 |
| iPad | iPad Pro 13-inch (M4) | iPadOS 27.0.1 |

All runs used the same 316 MB model, ONNX Runtime 1.24.2 CPU execution, FP32,
two intra-op threads and basic graph optimization. The model SHA-256 and source
identities are recorded in [Provenance](Provenance.md). Each run checked the
[20-position reference corpus](../Sources/MaiaBenchmarkSupport/Resources/reference.json)
before timing inference. Raw logit and probability errors stayed below the
1e-4 and 1e-5 tolerances, respectively.

## Direct API measurements

These 30-second runs exercised the `MaiaSession` inference core used by both
the direct API and `MaiaUCI`. Warm median/p95 values come from 100 predictions.
Cold time includes model verification/loading and the first prediction.

| Hardware | Cold load + first prediction | Warm median | Warm p95 | Kernel peak footprint | Raw report |
| --- | --- | --- | --- | --- | --- |
| Apple M5 Max Mac | 0.378 s | 16.8 ms | 17.2 ms | 759.5 MiB | [JSON](Benchmarks/2026-10-26/mac-30s.json) |
| iPhone 16 Pro Max | 0.448 s | 16.1 ms | 16.5 ms | 754.8 MiB | [JSON](Benchmarks/2026-10-26/iphone-30s.json) |
| iPad Pro 13-inch (M4) | 0.409 s | 14.3 ms | 14.5 ms | 756.0 MiB | [JSON](Benchmarks/2026-10-26/ipad-30s.json) |

## Sustained measurements

The longer runs used an earlier harness with the same model and inference settings.
Each run kept a session loaded for 20 minutes, with a 100 ms pause between
predictions. The completed-prediction counts therefore describe a paced workload,
not maximum inference throughput. All runs remained in nominal thermal state.

| Hardware | Cold load + first prediction | Warm p95 | Peak footprint | Predictions in 20 minutes | Raw report |
| --- | --- | --- | --- | --- | --- |
| Apple M5 Max Mac | 0.407 s | 17.6 ms | 777.6 MiB, sampled | 9,330 | [JSON](Benchmarks/2026-10-25/mac-20min.json) |
| iPhone 16 Pro Max | 0.457 s | 16.8 ms | 754.4 MiB, kernel | 7,751 | [JSON](Benchmarks/2026-10-26/iphone-20min.json) |
| iPad Pro 13-inch (M4) | 0.391 s | 14.7 ms | 755.5 MiB, kernel | 8,391 | [JSON](Benchmarks/2026-10-26/ipad-20min.json) |

Sustained first/last-window p95 values were 30.1/30.6 ms on the Mac,
52.1/51.3 ms on the iPhone and 40.5/43.8 ms on the iPad. Other build and runtime
work overlapped portions of the Mac run, so the table is not an isolated
cross-device speed ranking.

The Mac's 20-minute report predates kernel peak reporting and records only
between-operation samples. A separate [30-second kernel-memory measurement](Benchmarks/2026-10-25/mac-memory-highwater.json)
recorded a 758.4 MiB kernel peak. Kernel peaks include transient allocations
across the process lifetime; between-operation samples can miss them. These
measurement types should not be treated as interchangeable.

Periodic footprint samples are available for the [Mac](Benchmarks/2026-10-25/mac-sustained-samples.json),
[iPhone](Benchmarks/2026-10-26/iphone-sustained-samples.json) and
[iPad](Benchmarks/2026-10-26/ipad-sustained-samples.json).

## Interpreting the results

Cold measurements used a fresh session/process without evicting filesystem
caches. Footprint is for the benchmark process, not just model weights; an
application needs additional memory for its UI and other engines. Separate
sessions each load a model. Unloading releases the session, but native allocators
may retain pages, so process footprint need not immediately return to startup.

The recorded workloads showed no continuing memory growth. They do not establish
battery consumption or performance on every supported device. Numeric budget
flags in raw reports describe the harness's screening thresholds, not operating
system memory limits. See [Testing](Testing.md) to reproduce the measurements
on a target device and workload.
