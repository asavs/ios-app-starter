import Foundation

/// Everything an app keeps on the device, as the steps that erase it. `ResetLocalDataButton` runs
/// them after the person confirms.
///
/// ```swift
/// LocalDataReset([
///     .defaults(),                          // every UserDefaults key the app wrote
///     .secrets(in: KeychainStore()),        // the app's Keychain items
///     .init("database") { try container.erase() },
/// ])
/// ```
///
/// Every step runs even if an earlier one fails, so one broken store doesn't leave the rest behind;
/// the failures are then thrown together as a `Failure`.
public struct LocalDataReset {
    /// One store to erase, named for the error message.
    public struct Step {
        public let name: String
        let erase: () throws -> Void

        public init(_ name: String, erase: @escaping () throws -> Void) {
            self.name = name
            self.erase = erase
        }
    }

    /// The steps that failed, in order.
    public struct Failure: Error, CustomStringConvertible {
        public let steps: [(name: String, error: any Error)]

        public var description: String {
            steps.map { "\($0.name): \($0.error.localizedDescription)" }.joined(separator: "\n")
        }
    }

    public var steps: [Step]

    public init(_ steps: [Step]) {
        self.steps = steps
    }

    /// Runs every step, then throws a `Failure` if any failed.
    public func erase() throws {
        var failures: [(name: String, error: any Error)] = []
        for step in steps {
            do { try step.erase() } catch { failures.append((step.name, error)) }
        }
        if failures.isEmpty == false { throw Failure(steps: failures) }
    }

}

public extension LocalDataReset.Step {
    /// Removes every key the app wrote to `defaults`, one by one so `@AppStorage` views see each
    /// change (removing the whole domain at once doesn't notify them).
    static func defaults(_ defaults: UserDefaults = .standard) -> Self {
        Self("defaults") {
            for key in defaults.dictionaryRepresentation().keys {
                defaults.removeObject(forKey: key)
            }
        }
    }

    /// Removes every item in a `SecureStore`, such as the app's Keychain items.
    static func secrets(in store: any SecureStore) -> Self {
        Self("secrets") { try store.removeAll() }
    }
}
