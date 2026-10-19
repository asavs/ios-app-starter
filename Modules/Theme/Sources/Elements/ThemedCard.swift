import SwiftUI

/// Grouped content on a `surface`-colored, rounded background with the theme's medium padding.
public struct ThemedCard<Content: View>: View {
    @Environment(\.appTheme) private var theme
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(theme.spacing.medium)
            .background(theme.colors.surface, in: .rect(cornerRadius: theme.radii.large))
    }
}

#Preview("Card") {
    ThemedCard {
        VStack(alignment: .leading, spacing: 4) {
            Text("Title").font(.headline)
            Text("Supporting detail.").foregroundStyle(.secondary)
        }
    }
    .padding()
}
