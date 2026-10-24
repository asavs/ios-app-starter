import SwiftUI
import Theme

/// The pre-permission step: the primer as a tour card with its footnote underneath. The single
/// Continue button belongs to the flow, which runs the primer's requester when it is tapped.
public struct PermissionStepView: View {
    private let primer: PermissionPrimer

    public init(_ primer: PermissionPrimer) {
        self.primer = primer
    }

    public var body: some View {
        OnboardingPageView(primer.page, footnote: primer.footnote.map {
            .init(text: $0, identifier: "onboarding.permission.\(primer.id).footnote")
        })
    }
}

#Preview("Permission") {
    PermissionStepView(PermissionPrimer(id: "notifications", systemImage: "bell.badge", title: "Stay in the loop",
                                        message: "Why notifications help.", requester: FakePermission()))
}
