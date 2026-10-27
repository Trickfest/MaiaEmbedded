# ``MaiaUCI``

An instance-owned in-process UCI adapter over the direct Maia Swift API.

## Overview

Create ``MaiaEngine`` with a model configuration and ordered callback. Start it,
send uci/isready and await their responses before position/go. Readiness means
model preparation succeeded. One finite go produces one inference; infinite go
holds its result until stop. No subprocess or process-wide stream redirect is
used. The macOS maia-uci executable adapts the same engine to stdin/stdout.

UCI stop completes a request; Swift stop closes the protocol generation and
schedules cleanup. Await shutdown for resource/callback drainage. The object can
then start again. A callback already executing may finish during stop.

Policy percentages predict human choices. Default output has no centipawn score;
optional outcome compatibility scores must not be presented as searched evaluation.
See Docs/UCI.md in the repository for options and supported limits.

## Topics

### Engine lifecycle and commands
- ``MaiaEngine``
