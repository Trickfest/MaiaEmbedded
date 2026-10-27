# Future features

The native 79M Swift inference/selection API, UCI adapter and reference clients
are implemented. The local gates and final verification passed on the tested
Mac, iPhone and iPad; see [Testing](Testing.md) for the evidence and scope.

Potential follow-ups are additional model sizes, Core ML/Neural Engine providers,
quantization, batching and measured memory tuning. Each needs independent
correctness and device evidence. They are not requirements for this CPU baseline.

A full Mobile Maia-style Apple application is separate product work: clocks,
game storage/PGN, review/variations, Maia/Stockfish comparisons, training workflows,
accessibility/localization and optional physical-board transport.

Public distribution remains deferred: choose an initial version, settle the
consumer dependency setup, review source/model/runtime notices and corresponding
source obligations for the intended app/package distribution, then obtain explicit
authorization for visibility, tags/releases or App Store submission. This private
repository has no release and is not listed on Swift Package Index.
