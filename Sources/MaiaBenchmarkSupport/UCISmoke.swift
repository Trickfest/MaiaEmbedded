// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import MaiaEmbedded
import MaiaUCI
import ChessCore

/// Thread-safe ordered capture shared by CLI validation tools, not engine policy.
public final class MaiaLineCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    public init() {}
    public func append(_ line: String) { lock.lock(); defer { lock.unlock() }; storage.append(line) }
    public func take() -> [String] { lock.lock(); defer { lock.unlock() }; let result = storage; storage.removeAll(); return result }
}
public enum MaiaUCIChecks {
    public static func run(modelURL: URL, iterations: Int) async throws {
        guard (1...100_000).contains(iterations) else { throw MaiaError.invalidRequest("Iterations must be 1...100000.") }
        let capture = MaiaLineCapture()
        let engine = MaiaEngine(configuration: .init(model: .init(modelURL: modelURL), sampling: .init(seed: 7))) { capture.append($0) }
        do {
            try engine.start()
            engine.sendCommand("uci"); engine.sendCommand("isready")
            await engine.waitForIdle()
            let handshake = capture.take()
            guard handshake.contains("uciok"), handshake.contains("readyok") else { throw MaiaError.invalidRequest("UCI readiness failed: \(handshake)") }
            let fixtures = try ReferenceCorpus.load().cases
            for i in 0..<iterations {
                try Task.checkCancellation()
                let fixture = fixtures[i % fixtures.count]
                let moves = fixture.moves.isEmpty ? "" : " moves " + fixture.moves.joined(separator: " ")
                engine.sendCommand("position fen " + fixture.initialFEN + moves)
                engine.sendCommand("go depth 1")
                await engine.waitForIdle()
                let lines = capture.take()
                let best = lines.filter { $0.hasPrefix("bestmove ") }
                guard best.count == 1 else { throw MaiaError.invalidRequest("Expected exactly one bestmove, received \(best.count).") }
                let move = String(best[0].dropFirst(9))
                guard fixture.terminal ? move == "0000" : fixture.legalMoves.contains(move) else {
                    throw MaiaError.invalidRequest("Illegal UCI result for \(fixture.id): \(move)")
                }
            }
            engine.sendCommand("position startpos")
            engine.sendCommand("go infinite")
            await engine.waitForIdle()
            guard !capture.take().contains(where: { $0.hasPrefix("bestmove ") }) else {
                throw MaiaError.invalidRequest("Infinite request completed before stop.")
            }
            engine.sendCommand("stop"); engine.sendCommand("stop")
            await engine.waitForIdle()
            guard capture.take().filter({ $0.hasPrefix("bestmove ") }).count == 1 else {
                throw MaiaError.invalidRequest("Infinite stop did not produce one bestmove.")
            }
            await engine.shutdown()
            try engine.start()
            engine.sendCommand("isready"); await engine.waitForIdle()
            guard capture.take().contains("readyok") else { throw MaiaError.invalidRequest("Restart readiness failed.") }
            await engine.shutdown()
        } catch {
            await engine.shutdown(); throw error
        }
    }
}
