// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

/// Selection controls; original model probabilities are never rewritten.
public struct MaiaSamplingOptions: Equatable, Sendable {
    /// Finite logit temperature in 0...5; defaults to 1.
    ///
    /// Zero chooses the highest-logit eligible move without a random draw. Lower
    /// positive values concentrate probability; higher values spread it out.
    public var temperature: Double
    /// Finite cumulative cutoff in (0, 1], applied after temperature; defaults to 1.
    ///
    /// The pinned upstream convention retains candidates whose cumulative
    /// probability is less than or equal to this value, keeping at least one. The
    /// move crossing the cutoff can be excluded; 1 retains the full distribution.
    public var topP: Double
    /// Optional seed for the sampler overload that creates its own generator.
    ///
    /// That overload restarts the same stream on every call. The overload accepting
    /// a generator uses the caller's stream and ignores this field.
    public var seed: UInt64?
    /// An optional intersection with the prediction's legal coordinate-UCI moves.
    ///
    /// Nil allows all moves. Unknown strings are excluded by intersection; no
    /// remaining move in a nonterminal position causes an invalid-request error.
    public var allowedMoves: Set<String>?
    /// Creates selection options without validating their ranges.
    ///
    /// - Parameters:
    ///   - temperature: Logit temperature; 0 gives deterministic argmax.
    ///   - topP: Upstream-style cumulative probability cutoff.
    ///   - seed: Per-call seed, or nil for system randomness.
    ///   - allowedMoves: Optional legal-move restriction.
    public init(temperature: Double = 1, topP: Double = 1, seed: UInt64? = nil, allowedMoves: Set<String>? = nil) {
        self.temperature = temperature; self.topP = topP
        self.seed = seed; self.allowedMoves = allowedMoves
    }
    /// Checks temperature and TopP bounds and finiteness.
    ///
    /// Move restrictions are intersected with the prediction during selection.
    /// - Throws: `MaiaError.invalidRequest` for invalid numeric settings.
    public func validate() throws {
        guard temperature.isFinite, (0...5).contains(temperature), topP.isFinite, topP > 0, topP <= 1 else {
            throw MaiaError.invalidRequest("Temperature must be in 0...5 and TopP in (0,1].")
        }
    }
}

/// SplitMix64 stream, for reproducible selection independent of global randomness.
public struct MaiaSeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    /// Starts a reproducible stream at the supplied seed. This is not a cryptographic RNG.
    public init(seed: UInt64) { state = seed }
    /// Advances the stream and returns its next 64-bit value.
    public mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }
}

/// A selected move together with its original prediction and adjusted distribution.
public struct MaiaSelection: Codable, Sendable {
    /// The sampled coordinate-UCI move, or nil for a terminal prediction.
    public let move: String?
    /// The unchanged prediction supplied to the sampler.
    public let prediction: MaiaPrediction
    /// Probability after temperature, move restriction, and TopP filtering.
    public let selectionProbabilities: [String: Double]
}

/// Selects moves from an existing prediction without running the model.
public enum MaiaSampler {
    /// Selects using a fresh seeded or system-random generator.
    ///
    /// - Parameters:
    ///   - prediction: A prediction returned by a prepared session.
    ///   - options: Temperature, cutoff, optional move restriction and per-call seed.
    /// - Returns: A selection with original and adjusted probabilities kept separate.
    ///   Terminal predictions return a nil move after validating options.
    /// - Throws: `MaiaError` for invalid options, no eligible nonterminal moves or
    ///   non-finite policy logits. A repeated seed restarts selection each call.
    public static func select(from prediction: MaiaPrediction, options: MaiaSamplingOptions = .init()) throws -> MaiaSelection {
        if let seed = options.seed {
            var generator = MaiaSeededGenerator(seed: seed)
            return try select(from: prediction, options: options, using: &generator)
        }
        var generator = SystemRandomNumberGenerator()
        return try select(from: prediction, options: options, using: &generator)
    }

    /// Selects using a caller-owned random stream, advancing it when sampling occurs.
    ///
    /// - Parameters:
    ///   - prediction: A prediction returned by a prepared session.
    ///   - options: Selection settings; `options.seed` is ignored by this overload.
    ///   - generator: A retained stream for reproducible sequences across calls.
    /// - Returns: The selected move and its adjusted distribution. Terminal results
    ///   and temperature-zero selection do not consume a random value.
    /// - Throws: `MaiaError` for invalid options, an empty eligible move set or
    ///   non-finite logits. Reproducibility requires identical logits and settings.
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
