# Native inference experiment

## Outcome

The pinned Maia-3 79M FP32 model runs correctly through the native Swift/ONNX
integration on this Mac, a physical iPad Pro 13-inch (M4), a physical iPhone 16
Pro Max, and iPhone/iPad simulators. All three physical platforms meet the
proposed core inference latency and memory targets. The user also reports that
background/resume, cancellation during work, and restart without stale updates
passed on both physical mobile devices. The feasibility experiment is complete;
this is not production-package acceptance or release qualification. No UI automation or
XCTest UI suite was used. Mac/simulator evidence is dated 2026-10-25; physical
mobile evidence is dated 2026-10-26.

## Measured results

All runs compared 20 upstream PyTorch reference cases and passed their token,
legality, terminal, raw-logit and probability checks. Warm measurements use 100
predictions. Kernel peak footprint includes transient allocations; sampled peak
is measured between operations. Times below are rounded; raw JSON is linked.

| Runtime | Cold load + first prediction | Warm p95 | Peak footprint | Sustained work |
| --- | --- | --- | --- | --- |
| Physical iPhone 16 Pro Max, iOS 27.0.1 | 0.457 s | 16.8 ms | 754 MiB kernel peak | 1,200 s, 7,751 predictions |
| Physical iPad Pro 13-inch (M4), iPadOS 27.0.1 | 0.391 s | 14.7 ms | 756 MiB kernel peak | 1,200 s, 8,391 predictions |
| This Mac, native macOS 27.0.1 | 0.407 s | 17.6 ms | 778 MiB sampled | 1,200 s, 9,330 predictions |
| This Mac, short kernel-memory follow-up | 0.347 s | 16.8 ms | 758 MiB kernel peak | 30 s |
| iPhone 18 Pro simulator, iOS 27 | See JSON | 17.6 ms | 647 MiB kernel peak | 30 s |
| iPad Pro simulator, iPadOS 27 | See JSON | 17.9 ms | 653 MiB kernel peak | 30 s |
| iPhone Air simulator, iOS 26.5 | See JSON | 22.9 ms | 648 MiB kernel peak | 30 s |

Simulator times measure the host Mac running simulator binaries and do not
predict physical mobile latency, memory accounting, thermals, or battery life.
Cold timings mean a fresh process/session; filesystem caches were not evicted.
The Mac has 48 GiB RAM. Simulator starts/builds overlapped parts of the sustained
Mac run, so this is a practical feasibility workload, not an isolated lab speed
comparison.

The 20-minute Mac run stayed in nominal thermal state. Its first/last 100
sustained-prediction windows had p95 values of 30.1/30.6 ms. Sampled footprint
fell from about 757 MiB before the sustained workload to 452 MiB at its end;
39 periodic samples ranged from 449 to 685 MiB. No continuing growth was seen in
this run. That is evidence for this workload, not proof that all workloads are
leak-free. Two reload cycles and pre-canceled request rejection also completed.

The full-length run began before kernel high-water fields were added to the
reporter; its JSON therefore records sampled peaks only. The separate short
Mac follow-up and final simulator reports include kernel high-water measurements.
The inference core and paced workload were unchanged between those report
formats. Native allocators can retain pages after unload; immediate footprint
return to startup is not promised.

## Correctness and reproducibility

- Seven non-UI Swift Testing tests pass: reference encoding/legality/terminal
  status, illegal input, malformed FEN/broken model, promotion vocabulary,
  stable softmax, unloaded inference, and pre-cancellation behavior.
- Input FP32 tensor bytes match upstream hashes exactly for all 20 cases.
- The native Mac's maximum reference logit/probability errors were about
  2.10e-5 / 4.68e-6, within the predeclared 1e-4 / 1e-5 tolerances.
- The original PyTorch checkpoint and ONNX export were independently compared
  across the fixture corpus; maximum error across all heads was 6.78e-5.
- The pinned reference-generation script reproduced the fixture byte-for-byte.
- Release app builds pass for native macOS arm64, iOS/iPadOS simulator, and
  signed physical iPhone/iPad arm64. Installation/launch alone was not used as
  a correctness result: completed JSON reports were retrieved from each runtime.
- Model SHA-256 is checked during provisioning and again at runtime. Weights,
  original checkpoint, tool environments and build products remain ignored.

## Physical iPad — 2026-10-26

The Release build was signed with ignored local development settings, installed
on the unlocked physical iPad, and run with console monitoring. The completed
JSON was retrieved from the app data container and checked for the expected
hardware, current run timestamps, model identity and `isSimulator=false`.

All 20 reference cases passed. Maximum raw-logit/probability errors were
2.29e-5 / 4.95e-6. Warm median/p95 were 14.4/14.7 ms, and sequential predictions
at two ratings took 28.8 ms. Model verification/load plus first prediction took
0.391 s. The 20-minute session produced 8,391 predictions; first/last sustained
p95 windows were 40.5/43.8 ms. All latency targets were met.

