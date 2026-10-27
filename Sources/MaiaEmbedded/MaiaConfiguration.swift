// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

/// Local resources and CPU settings for one model session. No implicit downloads.
public struct MaiaConfiguration: Equatable, Sendable {
    /// A local URL for the pinned Maia-3 79M ONNX export.
    ///
    /// Keep the file readable and unchanged until the session is unloaded. The
    /// package does not acquire model files automatically.
    public var modelURL: URL
    /// CPU threads used within an ONNX operation, from 1 through 16; defaults to 2.
    ///
    /// This is a runtime setting, not a count of simultaneous Swift requests.
    public var intraOpThreads: Int
    /// Creates a configuration without loading or validating a model.
    ///
    /// - Parameters:
    ///   - modelURL: A file URL for the supported export.
    ///   - intraOpThreads: CPU thread count, defaulting to 2.
    public init(modelURL: URL, intraOpThreads: Int = 2) {
        self.modelURL = modelURL
        self.intraOpThreads = intraOpThreads
    }
    /// Checks the file-URL requirement and CPU thread range.
    ///
    /// This does not check file existence, its checksum or its ONNX schema;
    /// `MaiaSession.prepare()` performs those checks.
    /// - Throws: `MaiaError.invalidRequest` for an invalid configuration.
    public func validate() throws {
        guard modelURL.isFileURL else { throw MaiaError.invalidRequest("Use a local model file URL.") }
        guard (1...16).contains(intraOpThreads) else {
            throw MaiaError.invalidRequest("CPU threads must be in 1...16.")
        }
    }
}
