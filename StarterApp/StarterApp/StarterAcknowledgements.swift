import Foundation
#if canImport(Settings)
import Settings

extension Acknowledgement {
    /// The template credits the starter it was built from; an app adds a row per dependency it adopts.
    static let starter: [Acknowledgement] = [
        Acknowledgement(name: "iOS App Starter", author: "Asa Schaeffer", license: "MIT License",
                        url: URL(string: "https://github.com/asavs/ios-app-starter")),
    ]
}
#endif
