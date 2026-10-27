// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import Testing
@testable import MaiaEmbedded
@testable import MaiaUCI

private final class Capture: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []
    func append(_ line: String) { lock.lock(); defer { lock.unlock() }; lines.append(line) }
    func take() -> [String] { lock.lock(); defer { lock.unlock() }; defer { lines.removeAll() }; return lines }
}
private actor FakeModel {
    var requests: [MaiaRequest] = []
    var loads = 0
    var unloads = 0
    var shouldFail = false
    var blockNext = false
    var blocked: CheckedContinuation<Void, Never>?
    var entered: CheckedContinuation<Void, Never>?
    func prepare() throws { loads += 1; if shouldFail { throw MaiaError.modelNotFound } }
    func setFailure(_ value: Bool) { shouldFail = value }
    func block() { blockNext = true }
    func waitUntilBlocked() async {
        if blocked != nil { return }
        await withCheckedContinuation { entered = $0 }
    }
    func release() { blocked?.resume(); blocked = nil }
    func predict(_ request: MaiaRequest) async throws -> MaiaPrediction {
        requests.append(request)
        if blockNext {
            blockNext = false
            await withCheckedContinuation { blocked = $0; entered?.resume(); entered = nil }
        }
        let input = try MaiaEncoding.prepare(request)
        let count = Double(input.legalMoves.count)
        return MaiaPrediction(terminal: input.terminal,
            logits: Dictionary(uniqueKeysWithValues: input.legalMoves.map { ($0, Float(0)) }),
            probabilities: Dictionary(uniqueKeysWithValues: input.legalMoves.map { ($0, 1 / count) }),
            valueLogits: [], outcomeProbabilities: input.terminal ? input.terminalOutcome : [0.2, 0.3, 0.5])
    }
    func unload() { unloads += 1 }
    var backend: MaiaBackend {
        MaiaBackend(prepare: { try await self.prepare() }, predict: { try await self.predict($0) }, unload: { await self.unload() })
    }
}
private func setup(_ fake: FakeModel = FakeModel()) async throws -> (MaiaEngine, Capture, FakeModel) {
    let capture = Capture()
    let engine = MaiaEngine(configuration: .init(model: .init(modelURL: URL(fileURLWithPath: "/unused"))), backend: await fake.backend) { capture.append($0) }
    try engine.start()
    return (engine, capture, fake)
}
@Test func handshakeReadinessAndRatingOptions() async throws {
    let (engine, output, model) = try await setup()
    engine.sendCommand("uci\r\n"); engine.sendCommand("isready"); engine.sendCommand("isready")
    await engine.waitForIdle()
    let lines = output.take()
    #expect(lines.contains("uciok"))
    #expect(lines.filter { $0 == "readyok" }.count == 2)
    #expect(lines.contains("option name SelfElo type spin default 1600 min 600 max 2600"))
    #expect(await model.loads == 1)
    engine.sendCommand("setoption name SelfElo value 1200")
    engine.sendCommand("setoption name OppoElo value 2000")
    engine.sendCommand("setoption name UseHistory value true")
    engine.sendCommand("position startpos moves e2e4")
    engine.sendCommand("go movetime 1")
    await engine.waitForIdle()
    let request = try #require(await model.requests.last)
    #expect(request.selfRating == 1200 && request.opponentRating == 2000 && request.useHistory)
    #expect(request.moves == ["e2e4"])
    let search = output.take()
    #expect(search.filter { $0.hasPrefix("bestmove ") }.count == 1)
    #expect(!search.contains { $0.contains("score cp") || $0.contains(" wdl ") })
    await engine.shutdown()
}
@Test func searchmovesAndInfiniteStop() async throws {
    let (engine, output, _) = try await setup()
    engine.sendCommand("setoption name MultiPV value 3")
    engine.sendCommand("go infinite searchmoves e2e4")
    await engine.waitForIdle()
    let held = output.take()
    #expect(!held.contains { $0.hasPrefix("bestmove ") })
    #expect(held.filter { $0.hasPrefix("info multipv") } == ["info multipv 1 pv e2e4"])
    engine.sendCommand("stop"); engine.sendCommand("stop")
    await engine.waitForIdle()
    #expect(output.take() == ["bestmove e2e4"])
    await engine.shutdown()
}
@Test func replacementAndShutdownSuppressStaleResults() async throws {
    let (engine, output, model) = try await setup()
    await model.block()
    engine.sendCommand("go depth 1")
    await model.waitUntilBlocked()
    engine.sendCommand("position startpos moves e2e4")
    // Flush the command queue before releasing the old native inference.
    #expect(engine.isRunning)
    await model.release()
    await engine.waitForIdle()
    #expect(!output.take().contains { $0.hasPrefix("bestmove ") })
    engine.sendCommand("go searchmoves e7e5")
    await engine.waitForIdle()
    #expect(output.take().contains("bestmove e7e5"))
    await model.block()
    engine.sendCommand("go depth 1")
    await model.waitUntilBlocked()
    engine.stop()
    try engine.start()
    engine.sendCommand("isready")
    await model.release()
    await engine.waitForIdle()
    let restarted = output.take()
    #expect(restarted == ["readyok"])
    #expect(await model.unloads == 1)
    #expect(await model.loads == 2)
    await engine.shutdown()
    #expect(!engine.isRunning)
}
@Test func stopDuringInferenceReturnsExactlyOneMove() async throws {
    let (engine, output, model) = try await setup()
    await model.block(); engine.sendCommand("go infinite")
    await model.waitUntilBlocked()
    engine.sendCommand("stop"); engine.sendCommand("stop")
    #expect(engine.isRunning)
    await model.release(); await engine.waitForIdle()
    #expect(output.take().filter { $0.hasPrefix("bestmove ") }.count == 1)
    await engine.shutdown()
}
@Test func malformedCommandsDoNotCorruptPositionOrConfiguration() async throws {
    let (engine, output, model) = try await setup()
    for line in ["setoption name SelfElo value 599", "setoption name Temperature value nan", "position startpos moves e2e5", "go ponder", "go depth -1", "go searchmoves", "uci\nisready"] {
        engine.sendCommand(line)
    }
    await engine.waitForIdle()
    #expect(output.take().filter { $0.hasPrefix("info string MaiaEmbedded error:") }.count == 7)
    engine.sendCommand("go searchmoves e2e4")
    await engine.waitForIdle()
    #expect(output.take().contains("bestmove e2e4"))
    #expect(await model.requests.last?.selfRating == 1600)
    await engine.shutdown()
}
@Test func readinessFailureCanRetryAndTerminalReturnsNullMove() async throws {
    let fake = FakeModel(); await fake.setFailure(true)
    let (engine, output, _) = try await setup(fake)
    engine.sendCommand("isready"); await engine.waitForIdle()
    let failed = output.take()
    #expect(!failed.contains("readyok"))
    #expect(failed.contains { $0.hasPrefix("info string MaiaEmbedded error:") })
    await fake.setFailure(false)
    engine.sendCommand("isready"); await engine.waitForIdle()
    #expect(output.take() == ["readyok"])
    engine.sendCommand("position fen 7k/6Q1/5K2/8/8/8/8/8 b - - 0 1")
    engine.sendCommand("go depth 1"); await engine.waitForIdle()
    #expect(output.take() == ["bestmove 0000"])
    await engine.shutdown()
}
@Test func optionalOutcomeCompatibilityScoresInvertChildPerspective() async throws {
    let (engine, output, model) = try await setup()
    engine.sendCommand("setoption name OutcomeScores value true")
    engine.sendCommand("setoption name SelfElo value 1000")
    engine.sendCommand("setoption name OppoElo value 2000")
    engine.sendCommand("go searchmoves e2e4")
    await engine.waitForIdle()
    #expect(output.take().contains("info multipv 1 score cp -300 wdl 200 300 500 pv e2e4"))
    let child = try #require(await model.requests.last)
    #expect(child.moves == ["e2e4"] && child.selfRating == 2000 && child.opponentRating == 1000)
    await engine.shutdown()
}

