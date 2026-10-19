// swift-tools-version: 6.0
// Module library manifest. Every module is one product of this single root package so that apps
// can depend on a tagged version of this repository by URL; Swift Package Manager resolves git
// dependencies only from a repository's root manifest and rejects nested path packages behind a
// tag. The template app depends on this package by path (see project.yml). docs/modules.md has
// the layout, enablement, test and tag procedure; scripts/check-modules.py enforces the layout.
import PackageDescription

let package = Package(
    name: "StarterModules",
    platforms: [
        .iOS(.v17), // Keep at or below options.deploymentTarget.iOS in project.yml.
        .macOS(.v14), // Host-side `swift test` for host-portable modules only; the simulator lane is the supported check.
    ],
    products: [
        .library(name: "TemplateVersion", targets: ["TemplateVersion"]),
        .library(name: "Theme", targets: ["Theme"]),
    ],
    targets: [
        .target(name: "TemplateVersion", path: "Modules/TemplateVersion/Sources"),
        .testTarget(name: "TemplateVersionTests", dependencies: ["TemplateVersion"], path: "Modules/TemplateVersion/Tests"),
        .target(name: "Theme", path: "Modules/Theme/Sources"),
        .testTarget(name: "ThemeTests", dependencies: ["Theme"], path: "Modules/Theme/Tests"),
    ],
    swiftLanguageModes: [.v6]
)
