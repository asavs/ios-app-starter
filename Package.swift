// swift-tools-version: 6.0
// Module library manifest. Every module is one product of this single root package so that apps
// can depend on a tagged version of this repository by URL; Swift Package Manager resolves git
// dependencies only from a repository's root manifest and rejects nested path packages behind a
// tag. The template app depends on this package by path (see project.yml). docs/modules.md has
// the layout, enablement, test and tag procedure; scripts/check-modules.py enforces the layout.
import PackageDescription

let package = Package(
    name: "StarterModules",
    defaultLocalization: "en", // Module text is looked up in each module's Resources/Localizable.xcstrings.
    platforms: [
        .iOS(.v17), // Keep at or below options.deploymentTarget.iOS in project.yml.
        .macOS(.v14), // Host-side `swift test` for host-portable modules only; the simulator lane is the supported check.
    ],
    products: [
        .library(name: "TemplateVersion", targets: ["TemplateVersion"]),
        .library(name: "Theme", targets: ["Theme"]),
        .library(name: "Onboarding", targets: ["Onboarding"]),
        .library(name: "Settings", targets: ["Settings"]),
        .library(name: "TabShell", targets: ["TabShell"]),
        .library(name: "SessionTimer", targets: ["SessionTimer"]),
        .library(name: "TimerRing", targets: ["TimerRing"]),
        .library(name: "Cues", targets: ["Cues"]),
        .library(name: "DurationPicker", targets: ["DurationPicker"]),
    ],
    targets: [
        .target(name: "TemplateVersion", path: "Modules/TemplateVersion/Sources"),
        .testTarget(name: "TemplateVersionTests", dependencies: ["TemplateVersion"], path: "Modules/TemplateVersion/Tests"),
        .target(name: "Theme", path: "Modules/Theme/Sources",
                resources: [.process("Resources")]),
        .testTarget(name: "ThemeTests", dependencies: ["Theme"], path: "Modules/Theme/Tests"),
        .target(name: "Onboarding", dependencies: ["Theme"], path: "Modules/Onboarding/Sources",
                resources: [.process("Resources")]),
        .testTarget(name: "OnboardingTests", dependencies: ["Onboarding"], path: "Modules/Onboarding/Tests"),
        .target(name: "Settings", dependencies: ["Theme"], path: "Modules/Settings/Sources",
                resources: [.process("Resources")]),
        .testTarget(name: "SettingsTests", dependencies: ["Settings"], path: "Modules/Settings/Tests"),
        .target(name: "TabShell", dependencies: ["Theme"], path: "Modules/TabShell/Sources"),
        .testTarget(name: "TabShellTests", dependencies: ["TabShell"], path: "Modules/TabShell/Tests"),
        .target(name: "SessionTimer", path: "Modules/SessionTimer/Sources"),
        .testTarget(name: "SessionTimerTests", dependencies: ["SessionTimer"], path: "Modules/SessionTimer/Tests"),
        .target(name: "TimerRing", dependencies: ["Theme"], path: "Modules/TimerRing/Sources",
                resources: [.process("Resources")]),
        .testTarget(name: "TimerRingTests", dependencies: ["TimerRing"], path: "Modules/TimerRing/Tests"),
        .target(name: "Cues", path: "Modules/Cues/Sources",
                resources: [.process("Resources")]),
        .testTarget(name: "CuesTests", dependencies: ["Cues"], path: "Modules/Cues/Tests"),
        .target(name: "DurationPicker", dependencies: ["Theme"], path: "Modules/DurationPicker/Sources",
                resources: [.process("Resources")]),
        .testTarget(name: "DurationPickerTests", dependencies: ["DurationPicker"], path: "Modules/DurationPicker/Tests"),
    ],
    swiftLanguageModes: [.v6]
)
