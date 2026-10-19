import SwiftUI

/// The design tokens an app's screens read from the SwiftUI environment.
///
/// `AppTheme.standard` follows the system: dynamic system colors, the app's accent color and the
/// Dynamic Type text styles, so a themed screen adapts to light/dark mode and accessibility sizes
/// without extra work. An app customizes it once at the root:
///
/// ```swift
/// var theme = AppTheme.standard
/// theme.colors.accent = Color("Brand")
/// ContentView().appTheme(theme)
/// ```
///
/// Screens and the shared elements in this module read it with `@Environment(\.appTheme)`.
public struct AppTheme: Sendable, Equatable {
    public var colors: ThemeColors
    public var spacing: ThemeSpacing
    public var radii: ThemeRadii
    public var typography: ThemeTypography

    public init(colors: ThemeColors = ThemeColors(), spacing: ThemeSpacing = ThemeSpacing(),
                radii: ThemeRadii = ThemeRadii(), typography: ThemeTypography = ThemeTypography()) {
        self.colors = colors
        self.spacing = spacing
        self.radii = radii
        self.typography = typography
    }

    /// System-following defaults; the environment value when no theme is injected.
    public static let standard = AppTheme()
}

/// Semantic color roles. Defaults are dynamic system colors, so they adapt to the color scheme.
public struct ThemeColors: Sendable, Equatable {
    /// Interactive emphasis: primary buttons, selected states. Defaults to the asset catalog accent.
    public var accent: Color
    /// Text and symbols drawn on `accent`.
    public var onAccent: Color
    /// Screen background.
    public var background: Color
    /// Grouped content on top of `background`, such as cards.
    public var surface: Color
    public var textPrimary: Color
    public var textSecondary: Color
    public var success: Color
    public var warning: Color
    public var danger: Color

    public init(accent: Color = .accentColor, onAccent: Color = .white,
                background: Color = ThemeColors.systemBackground, surface: Color = ThemeColors.systemSurface,
                textPrimary: Color = .primary, textSecondary: Color = .secondary,
                success: Color = .green, warning: Color = .orange, danger: Color = .red) {
        self.accent = accent
        self.onAccent = onAccent
        self.background = background
        self.surface = surface
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.success = success
        self.warning = warning
        self.danger = danger
    }

    // The package also compiles for macOS so `swift test` runs host-side; pick each platform's
    // dynamic background colors.
#if canImport(UIKit) && !os(watchOS)
    public static let systemBackground = Color(uiColor: .systemBackground)
    public static let systemSurface = Color(uiColor: .secondarySystemBackground)
#elseif canImport(AppKit)
    public static let systemBackground = Color(nsColor: .windowBackgroundColor)
    public static let systemSurface = Color(nsColor: .controlBackgroundColor)
#else
    public static let systemBackground = Color.clear
    public static let systemSurface = Color.gray.opacity(0.15)
#endif
}

/// Spacing scale in points, from tight (`extraSmall`) to section gaps (`extraLarge`).
public struct ThemeSpacing: Sendable, Equatable {
    public var extraSmall: CGFloat
    public var small: CGFloat
    public var medium: CGFloat
    public var large: CGFloat
    public var extraLarge: CGFloat

    public init(extraSmall: CGFloat = 4, small: CGFloat = 8, medium: CGFloat = 16,
                large: CGFloat = 24, extraLarge: CGFloat = 32) {
        self.extraSmall = extraSmall
        self.small = small
        self.medium = medium
        self.large = large
        self.extraLarge = extraLarge
    }

    /// The scale in ascending order, for layouts and tests that iterate it.
    public var ordered: [CGFloat] { [extraSmall, small, medium, large, extraLarge] }
}

/// Corner radius scale in points: `small` for controls, `medium` for buttons, `large` for cards.
public struct ThemeRadii: Sendable, Equatable {
    public var small: CGFloat
    public var medium: CGFloat
    public var large: CGFloat

    public init(small: CGFloat = 8, medium: CGFloat = 12, large: CGFloat = 20) {
        self.small = small
        self.medium = medium
        self.large = large
    }

    public var ordered: [CGFloat] { [small, medium, large] }
}

/// Text roles. Defaults are Dynamic Type styles, so they scale with the user's text size.
public struct ThemeTypography: Sendable, Equatable {
    public var title: Font
    public var headline: Font
    public var body: Font
    public var caption: Font

    public init(title: Font = .title2.weight(.semibold), headline: Font = .headline,
                body: Font = .body, caption: Font = .footnote) {
        self.title = title
        self.headline = headline
        self.body = body
        self.caption = caption
    }
}
