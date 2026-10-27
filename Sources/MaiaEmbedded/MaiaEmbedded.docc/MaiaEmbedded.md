# ``MaiaEmbedded``

Native Maia-3 human-move predictions and selection on Apple platforms.

## Overview

Prepare a ``MaiaSession`` with a caller-owned pinned local model. Submit a
``MaiaRequest`` with a validated root FEN, legal move history and side-to-move/
opponent ratings. Reuse the session for sequential rating comparisons. Inspect
``MaiaPrediction`` for original human-move likelihoods, and use ``MaiaSampler``
for selection with separate adjusted probabilities.

Cancellation is cooperative around native work. Await unload and keep request
identities in UI owners to reject old results. Outcome probabilities describe
human games; they are not searched chess-engine evaluations. Runtime model
acquisition, board UI, clocks and storage belong to consumers.

## Topics

### Configuration and inference
- ``MaiaConfiguration``
- ``MaiaSession``
- ``MaiaRequest``
- ``MaiaPrediction``
- ``MaiaOutcome``
- ``MaiaError``

### Move selection
- ``MaiaSamplingOptions``
- ``MaiaSampler``
- ``MaiaSelection``
- ``MaiaSeededGenerator``
