// SPDX-License-Identifier: AGPL-3.0-only
import Foundation
import MaiaEmbedded

/// A restartable in-process UCI adapter over the direct Maia Swift API.
///
/// Commands and callbacks each preserve FIFO order on separate serial queues.
/// The adapter does not redirect process-wide streams. Keep the engine alive,
/// call `start()`, send `uci`, then send `isready` after `uciok`. Only `readyok`
/// confirms that the native model loaded; hosts need error handling and deadlines.
///
/// One finite `go` requests a primary prediction, not iterative chess search.
/// UCI time/depth limits do not calibrate playing strength or interrupt kernels.
/// Swift `stop()` closes the interface; the UCI `stop` command instead completes
/// an active request with a best move. Await `shutdown()` before releasing or
/// replacing a model. Independent engine instances each consume model memory.
public final class MaiaEngine: @unchecked Sendable {
    /// An ordered, off-main-actor callback receiving one UCI output line.
    ///
    /// Return promptly and dispatch UI work to the main actor. Do not synchronously
    /// block this callback waiting for a method that drains the output queue.
    public typealias LineHandler = @Sendable (String) -> Void
    /// Initial model, rating and UCI option defaults for each start/stop generation.
    public struct Configuration: Sendable {
        /// The pinned local model URL and CPU thread settings.
        public var model: MaiaConfiguration
        /// Side-to-move Lichess conditioning rating in 600...2600; defaults to 1600.
        public var selfRating: Int
        /// Opponent Lichess conditioning rating in 600...2600; defaults to 1600.
        public var opponentRating: Int
        /// Move-selection controls; a configured seed produces an engine-owned sequence.
        ///
        /// Any `allowedMoves` restriction is intersected with UCI `searchmoves`.
        public var sampling: MaiaSamplingOptions
        /// Maximum legal policy candidates to report, from 1 through 20; defaults to 1.
        ///
        /// Candidates are ranked by original likelihood, not sampling-adjusted probability.
        public var multiPV: Int
        /// Whether predictions use recorded board history; defaults to false.
        public var useHistory: Bool
        /// Opt-in WDL-derived GUI scores, never searched engine evaluations.
        /// Whether to emit optional child-position WDL compatibility scores; defaults to false.
        ///
        /// Enabling this adds child predictions and latency. The emitted `score cp` is
        /// win-minus-loss in permille, not a searched centipawn position evaluation.
        public var emitsOutcomeScores: Bool
        /// Creates initial defaults without preparing a native model.
        ///
        /// - Parameters:
        ///   - model: Local model and CPU settings.
        ///   - selfRating: Side-to-move conditioning rating.
        ///   - opponentRating: Opposing-side conditioning rating.
        ///   - sampling: Temperature, TopP, optional seed and move restriction.
        ///   - multiPV: Number of one-move policy candidates to report.
        ///   - useHistory: Whether to encode recorded positions.
        ///   - emitsOutcomeScores: Whether to request extra outcome-derived scores.
        public init(model: MaiaConfiguration, selfRating: Int = 1600, opponentRating: Int = 1600,
                    sampling: MaiaSamplingOptions = .init(), multiPV: Int = 1,
                    useHistory: Bool = false, emitsOutcomeScores: Bool = false) {
            self.model = model; self.selfRating = selfRating; self.opponentRating = opponentRating
            self.sampling = sampling; self.multiPV = multiPV; self.useHistory = useHistory
            self.emitsOutcomeScores = emitsOutcomeScores
        }
        /// Checks model settings, sampling ranges, ratings and MultiPV bounds.
        ///
        /// The model file is verified and loaded later when readiness is requested.
        /// - Throws: `MaiaError.invalidRequest` for an invalid setting.
        public func validate() throws {
            try model.validate(); try sampling.validate()
            guard (600...2600).contains(selfRating), (600...2600).contains(opponentRating), (1...20).contains(multiPV) else {
                throw MaiaError.invalidRequest("Ratings must be 600...2600; MultiPV must be 1...20.")
            }
        }
    }

