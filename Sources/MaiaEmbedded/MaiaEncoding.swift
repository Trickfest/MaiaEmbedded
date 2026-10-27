// SPDX-License-Identifier: AGPL-3.0-only
// Adapted from CSSLab Maia-3 dataset.py and utils.py; see ThirdParty/Maia3.
import ChessCore
import CryptoKit
import Foundation

/// Validated tensor data and rules-derived metadata consumed by native inference.
/// Token bytes also form the independent reference-fixture checksum.
package struct MaiaInput: Sendable {
    package let tokens: [Float]
    package let legalMoves: [String]
    package let terminal: Bool
    package let blackToMove: Bool
    package let terminalOutcome: [Double]
    package var tokenSHA256: String {
        tokens.withUnsafeBytes { SHA256.hash(data: Data($0)).map { String(format: "%02x", $0) }.joined() }
    }
}

/// Adapts legal recorded positions to the pinned Maia-3 board and move vocabulary.
/// Keep fixture byte hashes authoritative when changing layout or orientation.
package enum MaiaEncoding {
    package static func prepare(_ request: MaiaRequest) throws -> MaiaInput {
        do { return try encode(request) }
        catch let error as MaiaError { throw error }
        catch { throw MaiaError.invalidRequest(error.localizedDescription) }
    }
    private static func encode(_ request: MaiaRequest) throws -> MaiaInput {
        guard (600...2600).contains(request.selfRating), (600...2600).contains(request.opponentRating) else {
            throw MaiaError.invalidRequest("Ratings must be in 600...2600.")
        }
        guard request.initialFEN.utf8.count <= 1024, request.moves.count <= 20_000 else {
            throw MaiaError.invalidRequest("Position/history exceeds the supported input size.")
        }
        let position = try FENSerializer().validatedPosition(from: request.initialFEN)
        let game = Game(position: position)
        var history = [position]
        for move in request.moves {
            try game.applyLegal(move: move)
            if request.useHistory {
                history.append(game.position)
                if history.count > 8 { history.removeFirst() }
            }
        }
        let boards = request.useHistory ? Array(history.suffix(8)) : [game.position]
        // The model consumes eight slots: pad the earliest retained board, then
        // append recorded boards in chronological order. Current-only mode uses
        // the final board for every slot.
        let padded = Array(repeating: boards[0], count: 8 - boards.count) + boards
        var tokens = [Float](repeating: 0, count: 64 * 97)
        let kinds: [PieceKind] = [.pawn, .knight, .bishop, .rook, .queen, .king]
        // Square-major [64, 97] FP32 layout: each history slot uses twelve piece
        // channels. Orient each board to its own side to move, as the pinned
        // tokenizer does; move-vocabulary mirroring uses the final board's turn.
        for (h, board) in padded.enumerated() {
            let black = board.state.turn == .black
            for (square, piece) in board.board.enumeratedPieces() {
                let rank = black ? 7 - square.rank : square.rank
                let modelSquare = rank * 8 + square.file
                let ownColor = black ? piece.color == .black : piece.color == .white
                let channel = kinds.firstIndex(of: piece.kind)! + (ownColor ? 0 : 6)
                tokens[modelSquare * 97 + h * 12 + channel] = 1
            }
        }
        var terminalOutcome: [Double] = []
        if let outcome = game.status.outcome {
            switch outcome {
            case .draw: terminalOutcome = [0, 1, 0]
            case .win(let winner): terminalOutcome = winner == game.position.state.turn ? [0, 0, 1] : [1, 0, 0]
            }
        }
        return MaiaInput(tokens: tokens, legalMoves: game.legalMoves.map(\.description).sorted(),
                                   terminal: game.status.outcome != nil, blackToMove: game.position.state.turn == .black, terminalOutcome: terminalOutcome)
    }

    /// Maps a legal move into 4,096 from/to entries or 256 promotion entries.
    /// The queen/rook/bishop/knight ordering is part of checkpoint compatibility.
    package static func moveIndex(_ uci: String, blackToMove: Bool) throws -> Int {
        let move = try Move(string: uci)
        let fromRank = blackToMove ? 7 - move.from.rank : move.from.rank
        let toRank = blackToMove ? 7 - move.to.rank : move.to.rank
        if let promotion = move.promotion {
            guard fromRank == 6, toRank == 7,
                  let kind = [PieceKind.queen, .rook, .bishop, .knight].firstIndex(of: promotion) else {
                throw MaiaError.invalidRequest("Invalid promotion vocabulary entry: \(uci)")
            }
            return 4096 + move.from.file * 32 + move.to.file * 4 + kind
        }
        return (fromRank * 8 + move.from.file) * 64 + toRank * 8 + move.to.file
    }

    package static func softmax(_ values: [Float]) throws -> [Double] {
        guard let maximum = values.max(), values.allSatisfy(\.isFinite) else {
            throw MaiaError.incompatibleModel("Non-finite or empty model output.")
        }
        let weights = values.map { exp(Double($0 - maximum)) }
        let total = weights.reduce(0, +)
        guard total.isFinite, total > 0 else {
            throw MaiaError.incompatibleModel("Invalid probability distribution.")
        }
        return weights.map { $0 / total }
    }
}
