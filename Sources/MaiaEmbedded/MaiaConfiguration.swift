// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

/// Local resources and CPU settings for one model session. No implicit downloads.
public struct MaiaConfiguration: Equatable, Sendable {
    public var modelURL: URL
    public var intraOpThreads: Int
    public init(modelURL: URL, intraOpThreads: Int = 2) {
        self.modelURL = modelURL
        self.intraOpThreads = intraOpThreads
    }
    public func validate() throws {
        guard modelURL.isFileURL else { throw MaiaError.invalidRequest("Use a local model file URL.") }
        guard (1...16).contains(intraOpThreads) else {
            throw MaiaError.invalidRequest("CPU threads must be in 1...16.")
        }
    }
}
