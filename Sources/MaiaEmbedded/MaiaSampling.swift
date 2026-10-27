// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

/// Selection controls; original model probabilities are never rewritten.
public struct MaiaSamplingOptions: Equatable, Sendable {
    public var temperature: Double
    public var topP: Double
    public var seed: UInt64?
    public var allowedMoves: Set<String>?
    public init(temperature: Double = 1, topP: Double = 1, seed: UInt64? = nil, allowedMoves: Set<String>? = nil) {
        self.temperature = temperature; self.topP = topP
        self.seed = seed; self.allowedMoves = allowedMoves
    }
    public func validate() throws {
        guard temperature.isFinite, (0...5).contains(temperature), topP.isFinite, topP > 0, topP <= 1 else {
            throw MaiaError.invalidRequest("Temperature must be in 0...5 and TopP in (0,1].")
        }
    }
}

/// SplitMix64 stream, for reproducible selection independent of global randomness.
public struct MaiaSeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }
}

public struct MaiaSelection: Codable, Sendable {
    public let move: String?
    public let prediction: MaiaPrediction
    /// Probability after temperature, move restriction, and TopP filtering.
    public let selectionProbabilities: [String: Double]
}

public enum MaiaSampler {
    public static func select(from prediction: MaiaPrediction, options: MaiaSamplingOptions = .init()) throws -> MaiaSelection {
        if let seed = options.seed {
            var generator = MaiaSeededGenerator(seed: seed)
            return try select(from: prediction, options: options, using: &generator)
        }
        var generator = SystemRandomNumberGenerator()
        return try select(from: prediction, options: options, using: &generator)
    }

    public static func select<R: RandomNumberGenerator>(from prediction: MaiaPrediction,
        options: MaiaSamplingOptions = .init(), using generator: inout R) throws -> MaiaSelection {
        try options.validate()
        if prediction.terminal { return MaiaSelection(move: nil, prediction: prediction, selectionProbabilities: [:]) }
        let moves = prediction.logits.keys.filter { options.allowedMoves?.contains($0) ?? true }.sorted()
        guard !moves.isEmpty else { throw MaiaError.invalidRequest("No legal moves remain after filtering.") }
        guard moves.allSatisfy({ prediction.logits[$0]!.isFinite }) else {
            throw MaiaError.incompatibleModel("Non-finite policy logits.")
        }
        let ranked = moves.sorted {
            if prediction.logits[$0]! == prediction.logits[$1]! { return $0 < $1 }
            return prediction.logits[$0]! > prediction.logits[$1]!
        }
        if options.temperature == 0 {
            return MaiaSelection(move: ranked[0], prediction: prediction, selectionProbabilities: [ranked[0]: 1])
        }
        let maximum = Double(prediction.logits[ranked[0]]!)
        let weights = ranked.map { exp((Double(prediction.logits[$0]!) - maximum) / options.temperature) }
        let total = weights.reduce(0,+)
        let probabilities = weights.map { $0 / total }
        // Match the pinned upstream cumulative <= TopP convention, retaining at
        // least the top move. TopP=1 explicitly keeps the entire distribution.
        var kept = ranked.count
        if options.topP < 1 {
            kept = 0
            var cumulative = 0.0
            for probability in probabilities {
                cumulative += probability
                if cumulative <= options.topP { kept += 1 } else { break }
            }
            kept = max(1, kept)
        }
        let keptTotal = probabilities.prefix(kept).reduce(0,+)
        let distribution = Dictionary(uniqueKeysWithValues: (0..<kept).map { (ranked[$0], probabilities[$0] / keptTotal) })
        let draw = Double(generator.next() >> 11) / 9_007_199_254_740_992
        var cumulative = 0.0
        var chosen = ranked[kept - 1]
        for move in ranked.prefix(kept) {
            cumulative += distribution[move]!
            if draw < cumulative { chosen = move; break }
        }
        return MaiaSelection(move: chosen, prediction: prediction, selectionProbabilities: distribution)
    }
}
