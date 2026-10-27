# ``MaiaEmbedded``

Native Maia-3 human-move probabilities and move selection on Apple platforms.

## Overview

Use this library when an application needs structured predictions or sampling
without UCI line parsing. Prepare one ``MaiaSession`` with a caller-owned local
model, submit ``MaiaRequest`` values, then inspect ``MaiaPrediction`` or select a
move through ``MaiaSampler``. Reuse the session across sequential requests to
avoid loading a separate model for each rating or position.

Ratings condition human play at Lichess levels; they are not calibrated engine
strengths. A prediction preserves original legal-move probabilities. Temperature,
TopP and move restrictions affect only the selection distribution. Human-game
outcome probabilities are not searched centipawn evaluations.

### Model and lifecycle

Provision the pinned FP32 export before preparing a session. The runtime checks
its file URL, byte count, checksum and ONNX schema; it does not download weights.
See the repository's [model provenance](https://github.com/Trickfest/MaiaEmbedded/blob/main/Docs/Provenance.md)
for the supported asset and retained licenses.

Actor isolation serializes each session's native work. Cancellation is checked
around native calls, not inside ONNX kernels. Await unload when the owning feature
closes, and keep request identities so a replaced position cannot receive an old
result. Separate prepared sessions each consume substantial model memory.

## Topics

### Getting started
- <doc:GettingStarted>
- ``MaiaConfiguration``
- ``MaiaSession``

### Requests and results
- ``MaiaRequest``
- ``MaiaPrediction``
- ``MaiaOutcome``
- ``MaiaError``

### Selecting moves
- ``MaiaSamplingOptions``
- ``MaiaSampler``
- ``MaiaSelection``
- ``MaiaSeededGenerator``
