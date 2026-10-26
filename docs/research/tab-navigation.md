# Native tab navigation

Research and first implementation: 2026-10-25. Minimum iOS remains 17; the repository builds with Xcode 27.0. This is a code template: the app developer chooses tabs, labels, symbols and screens in Swift.

## Design decisions

Use SwiftUI's native `TabView`. Apple's [tab bar guidance](https://developer.apple.com/design/human-interface-guidelines/tab-bars) describes tabs as navigation among top-level sections, with navigation context preserved inside each section. Labels should explain the destination; a symbol alone is insufficient. Keep destinations stable and use badges for information that deserves attention. The template demonstrates its existing welcome and Settings screens, with no invented product destinations or actions disguised as tabs.

Apple's [SwiftUI design session](https://developer.apple.com/videos/play/wwdc2025/323/) explains how native tab bars adopt Liquid Glass, float above iPhone content, and can optionally minimize while scrolling. Use the native surface and scroll-edge treatment. Custom blur layers, capsule backgrounds and manually positioned overlays would interfere with that behavior. The first implementation keeps the bar's default behavior; there is no scrolling product screen here that calls for minimization or a bottom accessory.

Use a separate host-owned `NavigationStack` inside each destination. A shared stack around the entire shell would couple the destinations' navigation. The module supplies navigation between sections; the host supplies each section's routes and path storage. Selection restoration does not promise restoration of nested navigation paths.

Use enum values for selection, stable raw strings for storage, and localized resources for labels. A translation or badge update must not replace a tab's identity. Numeric badges use the system's [badge support](https://developer.apple.com/documentation/swiftui/tabcontent/badge(_:)); counts at or below zero are hidden. The host computes counts from its app data.

Respect native iPad placement. A request for bottom tabs on iPhone does not justify pinning an overlay to the bottom of every iPad window. Sidebar customization, user tab reordering and search roles are outside this first shell.

## API and availability

The module has three public types:

- `TabItem<ID>`: enum ID, localized title, SF Symbol and badge count.
- `TabSelection<ID>`: scene-owned observable selection, known destinations and persistence; `select(rawValue:)` lets a validated host route choose a tab.
- `TabShell<ID, Content>`: native rendering, Theme accent and host-supplied views through a generic builder. No `AnyView` or framework dependency beyond Theme.

Apple's [`Tab` documentation](https://developer.apple.com/documentation/swiftui/tab) provides the labeled value initializer. Its documentation metadata confirms iOS/iPadOS 18 and macOS 15 availability. The [`TabContent` accessibility identifier](https://developer.apple.com/documentation/swiftui/tabcontent/accessibilityidentifier(_:isenabled:)) has the same minimum. The implementation uses these APIs behind that availability check; iOS 17 and macOS 14 use native `tabItem` and tag-based selection. Building with a recent SDK does not remove the need for that fallback.

The selection model is `@MainActor @Observable`. Each scene owns it with `@State`; the shell uses `@Bindable`. Persistent storage holds only the raw ID, under a host-configurable key. Unsupported stored IDs fall back to a known default. Unknown routes and unavailable direct assignments leave selection unchanged. Separate open scenes do not observe each other's navigation changes; a new scene restores the most recently saved tab.

The module accepts a destination ID, not a URL. An app's `onOpenURL` handler must validate its scheme, host, route and authorization before selecting a tab, then perform any navigation inside that tab. This keeps app identity, account policy and universal-link setup out of the shell.

## Skills and source review

The first pass follows the pinned `write-swift`, `swiftui-pro`, `swift-testing-pro`, `apple-design`, `emil-design-eng` and `swiftui-accessibility-auditor` skills. The design skills' web-specific animation examples are not a reason to recreate native SwiftUI controls. The system owns tab feedback and motion here. No custom animation was added.

Source review found no demonstrated accessibility defect in the new shell requiring a custom accessibility patch: labels remain visible, identifiers do not replace spoken labels, selected traits come from the native tab, and there are no custom tap gestures, fixed fonts or forced transparency. That is a source review, not runtime accessibility acceptance.

## Verification boundaries

The first pass was written on Windows with Python 3.13.14 and Git 2.54.0.windows.1. Swift and Xcode are unavailable there. Portable checks do not establish Swift compilation, simulator behavior or the appearance of either presentation branch. The manifest change requires regeneration with the pinned XcodeGen 2.46.0 on a Mac before this feature lands.

For native acceptance, run `bash scripts/generate-project.sh`, commit the regenerated project, run `bash scripts/test-module.sh TabShell` and `bash scripts/test-ios.sh`, and inspect the per-test results and screenshots. The required lane uses iPhone 17 / iOS 27.0; use `IOS_TEST_DESTINATION` only for a runtime actually installed on the machine. The separate compatibility workflow must exercise iOS 17 and 18 before claiming those fallback paths verified. A modern simulator pass cannot establish older-runtime compatibility.

Manual checks on the Mac and phone:

1. Open Welcome, then Settings, then Welcome. Expect the selected tab to match the visible screen, a reachable tab bar, and no duplicate navigation bars. Relaunch from Settings and expect Settings to restore. After adding a host route, also verify its stack survives switching away and back.
2. Inspect light, dark and the largest accessibility text size on iPhone, then portrait, landscape and a resized iPad window. Expect readable content, reachable controls and native safe-area placement. Inspect Liquid Glass on iOS 26 or later and the native earlier appearance on an older runtime separately.
3. With VoiceOver, expect each tab's visible label, selected state and real badge count to be spoken without duplicate labels. With Voice Control's Show Names or Switch Control, expect both destinations to be discoverable and activatable. Inspect the element tree with Accessibility Inspector.
4. Enable Reduce Motion, Reduce Transparency and Increase Contrast separately. Expect legible tabs, usable content under the bar and system-appropriate transitions. Inject a real host badge count in a preview/test fixture; verify zero removes it and updating the badge preserves selection and screen state.

The main regression risks are the existing onboarding/tips and Settings entry paths, tab-button identifier propagation in the iOS 17 fallback, and state retention when host badge descriptors are updated. The same-PR UI test switches the actual destinations and verifies relaunch restoration. The existing Settings and onboarding tests now accept either the tab or the original gear, so disabling the module keeps that coverage.