Kernel lifetime peak footprint was about 756 MiB, within the proposed 1024 MiB
experiment budget. Between-operation peak was 452 MiB. Sustained initial/final
footprints were 442.1/442.5 MiB, with periodic console samples settling near
440 MiB; no continuing growth was observed. Two unload/reload cycles passed,
and kernel thermal state remained nominal throughout. These measurements apply
to this iPad and workload, not every supported iPad model.

The user reported that the screen scrolled normally with no unusual warmth
about three minutes into the session. That is direct manual responsiveness/
comfort feedback, distinct from the full-run system thermal measurements.
Battery consumption was not measured. Pre-canceled request rejection passed.
The later manual lifecycle checks passed per the user report below.

## Physical iPhone — 2026-10-26

The Release build was signed, installed on the unlocked physical iPhone 16 Pro
Max, and run with console monitoring. The completed JSON was retrieved from
the app data container and checked for current run timestamps, hardware/model
identity, duration and `isSimulator=false`.

All 20 reference cases passed. Maximum raw-logit/probability errors were
2.29e-5 / 4.95e-6. Warm median/p95 were 16.3/16.8 ms, and two sequential rating
predictions took 32.8 ms. Model verification/load plus first prediction took
0.457 s. The 20-minute session produced 7,751 predictions; first/last sustained
p95 windows were 52.1/51.3 ms. All proposed latency targets were met.

Kernel lifetime peak footprint was about 754 MiB, within the proposed 1024 MiB
experiment budget. Between-operation peak was about 451 MiB. Sustained
initial/final footprints were 442.8/439.7 MiB, with periodic console samples
remaining near 439 MiB; no continuing growth was observed. Two unload/reload
cycles and pre-canceled request rejection passed. Kernel thermal state remained
nominal throughout. These measurements apply to this iPhone and workload, not
every iPhone model.

The user reported normal scrolling and no unusual warmth early in the run.
That manual observation is recorded separately from the system thermal data.
Battery consumption was not measured. The later manual lifecycle checks passed
per the user report below.

## Manual lifecycle checks — 2026-10-26

The user reports completing all three prescribed tests on both physical iPhone
and iPad, with everything working as expected:

- Background an active run, return, and start a fresh run.
- Cancel during work without a completed result for the canceled run.
- Restart afterward with new progress/results and no late updates from the old run.

This is direct user-reported manual evidence, not an automated UI test or an
independent log reconstruction of those actions. It closes the remaining
lifecycle portion of the feasibility experiment on these devices.

## Next work

The model feasibility experiment has passed on the tested Mac, iPad and iPhone,
including the user-reported mobile lifecycle checks. Proceed to package/model
integration and the production direct Swift API design. Sampling, UCI and
SwiftChessDemo integration remain later work. The experimental API is not yet
production ready.

The harness and benchmark evidence were committed locally as `c4d2e3d`.
The subsequent manual lifecycle record is direct user-reported evidence.
Commit/push synchronization is tracked in Git; no tag/release or public visibility
change is part of this experiment.

## Evidence

- [User-reported manual lifecycle results](Benchmarks/2026-10-26/manual-lifecycle.json)

- [Physical iPhone report](Benchmarks/2026-10-26/iphone-physical.json)
- [Physical iPhone environment, source hashes and user observation](Benchmarks/2026-10-26/iphone-environment.json)
- [Physical iPhone sustained footprint samples](Benchmarks/2026-10-26/iphone-sustained-samples.json)

- [Physical iPad report](Benchmarks/2026-10-26/ipad-physical.json)
- [Physical iPad environment, source hashes and user observation](Benchmarks/2026-10-26/environment.json)
- [Physical iPad sustained footprint samples](Benchmarks/2026-10-26/ipad-sustained-samples.json)

- [Environment and scope](Benchmarks/2026-10-25/environment.json)
- [Native Mac 20-minute report](Benchmarks/2026-10-25/mac-20min.json)
- [Native Mac sustained footprint samples](Benchmarks/2026-10-25/mac-sustained-samples.json)
- [Native Mac kernel peak follow-up](Benchmarks/2026-10-25/mac-memory-highwater.json)
- [iPhone simulator report](Benchmarks/2026-10-25/iphone-simulator.json)
- [iPad simulator report](Benchmarks/2026-10-25/ipad-simulator.json)
- [iOS 26.5 simulator report](Benchmarks/2026-10-25/iphone-ios26-simulator.json)

Reports contain model/system/benchmark metadata and no signing team, personal
device UDID, credentials or absolute home-directory paths. Source is an
uncommitted local experiment, not a frozen release qualification.
