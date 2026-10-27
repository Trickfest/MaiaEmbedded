// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import Testing
@testable import MaiaEmbedded
import MaiaBenchmarkSupport

@Test func upstreamEncodingAndLegality() throws {
    for fixture in try ReferenceCorpus.load().cases {
        let input = try MaiaEncoding.prepare(fixture.request)
        #expect(input.tokenSHA256 == fixture.tokenSHA256, "\(fixture.id)")
        #expect(input.legalMoves == fixture.legalMoves, "\(fixture.id)")
        #expect(input.terminal == fixture.terminal, "\(fixture.id)")
        for move in input.legalMoves {
            #expect((0..<4352).contains(try MaiaEncoding.moveIndex(move, blackToMove: input.blackToMove)))
        }
    }
}
@Test func rejectsIllegalMovesAndRatings() throws {
    var request = try ReferenceCorpus.load().cases[0].request
    request.moves = ["e2e5"]
    #expect(throws: (any Error).self) { try MaiaEncoding.prepare(request) }
    request.moves = []; request.selfRating = 599
    #expect(throws: (any Error).self) { try MaiaEncoding.prepare(request) }
}
@Test func blackPromotionVocabulary() throws {
    #expect(try MaiaEncoding.moveIndex("a2b1n", blackToMove: true) == 4103)
    #expect(try MaiaEncoding.moveIndex("e7e8q", blackToMove: false) == 4240)
}
@Test func stableSoftmaxRejectsInvalidOutput() throws {
    let values = try MaiaEncoding.softmax([10000, 10001, 9999])
    #expect(abs(values.reduce(0, +) - 1) < 1e-12)
    #expect(throws: (any Error).self) { try MaiaEncoding.softmax([.nan, 1]) }
    #expect(throws: (any Error).self) { try MaiaEncoding.softmax([]) }
}
@Test func inferenceRequiresLoadedModel() async throws {
    let session = MaiaSession(configuration: .init(modelURL: URL(fileURLWithPath: "/unused")))
    let request = try ReferenceCorpus.load().cases[0].request
    await #expect(throws: MaiaError.self) { try await session.predict(request) }
    await session.unload()
}

@Test func rejectsMalformedFENAndBrokenModelWithoutLoading() async throws {
    var request = try ReferenceCorpus.load().cases[0].request
    request.initialFEN = "not a FEN"
    #expect(throws: (any Error).self) { try MaiaEncoding.prepare(request) }
    let path = FileManager.default.temporaryDirectory.appendingPathComponent("maia-invalid-\(UUID().uuidString).onnx")
    try Data("invalid model".utf8).write(to: path)
    defer { try? FileManager.default.removeItem(at: path) }
    let session = MaiaSession(configuration: .init(modelURL: path))
    await #expect(throws: MaiaError.self) { try await session.prepare() }
    request = try ReferenceCorpus.load().cases[0].request
    let validRequest = request
    await #expect(throws: MaiaError.self) { try await session.predict(validRequest) }
}

@Test func rejectsAlreadyCanceledPrediction() async throws {
    let session = MaiaSession(configuration: .init(modelURL: URL(fileURLWithPath: "/unused")))
    let request = try ReferenceCorpus.load().cases[0].request
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await session.predict(request)
    }
    await #expect(throws: CancellationError.self) { try await task.value }
}
