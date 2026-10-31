import SwiftUI

/// A settings row that pushes a screen of its own, the way iOS Settings nests General or Sounds &
/// Haptics. Modules offer their settings both ways, as a `Section` for inline use and as one of
/// these rows holding that section, and the app picks per module so its top level stays short.
///
/// ```swift
/// SettingsLink("Sounds & Haptics", systemImage: "speaker.wave.2") {
///     CueSettingsSection()
/// }
/// ```
///
/// The pushed screen is a `Form` with the content and the title as its navigation title. Pass an
/// `id` for the row's accessibility identifier (`settings.<id>`); the default is the symbol name.
public struct SettingsLink<Content: View>: View {
    private let title: LocalizedStringResource
    private let systemImage: String
    private let id: String
    private let content: Content

    public init(_ title: LocalizedStringResource, systemImage: String, id: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.id = id ?? systemImage
        self.content = content()
    }

    public var body: some View {
        NavigationLink {
            Form { content }
                .navigationTitle(Text(title))
                .inlineNavigationTitle()
        } label: {
            Label { Text(title) } icon: { Image(systemName: systemImage) }
        }
        .accessibilityIdentifier("settings.\(id)")
    }
}

#Preview {
    NavigationStack {
        Form {
            SettingsLink("Sounds & Haptics", systemImage: "speaker.wave.2") {
                Section { Toggle("Sounds", isOn: .constant(true)) }
            }
        }
    }
}
