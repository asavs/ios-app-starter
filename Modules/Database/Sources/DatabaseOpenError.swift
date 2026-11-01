import Foundation

/// A store that couldn't be opened, with where it is and why, and nothing from inside it.
public struct DatabaseOpenError: Error, CustomStringConvertible {
    public let storage: DatabaseStorage
    public let underlying: any Error

    public var description: String {
        switch storage {
        case .persistent(let url): "Couldn't open the store \(url.lastPathComponent): \(underlying.localizedDescription)"
        case .memory: "Couldn't open the in-memory store: \(underlying.localizedDescription)"
        }
    }
}
