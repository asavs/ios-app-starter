import SwiftUI

/// A host-provided view for an `OnboardingStep.custom` step, built on the main actor when shown.
public struct CustomStepContent: Sendable {
    private let make: @MainActor @Sendable () -> AnyView

    public init(@ViewBuilder _ content: @escaping @MainActor @Sendable () -> some View) {
        make = { AnyView(content()) }
    }

    @MainActor public func view() -> AnyView { make() }
}
