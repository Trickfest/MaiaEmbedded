// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

/// The original legal policy and human-game outcome prediction for a position.
///
/// Move keys use coordinate-UCI notation. Sampling does not rewrite these values.
/// Outcome predictions describe human games, not searched engine evaluations.
public struct MaiaPrediction: Codable, Sendable {
    /// Whether ChessCore determined an automatic terminal outcome for the line.
    ///
    /// A terminal result has empty move policy and value logits, with a known
    /// loss/draw/win outcome instead of neural inference.
    public let terminal: Bool
    /// Raw model logits for legal moves only; empty for terminal positions.
    public let logits: [String: Float]
    /// Softmax probabilities normalized over legal moves before selection filtering.
    public let probabilities: [String: Double]
    /// Raw loss/draw/win logits for the side to move; empty for terminal results.
    public let valueLogits: [Float]
    /// Loss, draw and win probabilities, in that order, relative to the side to move.
    public let outcomeProbabilities: [Double]
    /// The highest-probability legal move, or nil when no candidate exists.
    ///
    /// This can differ from a move sampled with `MaiaSampler`.
    public var topMove: String? { rankedMoves.first }
}


public extension MaiaPrediction {
    /// Human-game outcome probabilities, relative to the side to move.
    ///
    /// Returns nil if decoded data does not contain exactly three outcome values.
    var outcome: MaiaOutcome? {
        guard outcomeProbabilities.count == 3 else { return nil }
        return MaiaOutcome(loss: outcomeProbabilities[0], draw: outcomeProbabilities[1], win: outcomeProbabilities[2])
    }
    /// Candidates ordered by original model likelihood, with lexical tie breaking.
    ///
    /// Sampling controls do not change this ranking.
    var rankedMoves: [String] {
        probabilities.keys.sorted {
            if probabilities[$0]! == probabilities[$1]! { return $0 < $1 }
            return probabilities[$0]! > probabilities[$1]!
        }
    }
}
/// Human-game outcome probabilities relative to the position's side to move.
///
/// For terminal predictions these represent the known result. Nonterminal
/// values come from the model; they are not centipawn or mate evaluations.
public struct MaiaOutcome: Codable, Equatable, Sendable {
    /// Probability of a loss for the side to move.
    public let loss: Double
    /// Probability of a draw.
    public let draw: Double
    /// Probability of a win for the side to move.
    public let win: Double
}