    private let configuration: Configuration
    private let backend: MaiaBackend
    private let handler: LineHandler
    private let control = DispatchQueue(label: "MaiaEmbedded.uci.commands")
    private let output = DispatchQueue(label: "MaiaEmbedded.uci.output")
    // The unchecked Sendable conformance relies on command-queue confinement
    // for these fields; callbacks run on output and consult control before use.
    private var running = false
    private var epoch = UUID()
    private var requestID = UUID()
    private var position = MaiaRequest(initialFEN: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    private var options: Configuration
    private var prepareTask: Task<Void, Error>?
    private var searchTask: Task<Void, Never>?
    private var cleanupTask: Task<Void, Never>?
    private var canceledSearchTail: Task<Void, Never>?
    private var prepared = false
    private var readyReplies = 0
    private var active = false
    private var infinite = false
    private var stopRequested = false
    private var heldMove: String?
    private var generator: MaiaSeededGenerator?

    /// Creates a stopped adapter with its own unloaded native session.
    ///
    /// - Parameters:
    ///   - configuration: Defaults restored on a fresh start after stop/shutdown.
    ///   - lineHandler: A retained, ordered output callback; avoid strong ownership
    ///     cycles with the engine and return promptly from each callback.
    public convenience init(configuration: Configuration, lineHandler: @escaping LineHandler) {
        let session = MaiaSession(configuration: configuration.model)
        self.init(configuration: configuration, backend: MaiaBackend(
            prepare: { try await session.prepare() },
            predict: { try await session.predict($0) },
            unload: { await session.unload() }), lineHandler: lineHandler)
    }
    init(configuration: Configuration, backend: MaiaBackend, lineHandler: @escaping LineHandler) {
        self.configuration = configuration; self.options = configuration
        self.backend = backend; self.handler = lineHandler
    }
    deinit {
        prepareTask?.cancel(); searchTask?.cancel()
        let backend = backend
        let prior = cleanupTask; let retired = canceledSearchTail
        let search = searchTask; let preparation = prepareTask
        Task {
            await prior?.value; await retired?.value; await search?.value
            _ = try? await preparation?.value
            await backend.unload()
        }
    }
    /// Whether the command interface is open, regardless of model readiness or search state.
    public var isRunning: Bool { control.sync { running } }
    /// Opens the protocol interface; it does not send a handshake or load the model.
    ///
    /// Starting an already running instance is idempotent. After stop/shutdown,
    /// start resets position/options to configured defaults. New preparation waits
    /// for preceding native cleanup.
    /// - Throws: A configuration validation error before opening the interface.
    public func start() throws {
        try configuration.validate()
        control.sync {
            guard !running else { return }
            epoch = UUID(); requestID = UUID(); running = true
            options = configuration
            generator = options.sampling.seed.map(MaiaSeededGenerator.init(seed:))
            position = Self.startPosition
            prepared = false; prepareTask = nil; active = false
            readyReplies = 0; stopRequested = false; heldMove = nil
        }
    }
    /// Enqueues one UCI command and returns without waiting for its response.
    ///
    /// - Parameter command: One line, optionally ending in LF or CRLF. Embedded
    ///   newlines, NULs and input over 1 MiB are rejected. Commands on a stopped
    ///   adapter are ignored. Invalid commands emit diagnostics and preserve valid
    ///   position/options; native work errors are also reported through output.
    public func sendCommand(_ command: String) {
        control.async { [weak self] in self?.receive(command) }
    }
    /// Closes the current command/output generation and schedules native cleanup.
    ///
    /// This Swift lifecycle method does not emit a final best move. Queued old
    /// callbacks are suppressed, while a callback already executing can finish.
    /// Native cancellation is cooperative. Use `shutdown()` to await cleanup
    /// and callback drainage, or send the UCI `stop` command to finish a search.
    public func stop() { control.sync { close() } }
    /// Stops the interface, then awaits native cleanup and queued callback drainage.
    ///
    /// Use this before releasing resources or replacing a loaded engine. A callback
    /// that was already executing can complete before this method returns. Cleanup
    /// waits for native work even when the caller's task has been canceled.
    public func shutdown() async {
        let cleanup = control.sync { close(); return cleanupTask }
        await cleanup?.value
        await synchronizeOutput()
    }
    /// Waits for submitted preparation/prediction work and an output-queue fence.
    ///
    /// This is a snapshot of work already submitted, not a barrier against new
    /// concurrent commands. A completed `go infinite` prediction may still hold
    /// its best move: send the UCI `stop` command to finish that protocol request.
    /// Errors remain output diagnostics; this method does not throw or unload
    /// the model. Use `shutdown()` as the resource-lifecycle barrier.
    public func waitForIdle() async {
        let tasks = control.sync { (prepareTask, searchTask, canceledSearchTail) }
        _ = try? await tasks.0?.value
        await tasks.1?.value
        await tasks.2?.value
        await synchronizeOutput()
    }
    private func synchronizeOutput() async {
        await withCheckedContinuation { continuation in
            control.async { self.output.async { continuation.resume() } }
        }
    }
    private static var startPosition: MaiaRequest {
        MaiaRequest(initialFEN: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    }
    private func emit(_ line: String, request: UUID? = nil) {
        let generation = epoch
        output.async { [weak self] in
            guard let self, self.control.sync(execute: { self.running && self.epoch == generation && (request == nil || self.requestID == request) }) else { return }
            self.handler(line)
        }
    }
    private func diagnostic(_ message: String) {
        emit("info string MaiaEmbedded error: " + message.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " "))
    }
    // Retire canceled work instead of losing its cleanup dependency: a native
    // prediction can finish after its Swift task is canceled.
    private func invalidateSearch() {
        requestID = UUID(); searchTask?.cancel(); active = false
        if let search = searchTask {
            let prior = canceledSearchTail
            canceledSearchTail = Task { await prior?.value; await search.value }
            searchTask = nil
        }
        heldMove = nil; stopRequested = false
    }
    private func close() {
        guard running else { return }
        running = false; epoch = UUID(); requestID = UUID()
        readyReplies = 0; active = false; heldMove = nil; prepared = false
        let search = searchTask; let preparation = prepareTask; let prior = cleanupTask; let backend = backend
        let retired = canceledSearchTail; canceledSearchTail = nil
        search?.cancel(); preparation?.cancel()
        cleanupTask = Task {
            await prior?.value
            await retired?.value
            await search?.value
            _ = try? await preparation?.value
            await backend.unload()
        }
        searchTask = nil; prepareTask = nil
    }
    // A new protocol generation may start before old native work has drained.
    // Chain preparation behind cleanup so replacement models do not overlap.
    private func ensurePreparation() -> Task<Void, Error> {
        if let task = prepareTask { return task }
        let barrier = cleanupTask; let backend = backend; let generation = epoch
        let task = Task { [weak self] in
            do {
                await barrier?.value
                try Task.checkCancellation()
                try await backend.prepare()
                try Task.checkCancellation()
                self?.control.async { [weak self] in
                    guard let self, self.running, self.epoch == generation else { return }
                    self.prepared = true
                    for _ in 0..<self.readyReplies { self.emit("readyok") }
                    self.readyReplies = 0
                }
            } catch {
                let message = error.localizedDescription
                self?.control.async { [weak self] in
                    guard let self, self.running, self.epoch == generation else { return }
                    self.readyReplies = 0; self.prepareTask = nil
                    self.diagnostic(message)
                }
                throw error
            }
        }
        prepareTask = task
        return task
    }
    private func receive(_ raw: String) {
        guard running else { return }
        var line = raw
        // CRLF is one Swift Character; removeLast strips either supported terminator.
        if line.hasSuffix("\r\n") { line.removeLast() } else if line.hasSuffix("\n") { line.removeLast() }
        guard line.utf8.count <= 1_048_576, !line.contains("\0"), !line.contains("\n"), !line.contains("\r") else {
            diagnostic("Expected one UCI line of at most 1 MiB."); return
        }
        let tokens = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let command = tokens.first else { return }
        do {
            switch command {
            case "uci": handshake()
            case "isready":
                if prepared { emit("readyok") } else {
                    guard readyReplies < 64 else { throw MaiaError.invalidRequest("Too many pending readiness requests.") }
                    readyReplies += 1; _ = ensurePreparation()
                }
            case "setoption": try setOption(tokens)
            case "position":
                let request = try parsePosition(tokens)
                try request.validate()
                invalidateSearch(); position = request
            case "ucinewgame":
                invalidateSearch(); position = Self.startPosition
                generator = options.sampling.seed.map(MaiaSeededGenerator.init(seed:))
            case "go": try go(tokens)
            case "stop":
                stopRequested = true
                if let move = heldMove { finish(move) }
            case "quit": close()
            case "debug": break
            case "ponderhit": throw MaiaError.invalidRequest("Pondering is not supported.")
            default: throw MaiaError.invalidRequest("Unsupported UCI command: \(command)")
            }
        } catch { diagnostic(error.localizedDescription) }
    }
    private func handshake() {
        emit("id name MaiaEmbedded Maia-3 79M")
        emit("id author CSSLab; MaiaEmbedded contributors")
        for name in ["Elo", "SelfElo", "OppoElo"] {
            emit("option name \(name) type spin default \(name == "OppoElo" ? configuration.opponentRating : configuration.selfRating) min 600 max 2600")
        }
        emit("option name Temperature type string default \(configuration.sampling.temperature)")
        emit("option name TopP type string default \(configuration.sampling.topP)")
        emit("option name MultiPV type spin default \(configuration.multiPV) min 1 max 20")
        emit("option name UseHistory type check default \(configuration.useHistory)")
        emit("option name OutcomeScores type check default \(configuration.emitsOutcomeScores)")
        emit("option name Seed type string default \(configuration.sampling.seed.map(String.init) ?? "random")")
        emit("info string Maia predicts human play; optional outcome scores are WDL-derived compatibility values.")
        emit("uciok")
    }
    private func setOption(_ tokens: [String]) throws {
        guard !active else { throw MaiaError.invalidRequest("Stop the active request before changing options.") }
        guard tokens.count >= 5, tokens[1] == "name", let valueIndex = tokens.firstIndex(of: "value"), valueIndex > 2, valueIndex + 2 == tokens.count else {
            throw MaiaError.invalidRequest("Expected setoption name NAME value VALUE.")
        }
        let name = tokens[2..<valueIndex].joined(separator: " ").lowercased()
        let value = tokens[valueIndex + 1]
        var next = options
        switch name {
        case "elo", "selfelo", "oppoelo":
            guard let rating = Int(value), (600...2600).contains(rating) else { throw MaiaError.invalidRequest("Elo must be 600...2600.") }
            if name != "oppoelo" { next.selfRating = rating }
            if name != "selfelo" { next.opponentRating = rating }
        case "temperature":
            guard let number = Double(value) else { throw MaiaError.invalidRequest("Invalid Temperature.") }
            next.sampling.temperature = number
        case "topp":
            guard let number = Double(value) else { throw MaiaError.invalidRequest("Invalid TopP.") }
            next.sampling.topP = number
        case "multipv":
            guard let count = Int(value), (1...20).contains(count) else { throw MaiaError.invalidRequest("MultiPV must be 1...20.") }
            next.multiPV = count
        case "usehistory", "outcomescores":
            guard value == "true" || value == "false" else { throw MaiaError.invalidRequest("Expected true or false.") }
            if name == "usehistory" { next.useHistory = value == "true" } else { next.emitsOutcomeScores = value == "true" }
        case "seed":
            if value == "random" { next.sampling.seed = nil }
            else if let seed = UInt64(value) { next.sampling.seed = seed }
            else { throw MaiaError.invalidRequest("Seed must be random or an unsigned integer.") }
        default: throw MaiaError.invalidRequest("Unsupported option: \(name)")
        }
        try next.validate(); options = next
        if name == "seed" { generator = next.sampling.seed.map(MaiaSeededGenerator.init(seed:)) }
    }
    private func parsePosition(_ tokens: [String]) throws -> MaiaRequest {
        guard tokens.count >= 2 else { throw MaiaError.invalidRequest("Missing position.") }
        let fen: String; let offset: Int
        if tokens[1] == "startpos" { fen = Self.startPosition.initialFEN; offset = 2 }
        else if tokens[1] == "fen", tokens.count >= 8 { fen = tokens[2..<8].joined(separator: " "); offset = 8 }
        else { throw MaiaError.invalidRequest("Expected startpos or a six-field FEN.") }
        if tokens.count == offset { return MaiaRequest(initialFEN: fen) }
        guard tokens[offset] == "moves", tokens.count > offset + 1 else { throw MaiaError.invalidRequest("Expected a move list after moves.") }
        return MaiaRequest(initialFEN: fen, moves: Array(tokens[(offset+1)...]))
    }
    private func go(_ tokens: [String]) throws {
        guard !active else { throw MaiaError.invalidRequest("One outstanding go request is allowed.") }
        var allowed: Set<String>?
        var isInfinite = false
        var i = 1
        let limits: Set<String> = ["wtime","btime","winc","binc","movestogo","movetime","depth","nodes","mate"]
        while i < tokens.count {
            let token = tokens[i]
            if token == "infinite" { isInfinite = true; i += 1 }
            else if token == "ponder" { throw MaiaError.invalidRequest("Pondering is not supported.") }
            else if token == "searchmoves" {
                i += 1; var moves: Set<String> = []
                while i < tokens.count, tokens[i] != "infinite", !limits.contains(tokens[i]), tokens[i] != "ponder" {
                    moves.insert(tokens[i]); i += 1
                }
                guard !moves.isEmpty else { throw MaiaError.invalidRequest("searchmoves must not be empty.") }
                allowed = moves
            } else if limits.contains(token) {
                guard i + 1 < tokens.count, let value = UInt64(tokens[i+1]), value > 0 || ["wtime","btime","winc","binc"].contains(token) else {
                    throw MaiaError.invalidRequest("Invalid \(token) limit.")
                }
                i += 2
            } else { throw MaiaError.invalidRequest("Unsupported go argument: \(token)") }
        }
        // Maia has no iterative search. Finite limits all request one inference;
        // limits never promise a hard interrupt of a native kernel.
        var request = position
        request.selfRating = options.selfRating; request.opponentRating = options.opponentRating; request.useHistory = options.useHistory
        try request.validate()
        var sampling = options.sampling
        if let allowed {
            sampling.allowedMoves = sampling.allowedMoves.map { $0.intersection(allowed) } ?? allowed
        }
        if var stream = generator { sampling.seed = stream.next(); generator = stream }
        let count = options.multiPV; let scores = options.emitsOutcomeScores
        let preparation = ensurePreparation(); let backend = backend
        let generation = epoch; let token = UUID(); requestID = token
        active = true; infinite = isInfinite; stopRequested = false; heldMove = nil
        searchTask = Task { [weak self, request, sampling] in
            do {
                try await preparation.value
                try Task.checkCancellation()
                let prediction = try await backend.predict(request)
                try Task.checkCancellation()
                let selection = try MaiaSampler.select(from: prediction, options: sampling)
                var lines: [String] = []
                for (index, move) in prediction.rankedMoves.filter({ sampling.allowedMoves?.contains($0) ?? true }).prefix(count).enumerated() {
                    if self?.control.sync(execute: { self?.stopRequested ?? true }) ?? true { break }
                    var suffix = ""
                    if scores {
                        var child = request; child.moves.append(move)
                        child.selfRating = request.opponentRating; child.opponentRating = request.selfRating
                        let after = try await backend.predict(child)
                        if let outcome = after.outcome {
                            let win = Int((outcome.loss * 1000).rounded())
                            let loss = min(1000 - win, Int((outcome.win * 1000).rounded()))
                            let draw = max(0, 1000 - win - loss)
                            suffix = " score cp \(win - loss) wdl \(win) \(draw) \(loss)"
                        }
                    }
                    lines.append("info multipv \(index + 1)\(suffix) pv \(move)")
                    lines.append("info string Maia policy \(move) probability \(prediction.probabilities[move]!)")
                }
                let completedLines = lines
                self?.control.async { [weak self] in
                    guard let self, self.running, self.epoch == generation, self.requestID == token else { return }
                    for line in completedLines { self.emit(line, request: token) }
                    let move = selection.move ?? "0000"
                    if self.infinite && !self.stopRequested { self.heldMove = move }
                    else { self.finish(move) }
                }
            } catch {
                let message = error.localizedDescription
                self?.control.async { [weak self] in
                    guard let self, self.running, self.epoch == generation, self.requestID == token else { return }
                    self.diagnostic(message); self.finish("0000")
                }
            }
        }
    }
    private func finish(_ move: String) {
        guard active else { return }
        active = false; heldMove = nil; stopRequested = false
        emit("bestmove \(move)", request: requestID)
    }
}

/// Internal dependency seam permits deterministic protocol/race tests without a
/// 316 MB asset or timing-dependent guesses about the native runtime.
struct MaiaBackend: Sendable {
    let prepare: @Sendable () async throws -> Void
    let predict: @Sendable (MaiaRequest) async throws -> MaiaPrediction
    let unload: @Sendable () async -> Void
}
