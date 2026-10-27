# Predict and select a human move

Use one prepared session for position or rating comparisons, and explicitly
unload when the application feature finishes using it.

## One complete session

This asynchronous helper loads the pinned model, predicts from a root FEN and
recorded line, samples a move, and unloads on success or failure:

```swift
import Foundation
import MaiaEmbedded

func chooseHumanMove(modelURL: URL, rootFEN: String, moves: [String]) async throws -> MaiaSelection {
    let session = MaiaSession(configuration: .init(modelURL: modelURL))
    do {
        try await session.prepare()
        let request = MaiaRequest(
            initialFEN: rootFEN, moves: moves, useHistory: true,
            selfRating: 1400, opponentRating: 1800)
        let result = try await session.selectMove(request, options: .init(seed: 42))
        await session.unload()
        return result
    } catch {
        await session.unload()
        throw error
    }
}
```

For a sequence of moves, retain the prepared session instead of calling this
single-session helper for every position. Keep the model file readable until
unload and observe the task's errors/cancellation in the application.

## Interpret a result

``MaiaSelection/move`` is a coordinate-UCI string, or nil for an automatic terminal
outcome. ``MaiaSelection/prediction`` retains original legal probabilities;
``MaiaSelection/selectionProbabilities`` reports the temperature/TopP-adjusted
distribution. The selected move can differ from ``MaiaPrediction/topMove``.

Request ratings always refer to the final side to move and its opponent. History
mode uses the last eight replayed boards; a standalone final FEN cannot recover
moves that were not supplied. Validation checks legal replay and position
consistency, not whether every possible root FEN is historically reachable.

A fixed sampling seed starts a fresh stream on each direct selection call. For a
reproducible series, retain ``MaiaSeededGenerator`` and pass it to
``MaiaSampler/select(from:options:using:)`` after calling ``MaiaSession/predict(_:)``.
Reproducibility requires identical logits and settings.

## Integrate with a screen

Cancel work when the displayed request changes, retain a request identity and
reject outdated results. Cancellation suppresses delivery at cooperative
checkpoints; cleanup can still wait for native inference to finish. Use
``MaiaSession/unload()`` to release the native session after the feature closes.
