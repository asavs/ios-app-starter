import SwiftUI
import Testing
@testable import Theme

struct ThemeTests {
    @Test func standardThemeIsTheDefaultInitializer() {
        #expect(AppTheme() == .standard)
    }

    @Test func environmentDefaultsToStandardTheme() {
        #expect(EnvironmentValues().appTheme == .standard)
    }

    @Test func customizedThemeDiffersFromStandard() {
        var theme = AppTheme.standard
        theme.colors.accent = .purple
        #expect(theme != .standard)
        #expect(theme.spacing == AppTheme.standard.spacing)
    }

    @Test func spacingScaleAscends() {
        let scale = ThemeSpacing().ordered
        #expect(scale == scale.sorted())
        #expect(Set(scale).count == scale.count)
        #expect(scale.allSatisfy { $0 > 0 })
    }

    @Test func radiiScaleAscends() {
        let scale = ThemeRadii().ordered
        #expect(scale == scale.sorted())
        #expect(Set(scale).count == scale.count)
    }

    @Test func appearanceMapsToColorScheme() {
        #expect(AppearancePreference.system.colorScheme == nil)
        #expect(AppearancePreference.light.colorScheme == .light)
        #expect(AppearancePreference.dark.colorScheme == .dark)
    }

    @Test func appearanceStorageKeysAreStable() throws {
        #expect(AppearancePreference.allCases.map(\.rawValue) == ["system", "light", "dark"])
        for preference in AppearancePreference.allCases {
            let data = try JSONEncoder().encode(preference)
            #expect(try JSONDecoder().decode(AppearancePreference.self, from: data) == preference)
            #expect(preference.id == preference.rawValue)
            #expect(!preference.title.isEmpty)
        }
    }

    @Test @MainActor func sharedElementsConstructWithPublicInitializers() {
        _ = ThemedCard { Text("Content") }
        _ = EmptyStateView(systemImage: "tray", title: "Empty", message: "Nothing here")
        _ = EmptyStateView(systemImage: "tray", title: "Empty", message: "Nothing here",
                           actionTitle: "Add") {}
        _ = Button("Continue") {}.buttonStyle(.primary)
        _ = Button("Not now") {}.buttonStyle(.secondary)
    }
}
