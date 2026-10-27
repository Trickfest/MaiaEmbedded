// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import Testing
@testable import MaiaEmbedded

private func policy(_ values: [String: Float], terminal: Bool = false) throws -> MaiaPrediction {
    let keys = values.keys.sorted()
    let probabilities = terminal ? [] : try MaiaEncoding.softmax(keys.map { values[$0]! })
    return MaiaPrediction(terminal: terminal, logits: values,
        probabilities: Dictionary(uniqueKeysWithValues: zip(keys, probabilities)), valueLogits: [], outcomeProbabilities: [])
}
@Test func seededSelectionIsReproducibleAndCoversDistribution() throws {
    let prediction = try policy(["e2e4": 0, "d2d4": 0, "c2c4": 0])
    var a = MaiaSeededGenerator(seed: 0), b = MaiaSeededGenerator(seed: 0)
    let first = try (0..<300).map { _ in try MaiaSampler.select(from: prediction, using: &a).move! }
    let second = try (0..<300).map { _ in try MaiaSampler.select(from: prediction, using: &b).move! }
    #expect(first == second)
    #expect(Set(first) == Set(prediction.probabilities.keys))
}
@Test func argmaxFilteringAndBaseProbabilitiesAreDistinct() throws {
    let prediction = try policy(["e2e4": 2, "d2d4": 1, "c2c4": 0])
    let chosen = try MaiaSampler.select(from: prediction, options: .init(temperature: 0))
    #expect(chosen.move == "e2e4")
    #expect(chosen.selectionProbabilities == ["e2e4": 1])
    #expect(chosen.prediction.probabilities["e2e4"]! < 1)
    let limited = try MaiaSampler.select(from: prediction, options: .init(allowedMoves: ["d2d4"]))
    #expect(limited.move == "d2d4")
    #expect(throws: MaiaError.self) { try MaiaSampler.select(from: prediction, options: .init(allowedMoves: [])) }
}
@Test func topPUsesPinnedUpstreamCumulativeConvention() throws {
    let prediction = try policy(["e2e4": 0, "d2d4": 0, "c2c4": 0])
    let selected = try MaiaSampler.select(from: prediction, options: .init(topP: 0.8, seed: 1))
    #expect(selected.selectionProbabilities.count == 2)
    #expect(abs(selected.selectionProbabilities.values.reduce(0,+) - 1) < 1e-12)
    #expect(try MaiaSampler.select(from: prediction, options: .init(topP: 0.01)).selectionProbabilities.count == 1)
}
@Test func invalidSamplingAndTerminalPolicy() throws {
    let prediction = try policy(["e2e4": 0])
    for options in [MaiaSamplingOptions(temperature: .nan), .init(temperature: -1), .init(topP: 0), .init(topP: .infinity)] {
        #expect(throws: MaiaError.self) { try MaiaSampler.select(from: prediction, options: options) }
    }
    #expect(try MaiaSampler.select(from: policy([:], terminal: true)).move == nil)
}
@Test func configurationAndInputBoundsAreValidated() throws {
    #expect(throws: MaiaError.self) { try MaiaConfiguration(modelURL: URL(string: "https://example.com/model")!).validate() }
    #expect(throws: MaiaError.self) { try MaiaConfiguration(modelURL: URL(fileURLWithPath: "/unused"), intraOpThreads: 0).validate() }
    #expect(throws: MaiaError.self) { try MaiaRequest(initialFEN: String(repeating: "x", count: 1025)).validate() }
}
