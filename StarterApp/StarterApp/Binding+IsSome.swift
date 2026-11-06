import SwiftUI

extension Binding {
    /// An optional's presence as a Boolean binding: setting false clears it, setting true is ignored.
    func isSome<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
        Binding<Bool>(get: { wrappedValue != nil }, set: { if !$0 { wrappedValue = nil } })
    }
}
