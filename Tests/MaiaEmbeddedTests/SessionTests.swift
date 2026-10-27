// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import Testing
import MaiaEmbedded
import MaiaBenchmarkSupport

@Test func malformedRequestsUseTypedErrors() throws {
    do {
        try MaiaRequest(initialFEN: "not a position").validate()
        Issue.record("Expected invalid request")
    } catch MaiaError.invalidRequest { }
}

/// Asset-dependent checks are opt-in; all encoding/sampling/protocol tests work
/// from a fresh checkout without a downloaded model or a Python runtime.
@Test(.enabled(if: ProcessInfo.processInfo.environment["MAIA_MODEL_PATH"] != nil))
func realSessionReuseUnloadAndIndependentInstances() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["MAIA_MODEL_PATH"])
    let config = MaiaConfiguration(modelURL: URL(fileURLWithPath: path))
    let first = MaiaSession(configuration: config)
    let second = MaiaSession(configuration: config)
    try await first.prepare()
    try await first.prepare() // Idempotent.
    let fixture = try #require(ReferenceCorpus.load().cases.first { !$0.terminal })
    let request = MaiaRequest(initialFEN: fixture.initialFEN, moves: fixture.moves,
                              useHistory: fixture.useHistory, selfRating: fixture.selfRating, opponentRating: fixture.opponentRating)
    let original = try await first.predict(request)
    #expect(Set(original.probabilities.keys) == Set(fixture.legalMoves))
    #expect(abs(original.probabilities.values.reduce(0,+) - 1) < 1e-10)
    let move = try await first.selectMove(request, options: .init(temperature: 0))
    #expect(move.move == original.topMove)
    try await second.prepare()
    await first.unload()
    #expect(await !first.isReady)
    #expect(await second.isReady)
    let independent = try await second.predict(request)
    #expect(independent.probabilities == original.probabilities)
    await second.unload()
    try await first.prepare()
    let restarted = try await first.predict(request)
    #expect(restarted.probabilities == original.probabilities)
    await first.unload()
}
