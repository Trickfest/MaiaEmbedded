// SPDX-License-Identifier: AGPL-3.0-only
import ChessCore
import Foundation

public struct MaiaRequest: Codable, Sendable {
    public var initialFEN: String
    public var moves: [String]
    public var useHistory: Bool
    public var selfRating: Int
    public var opponentRating: Int
    public init(initialFEN: String, moves: [String] = [], useHistory: Bool = false,
                selfRating: Int = 1600, opponentRating: Int = 1600) {
        self.initialFEN = initialFEN; self.moves = moves; self.useHistory = useHistory
        self.selfRating = selfRating; self.opponentRating = opponentRating
    }
    public func validate() throws { _ = try MaiaEncoding.prepare(self) }
}
