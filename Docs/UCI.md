# UCI support

`MaiaEngine` wraps `MaiaSession`; the desktop executable wraps `MaiaEngine`.
Apple apps use the in-process adapter. No subprocess or redirected process-wide
streams are needed inside an app.

## Lifecycle

Create with configuration and an ordered `@Sendable` line callback. `start()`
validates configuration and opens the protocol without sending commands.
The caller sends `uci`, waits for `uciok`, sends `isready` and waits for
`readyok`. Preparation is lazy and `readyok` means the model actually loaded.
Preparation failure emits `info string MaiaEmbedded error: ...`, without a false
ready reply. A later isready can retry. Maintain a startup/error timeout.

Only one go request is outstanding. Commands and callbacks each preserve FIFO
order. Output handlers run off the main actor and must return promptly; marshal
UI updates to the main actor and retain request identities. A callback already
executing can finish while another thread stops the engine.

`stop` as a **UCI command** completes an active go with exactly one bestmove
once current native inference returns. An idle stop produces no bestmove.
The **Swift `stop()` method** closes the current generation, suppresses queued
output and schedules cooperative cleanup. `shutdown()` additionally awaits
native cleanup and callback drainage. Neither method sends a final bestmove.
`start()` can reopen the same object; new preparation waits behind old cleanup.
`quit` closes the protocol; the CLI also exits without requiring stdin EOF.

`waitForIdle()` waits for already submitted preparation/prediction work and
callbacks. It is a snapshot, not a fence against new concurrent commands. An
infinite prediction can finish its computation while retaining an active protocol
request; send UCI `stop` to release that best move. `waitForIdle()` does not unload
the model or throw readiness errors. Inspect diagnostic lines and enforce a
response deadline; see the complete [host example](Examples.md).

A valid position or ucinewgame invalidates old search results immediately.
The host should ordinarily stop/wait for bestmove before issuing a new position;
replacement intentionally suppresses the old request's bestmove. Invalid
commands emit a diagnostic and preserve the last valid position/options.

## Options

| Name | Default | Accepted values / meaning |
| --- | --- | --- |
| Elo | 1600 | 600...2600; sets both ratings |
| SelfElo | 1600 | 600...2600; side-to-move rating |
| OppoElo | 1600 | 600...2600; opponent rating |
| Temperature | 1 | finite 0...5; 0 gives argmax |
| TopP | 1 | finite (0,1]; upstream cumulative <= convention |
| MultiPV | 1 | 1...20 one-move candidates, ordered by base likelihood |
| UseHistory | false | replay/pad the supplied last eight positions |
| OutcomeScores | false | opt-in human-outcome compatibility scores |
| Seed | random | UInt64 seed, or random |

Configuration can change defaults. Send `setoption name NAME value VALUE` while
idle; invalid changes are atomic failures. Seed maintains a per-engine sequence;
changing Seed or ucinewgame resets it. Options otherwise survive ucinewgame,
which resets position to startpos. Swift stop/start restores initial configuration.

## Positions, go and output

`position startpos [moves ...]` and `position fen SIX_FIELDS [moves ...]` replay
legal coordinate moves. Full move history supports history mode and draw state;
a final FEN alone cannot reconstruct them. CRLF or LF terminators are accepted;
embedded newlines, NULs and lines above 1 MiB are rejected.

Finite `go` arguments movetime, depth, nodes, mate, wtime/btime, winc/binc and
movestogo all request **one primary policy prediction**, since Maia has no iterative search.
They do not set playing strength or impose a hard kernel deadline. Integer
limits must be positive; clock/increment values may be zero. `searchmoves`
restricts selection/PV candidates to its intersection with legal moves
and any caller-configured allowedMoves; an empty
intersection fails with a diagnostic and bestmove 0000.

`go infinite` performs one primary prediction and holds bestmove until stop; it does not
busy-loop. Ponder/ponderhit are rejected. Unsupported go arguments are rejected.
Terminal positions emit bestmove 0000. A failed started request emits a diagnostic
and one bestmove 0000; hosts should distinguish failure from terminal status.

Default info contains one-move PV candidates and `info string Maia policy MOVE
probability NUMBER`. These probabilities are original legal policy probabilities,
not sampling-adjusted probabilities. No fabricated depth or centipawn score is
emitted. The selected sampled move may differ from the top PV.

OutcomeScores opts into additional child-position predictions, swaps ratings
and inverts child outcomes to the root perspective. It emits integer permille
`wdl W D L` summing to 1000 and a compatibility `score cp W-L`, matching the pinned
upstream style. **This cp field is not a centipawn position evaluation.** It is
off by default, and SwiftChessDemo keeps it off and refuses Maia score recording.
No multi-move search PV, ponder move, opening book or tablebase is implemented.