@Test func seededSequencesAndNewGameResetAreInstanceOwned() async throws {
    let (first, firstOutput, _) = try await setup()
    let (second, secondOutput, _) = try await setup()
    for engine in [first, second] { engine.sendCommand("setoption name Seed value 42") }
    var sequence: [String] = []
    for _ in 0..<8 {
        first.sendCommand("go depth 1"); second.sendCommand("go depth 1")
        await first.waitForIdle(); await second.waitForIdle()
        let a = firstOutput.take().filter { $0.hasPrefix("bestmove ") }
        let b = secondOutput.take().filter { $0.hasPrefix("bestmove ") }
        #expect(a == b)
        sequence += a
    }
    #expect(Set(sequence).count > 1)
    first.sendCommand("ucinewgame"); first.sendCommand("go depth 1")
    await first.waitForIdle()
    #expect(firstOutput.take().filter { $0.hasPrefix("bestmove ") }.first == sequence.first)
    await first.shutdown(); await second.shutdown()
}

@Test func configuredMoveRestrictionsSurviveGoAndIntersectSearchmoves() async throws {
    let model = FakeModel(); let capture = Capture()
    let engine = MaiaEngine(configuration: .init(model: .init(modelURL: URL(fileURLWithPath: "/unused")),
        sampling: .init(allowedMoves: ["e2e4"])), backend: await model.backend) { capture.append($0) }
    try engine.start()
    engine.sendCommand("go depth 1"); await engine.waitForIdle()
    #expect(capture.take().contains("bestmove e2e4"))
    engine.sendCommand("go searchmoves d2d4 e2e4"); await engine.waitForIdle()
    #expect(capture.take().contains("bestmove e2e4"))
    engine.sendCommand("go searchmoves d2d4"); await engine.waitForIdle()
    let failure = capture.take()
    #expect(failure.contains { $0.hasPrefix("info string MaiaEmbedded error:") })
    #expect(failure.contains("bestmove 0000"))
    await engine.shutdown()
}
