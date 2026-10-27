// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

public struct MaiaPrediction: Codable, Sendable {
    public let terminal: Bool
    public let logits: [String: Float]
    public let probabilities: [String: Double]
    /// Raw value-head order is loss, draw, win for the side to move.
    public let valueLogits: [Float]
    public let outcomeProbabilities: [Double]
    public var topMove: String? { rankedMoves.first }
}


public extension MaiaPrediction {
    /// Human-game outcome probabilities, relative to the side to move.
    var outcome: MaiaOutcome? {
        guard outcomeProbabilities.count == 3 else { return nil }
        return MaiaOutcome(loss: outcomeProbabilities[0], draw: outcomeProbabilities[1], win: outcomeProbabilities[2])
    }
    /// Candidates ordered by original model likelihood, with stable tie breaking.
    var rankedMoves: [String] {
        probabilities.keys.sorted {
            if probabilities[$0]! == probabilities[$1]! { return $0 < $1 }
            return probabilities[$0]! > probabilities[$1]!
        }
    }
}
public struct MaiaOutcome: Codable, Equatable, Sendable {
    public let loss: Double
    public let draw: Double
    public let win: Double
}
