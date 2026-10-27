// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

public enum MaiaError: Error, LocalizedError, Sendable {
    case invalidRequest(String)
    case incompatibleModel(String)
    case modelNotFound
    case runtimeFailure(String)
    case notLoaded
    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let message), .incompatibleModel(let message): return message
        case .modelNotFound: return "The configured local model file was not found."
        case .runtimeFailure(let message): return "ONNX Runtime: \(message)"
        case .notLoaded: return "Load the model before requesting inference."
        }
    }
}
