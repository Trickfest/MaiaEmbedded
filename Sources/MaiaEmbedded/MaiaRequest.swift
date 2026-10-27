// SPDX-License-Identifier: AGPL-3.0-only
import ChessCore
import Foundation

/// A root position and legal recorded line to predict, conditioned on two ratings.
///
/// Ratings describe the final side to move and its opponent, regardless of color.
/// They are Lichess human-play conditioning levels, not calibrated engine strengths.
public struct MaiaRequest: Codable, Sendable {
    /// The six-field root FEN, limited to 1,024 UTF-8 bytes.
    ///
    /// Validation checks position consistency, not historical reachability.
    public var initialFEN: String
    /// Up to 20,000 legal coordinate-UCI moves replayed from `initialFEN`.
    ///
    /// An empty array predicts the root. Earlier history cannot be reconstructed
    /// from a final-position FEN alone.
    public var moves: [String]
    /// Whether to encode up to the last eight replayed boards; defaults to false.
    ///
    /// Short histories repeat their earliest board as padding. When false, the
    /// final board fills all eight history slots. Moves are still legally replayed.
    public var useHistory: Bool
    /// The final side-to-move Lichess rating, from 600 through 2600; defaults to 1600.
    public var selfRating: Int
    /// The opposing side's Lichess rating, from 600 through 2600; defaults to 1600.
    public var opponentRating: Int
    /// Creates a request; validation is deferred until `validate()` or prediction.
    ///
    /// - Parameters:
    ///   - initialFEN: The root position as a six-field FEN.
    ///   - moves: Coordinate-UCI moves, including promotion suffixes where required.
    ///   - useHistory: Whether to supply recorded board history to the model.
    ///   - selfRating: The final side-to-move conditioning rating.
    ///   - opponentRating: The opposing side's conditioning rating.
    public init(initialFEN: String, moves: [String] = [], useHistory: Bool = false,
                selfRating: Int = 1600, opponentRating: Int = 1600) {
        self.initialFEN = initialFEN; self.moves = moves; self.useHistory = useHistory
        self.selfRating = selfRating; self.opponentRating = opponentRating
    }
    /// Validates ratings, input bounds, the root position and every recorded move.
    ///
    /// No model needs to be loaded.
    /// - Throws: `MaiaError.invalidRequest` if validation fails.
    public func validate() throws { _ = try MaiaEncoding.prepare(self) }
}
