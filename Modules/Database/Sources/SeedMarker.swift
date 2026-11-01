import Foundation
import SwiftData

/// A record that `Database.seed(_:in:insert:)` saves with the seeded data, so seeding runs once per
/// key even when every seeded record is later deleted. Include it in the app's versioned schema.
@Model
public final class SeedMarker {
    public var key: String
    public var date: Date

    public init(key: String, date: Date = .now) {
        self.key = key
        self.date = date
    }
}
