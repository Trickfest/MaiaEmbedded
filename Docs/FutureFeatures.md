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

The 1.0 release establishes the CPU baseline and public source-package setup.
Future releases should retain the same API/asset qualification gates and source,
model and runtime notices. App Store distribution is separate product work.
