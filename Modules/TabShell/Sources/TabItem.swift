import Foundation

/// A host-owned destination. Use a string-backed enum for `ID`; never use translated titles as IDs.
///
/// Recreate the value when a badge count changes. Its stable ID keeps the destination's identity.
public struct TabItem<ID: Hashable & RawRepresentable>: Identifiable where ID.RawValue == String {
    public let id: ID
    public let title: LocalizedStringResource
    public let systemImage: String
    /// Zero (including a negative input) hides the native count badge.
    public let badgeCount: Int

    /// The native tab button's identifier, independent of its translated label.
    public var accessibilityIdentifier: String { "tabs.\(id.rawValue)" }

    public init(id: ID, title: LocalizedStringResource, systemImage: String, badgeCount: Int = 0) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.badgeCount = max(0, badgeCount)
    }
}
