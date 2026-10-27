# ``MaiaUCI``

An instance-owned in-process UCI adapter over native Maia inference.

## Overview

Use ``MaiaEngine`` when the host already speaks UCI. The adapter shares the direct
Swift inference core, owns its command and output queues, and does not redirect
process-wide streams. The macOS `maia-uci` executable is a stdin/stdout host for
this same adapter.

### Handshake and requests

1. Create an engine with configuration and an ordered output callback.
2. Call ``MaiaEngine/start()``, then ``MaiaEngine/sendCommand(_:)`` with `uci`.
3. After `uciok`, send `isready`. Only `readyok` confirms model preparation.
4. Send a legal `position` line, then `go`; consume the resulting `bestmove`.
5. Await ``MaiaEngine/shutdown()`` before releasing or replacing the engine.

Callbacks run off the main actor and must return promptly. Dispatch UI work to
the main actor, retain request identities, and handle diagnostic output and
response deadlines. A complete asynchronous host example with timeout and cleanup
is in the repository's [Examples guide](https://github.com/Trickfest/MaiaEmbedded/blob/main/Docs/Examples.md).

### Stop and cleanup

The UCI `stop` command completes an active request with one best move after native
work returns. Swift ``MaiaEngine/stop()`` closes the current protocol generation,
suppresses queued output and schedules cleanup. A callback already executing may
finish. ``MaiaEngine/shutdown()`` also waits for cleanup and callback drainage.
The object can be started again afterward.

``MaiaEngine/waitForIdle()`` waits for submitted native work and callbacks. It is
not a resource-release barrier, and an infinite request can still hold a computed
best move afterward. Send UCI `stop` to finish that protocol request.

### Prediction semantics

A finite `go` produces one primary policy prediction. Time/depth limits do not
add iterative search or provide a hard inference deadline. Infinite mode holds
the result until `stop` rather than repeatedly running inference.

Policy percentages describe original human-move likelihoods. Optional outcome
scores perform additional child predictions and emit WDL-derived compatibility
values, not searched centipawn evaluations. They are off by default. See the
[UCI guide](https://github.com/Trickfest/MaiaEmbedded/blob/main/Docs/UCI.md) for the
full options, history, error and command contracts.

## Topics

### Configuration and callbacks
- ``MaiaEngine``
- ``MaiaEngine/Configuration``
- ``MaiaEngine/LineHandler``

### Lifecycle and commands
- ``MaiaEngine/isRunning``
- ``MaiaEngine/start()``
- ``MaiaEngine/sendCommand(_:)``
- ``MaiaEngine/stop()``
- ``MaiaEngine/shutdown()``
- ``MaiaEngine/waitForIdle()``
