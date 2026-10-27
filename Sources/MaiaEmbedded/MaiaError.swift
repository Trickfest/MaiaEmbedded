// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

/// Typed failures from configuration, position validation or native inference.
///
/// Switch on cases for recovery. Associated diagnostic text and localized
/// descriptions are intended for people, not a stable parsing format. Swift
/// task cancellation is reported separately as `CancellationError`.
public enum MaiaError: Error, LocalizedError, Sendable {
    /// A configuration, position, rating, sampling option or command is invalid.
    case invalidRequest(String)
    /// Model identity/schema or numerical output does not match the supported export.
    case incompatibleModel(String)
    /// The configured local model file could not be found.
    case modelNotFound
    /// An underlying runtime or file operation failed; the message contains details.
    case runtimeFailure(String)
    /// Prediction was requested before successful model preparation.
    case notLoaded
    /// A human-readable diagnostic suitable for error presentation.
    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let message), .incompatibleModel(let message): return message
        case .modelNotFound: return "The configured local model file was not found."
        case .runtimeFailure(let message): return "ONNX Runtime: \(message)"
        case .notLoaded: return "Load the model before requesting inference."
        }
    }
}
