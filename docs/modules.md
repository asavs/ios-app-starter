# Modules: the versioned library apps are built from

The template is copied once ("Use this template"), so later improvements reach existing apps only through versioned packages. Modules live in this repository as products of one Swift package; the template app depends on it by path, and an app created from the template depends on a tagged version by URL. Backpropagation is a pull request here, a tag, and a version bump in each app.

## Layout

| Piece | Where | Rule |
| --- | --- | --- |
| Manifest | `Package.swift` at the repository root | One package, `StarterModules`, one library product per module. Swift Package Manager resolves a git dependency only from the root manifest and rejects a tagged package that depends on nested path packages, so modules are products, not nested packages. |
| Module | `Modules/<Name>/Sources/` and `Modules/<Name>/Tests/` | Product `<Name>` built from target `<Name>`; test target `<Name>Tests`. UpperCamelCase names. |
| Enablement | `project.yml`, `targets.StarterApp.dependencies` | One `- package: StarterModules` / `product: <Name>` line per enabled module. Remove the line to disable. No second configuration format. |
| Template sources | `StarterApp/StarterApp/` | Reference modules only inside `#if canImport(<Name>)` so the app builds with any subset enabled. `examples/no-modules.yml` is the overlay with everything disabled. |
| Platform minimum | `platforms:` in `Package.swift` | At or below `options.deploymentTarget.iOS`; `scripts/check-modules.py` compares them. macOS is listed only so host-side `swift test` works for host-portable modules. |
| Version | `Modules/TemplateVersion/Sources/TemplateVersion.swift` | `TemplateVersion.modules` equals the git tag that ships it. The welcome screen shows it. |

`scripts/check-modules.py` validates all of this from `swift package dump-package` and the generated project, and writes `modules.json` (modules, enabled, disabled, platforms) that CI uploads with the test results. The `iOS` workflow runs it on every lane.

## Available modules

| Module | Purpose | Use |
| --- | --- | --- |
| `TemplateVersion` | The library version an app was built against; equals the git tag. | `TemplateVersion.modules`; the welcome screen shows it. |
| `Theme` | Design tokens and shared UX elements, system-following by default. | Read `@Environment(\.appTheme)`; customize once at the root with `.appTheme(_:)`. |
| `Onboarding` | First-launch flow of typed steps (welcome sheet, choice, tour card, permission primer, custom), remembered per version, and TipKit contextual tips that wait for it. Requires `Theme`. | `ContentView().onboardingGate(steps:version:)`; steps are `OnboardingStep` values. |
| `Settings` | Settings screen, stored appearance choice, Keychain-backed secrets. Requires `Theme`. | `SettingsView { }` behind a navigation link; `.storedAppearance()` at the root; `KeychainStore` / `SecureStore`. |

### Theme

`AppTheme` carries semantic colors (`accent`, `onAccent`, `background`, `surface`, `textPrimary`, `textSecondary`, `success`, `warning`, `danger`), a spacing scale (4/8/16/24/32), corner radii (8/12/20) and text roles (`title`, `headline`, `body`, `caption`). `AppTheme.standard` uses dynamic system colors, the asset-catalog accent and Dynamic Type styles, so it adapts to dark mode and text size without configuration. Elements: `PrimaryButtonStyle` and `SecondaryButtonStyle` (`.buttonStyle(.primary)` / `.secondary`, full width, disabled and pressed states), `ThemedCard { }` (grouped content on `surface`), and `EmptyStateView(systemImage:title:message:actionTitle:action:)`. `AppearancePreference` (`system`/`light`/`dark`, stable raw values for storage) maps to `preferredColorScheme`; the Settings module is meant to persist it.

```swift
@main struct MyApp: App {
    var theme: AppTheme {
        var theme = AppTheme.standard
        theme.colors.accent = Color("Brand")  // asset catalog color
        return theme
    }
    var body: some Scene {
        WindowGroup { ContentView().appTheme(theme) }
    }
}
```

The template's welcome screen puts its build details on a `ThemedCard` under `#if canImport(Theme)` (identifier `welcome.card`); the UI test `testThemeRendersInLightAndDark` checks the card and the primary button in both appearances, forcing dark through the Settings module's `-settings.appearance dark` and asserting the screenshot's background luminance. The module's tests are host-portable (`swift test`) because the tokens and the appearance mapping hold no UIKit; the views compile for macOS too.

### Onboarding

The module follows Apple's onboarding guidance (fast, optional, skippable, never shown again, sign-in and permissions deferred) and ships every well-founded piece as an opt-in step, so an app built from the template keeps the steps it needs and deletes the rest. `OnboardingView(steps:onFinish:)` is a swipeable `TabView` over an ordered `[OnboardingStep]` with a Skip button, a single Continue button and a final call to action (`Get started`); the labels are parameters, `skipTitle: nil` removes Skip everywhere, and a step can set its own `continueTitle`. The Continue button is Liquid Glass (`.glassProminent`) on iOS 26 and the theme's primary style before that. Step kinds:

- `.welcome(WelcomeContent)`: the Stocks/Journal-style sheet, an icon (`.system` symbol or `.asset` image), a large title, an optional line and `WelcomeFeature` rows (symbol, title, detail), laid out by `WelcomeStepView`.
- `.page(OnboardingPage)`: the classic tour card (symbol, title, message) laid out by `OnboardingPageView`. `OnboardingStep.pages(_:)` wraps an array, and the `pages:` initializers of the view and the gate still work.
- `.choice(OnboardingChoice)`: one question with fixed answers, `.single` (radio) or `.multiple` (checkboxes), laid out by `ChoiceStepView`. Ask only what changes the product. `onAnswer` receives the answer, as option identifiers in option order (an option's identifier defaults to its title), every time it changes, so the host has it whether the user continues, swipes on or skips. `requiresAnswer: true` disables Continue and stops swiping at the step until something is picked; `initialSelection` preselects.
- `.permission(PermissionPrimer)`: the HIG pre-permission screen. It has exactly one button, labelled Continue (never Allow) and no Cancel, so Skip is hidden on it by default (`allowsSkip: false`); tapping Continue runs the primer's `PermissionRequesting` requester and moves on whatever the `PermissionOutcome`. `NotificationPermission` is the shipped requester; add your own for location, camera and the like. `PermissionOverride.resolve(real:)` swaps in a `FakePermission` when the launch argument `-onboarding.permissions granted` (or `denied`, `unavailable`) is present, which is how UI tests on the simulator avoid the system alert.
- `.custom(id:content:)`: any SwiftUI view, with the flow's Skip and Continue around it. The sign-in module plugs in here; onboarding itself knows nothing about accounts.

`OnboardingPager` holds the position rules (advance, clamp, finish) as a plain value with its own tests; `OnboardingStep.showsSkip(isLast:)`, `OnboardingView.buttonTitle(for:isLast:continueTitle:finishTitle:)`, `OnboardingChoice.selection(_:tapping:)` and `OnboardingView.reachableIndex(_:in:answers:)` hold the per-step rules the same way.

`.onboardingGate(steps:version:record:)` shows the flow in place of its content until the user finishes it once. `OnboardingRecord` stores the completed version in `UserDefaults` under `onboarding.completedVersion`; raise `version` when the flow changes enough to show again (the template went from 1 to 2 when it moved from three cards to the typed steps), and call `reset()` from a settings screen to show it on the next launch. Nothing here is secret, so `UserDefaults` is the right store; Keychain values are the Settings module's job. Accessibility identifiers for UI tests: `onboarding.next`, `onboarding.skip`, `onboarding.step.<id>`, `onboarding.page.<id>`, `onboarding.feature.<id>`, `onboarding.choice.<step id>.<option id>`, `onboarding.permission.<id>.footnote`.

**Contextual tips.** The module also wraps TipKit for the tips that follow onboarding. Call `ContextualTips.configure()` once in the `App` initializer. `ContextualTip(id:title:message:systemImage:maxDisplayCount:)` describes a tip as values; every one waits for `ContextualTips.isEligible`, which the onboarding gate turns off while its flow is on screen, so no tip lands on top of onboarding. Show one with `.contextualTip(tip)` (a popover) or `ContextualTipView(tip)` (inline); show several one at a time with `@State var tips = ContextualTipSequence([...])` and `.contextualTip("id", in: tips)` or `ContextualTipView("id", in: tips)`. The sequence is a `TipGroup(.ordered)` on iOS 18; iOS 17 has no `TipGroup`, so there only the first tip shows. Call `tips.invalidate("id")` when the user does what a tip suggests. TipKit resets its datastore only before configuring, so `ContextualTips.resetOnNextLaunch()` (the template's Settings row "Show tips again on next launch") takes effect at the next launch. Launch arguments for tests: `-tips.reset YES` forgets every tip's history, `-tips.testing hideAll` keeps tips off screens a test inspects, `-tips.testing showAll` ignores the rules. A popover anchored to a toolbar button did not appear on iOS 26.5, so tips about toolbar items are inline.

```swift
@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().onboardingGate(steps: [
                .welcome(WelcomeContent(icon: .asset("AppIconPreview"), title: "Welcome to Notes", features: [
                    WelcomeFeature(systemImage: "square.and.pencil", title: "Write anywhere", detail: "Notes sync to every device."),
                    WelcomeFeature(systemImage: "lock", title: "Private by default", detail: "Nothing leaves the device unless you share it."),
                ])),
                .permission(PermissionPrimer(id: "notifications", systemImage: "bell.badge", title: "Reminders",
                                             message: "Get a nudge when a note is due.",
                                             requester: PermissionOverride.resolve(real: NotificationPermission()))),
            ], version: 1)
        }
    }
}
```

The welcome screen's "Take the tour" button (`onboarding.replay`, the theme's primary style) replays the flow in a sheet without touching the record. The template app gates `ContentView` behind `OnboardingStep.template(onChoice:)` at version 3 (welcome sheet, a multiple-choice "What will you build?" whose answer the welcome screen shows as "Building: ...", one tour card, notifications primer) under `#if canImport(Onboarding)`; `OnboardingStep.templateDefaults` is the same flow with no one listening to the answer. After onboarding the welcome screen shows two tips in order: Settings, inline above the greeting, then "See the tour again" as a popover on the replay button. UI tests force the flow with `-onboarding.completedVersion 0` (`UserDefaults` reads arguments ahead of stored values) and skip it with `-onboarding.completedVersion 1`, and pass `-onboarding.permissions granted` so the primer never shows a system alert: `testOnboardingSteps` walks the four steps with a screenshot each, picks and clears answers on the choice step and checks the answer on the welcome screen, asserts Skip disappears on the primer, then checks the two tips appear one after the other (`-tips.reset YES`), and the welcome-screen smoke test still taps through whatever flow is configured. The page style exists on iOS only; under `#if os(iOS)` the view uses it, elsewhere a plain step switch, so `swift test` still runs host-side.

The research behind the design, and behind the planned conversion steps, is in [research/onboarding.md](research/onboarding.md): Apple's guidance, the tutorial studies, first-launch patterns of well-regarded apps, and a strength-graded review of what converts to trials and purchases, with every source linked. Planned follow-ups: commitment and plan-summary steps, a host-supplied paywall step, a social-proof slot, an event hook with a holdout flag, and the sign-in module.

### Settings

`SettingsView(version:extra:)` is a `Form` with an Appearance section (a segmented `AppearancePreference` picker), the app's own sections from the `extra` builder, and an About section showing `AppInfo.version()` (`CFBundleShortVersionString (CFBundleVersion)`, e.g. `1.0 (1)`). Push it from a navigation link; it sets its own title. The picker binds to `@AppStorage(AppSettings.appearanceKey)` (`settings.appearance`), and `.storedAppearance()` on the root view applies the same key as `preferredColorScheme`, so a tap in Settings restyles the app at once. `AppSettings` reads and writes the same defaults from non-view code (`appearance`, `reset()`); it holds nothing secret.

Secrets go through the `SecureStore` protocol (`data(for:)`, `set(_:for:)`, `remove`, `removeAll`, `keys()`, plus `string(for:)`/`set(String, for:)` helpers and `contains`). `KeychainStore` is the implementation: generic-password items scoped by `service` (the bundle identifier by default) and keyed by account, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` unless `.whenUnlocked` is requested, no entitlement required for an app's own items, and `SecureStoreError.keychain(status:operation:)` for a failing Security call. `InMemorySecureStore` is the stand-in for tests and previews. `SecureSettingRow("API key", key: "api.key")` is the matching form row: it never shows the stored value, reports "Stored securely on this device." or "Not set.", replaces on Save and forgets on Clear. Accessibility identifiers for UI tests: `settings.appearance`, `settings.version`, `settings.secure.<key>.field` / `.save` / `.clear` / `.status`.

```swift
@main struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView().storedAppearance() }
    }
}

NavigationStack {
    SettingsView {
        Section("Account") { SecureSettingRow("API key", key: "api.key") }
    }
}
```

The template's welcome screen gains a gear button (`settings.open`) under `#if canImport(Settings)` that pushes `SettingsView` with an example secret row and, under `#if canImport(Onboarding)`, a "Show the welcome tour on next launch" button calling `OnboardingRecord().reset()`. The root applies `.storedAppearance()`.

**Keychain and signing in tests.** The simulator Keychain answers `errSecMissingEntitlement` (-34018) to a process without an `application-identifier` entitlement. An app built with `CODE_SIGNING_ALLOWED=NO` has none, so `scripts/test-ios.sh` signs the app ad hoc (`CODE_SIGN_IDENTITY=-`, no certificate or team needed) with `scripts/simulator-tests.entitlements`, which declares only that identifier; the UI test `testSettingsScreen` then stores and clears a secret in the real simulator Keychain. Xcode's package test host has no identifier either, so the module's three Keychain tests are `.enabled(if:)` a probe write succeeds and are reported as skipped on the package lane with that reason; the in-memory tests and the preference tests run everywhere, and the real Keychain path is the app UI test's job. Release and device builds are untouched: they get the identifier from the provisioning profile.

## Add a module

1. Create `Modules/<Name>/Sources/<Name>.swift` and `Modules/<Name>/Tests/<Name>Tests.swift` (Swift Testing).
2. Add the product and both targets to `Package.swift`, with explicit `path:` values as the existing entries show.
3. Enable it in `project.yml` under `targets.StarterApp.dependencies`, then `bash scripts/generate-project.sh` and commit the regenerated project.
4. Use it in template sources only under `#if canImport(<Name>)`.
5. Run `python3 scripts/check-modules.py`, `bash scripts/test-module.sh <Name>` (simulator) and `bash scripts/test-ios.sh` (every UI test in `StarterAppUITests`; a module that adds something visible adds a UI test of its main path in the same pull request). Gate the test with `requireModuleUI("<Name>", appeared:_:)`: it skips when the module is disabled and fails when `test-ios.sh` reports the module enabled (`TEST_RUNNER_IOS_ENABLED_MODULES`, read from the generated project) but its UI did not appear, so a stale launch argument cannot hide behind a skip. `swift test` from the repository root is a fast host-side check when the module compiles on macOS.
6. Open the pull request; the required iOS lane checks the layout and builds the app with the module.

## Test a module

```bash
bash scripts/test-module.sh TemplateVersion            # one module's tests on the iOS simulator
bash scripts/test-ios.sh                               # the app: every UI test except the performance and launch tests
IOS_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 17,OS=26.5' bash scripts/test-module.sh TemplateVersion
swift test                                             # host-side, all host-portable modules
```

Xcode derives schemes from the manifest: one scheme per product plus `StarterModules-Package` (with a single product, just `StarterModules`). Only the package-wide scheme has a test action, so the script runs it with `-only-testing:<Name>Tests` and writes the same `summary.md`, `results.json` and log layout as `test-ios.sh`. The required iOS workflow discovers each module under `Modules/` and runs one simulator test lane per module. It also generates the `examples/no-modules.yml` app, verifies that it enables no module products, and builds it for the iOS Simulator.

The app, module and compatibility lanes cache Xcode's cloned Swift package sources in `build/swiftpm-cache/`. Keys include the Xcode version and hashes of package manifests, resolved pins and XcodeGen specs; a cache miss or stale restored entry still runs normal package resolution. Compiled DerivedData is never cached. The current root package has no remote dependencies, so this cache will save downloads only after one is added.

## Release a version

Tags on this repository are module library versions, never app builds. Semantic versions without a `v` prefix, as Swift Package Manager expects.

1. In a pull request, set `TemplateVersion.modules` to the new version and merge.
2. From a clean `main` checkout at the merged commit: `python3 scripts/tag-modules.py 0.2.0`, then the printed `git push origin 0.2.0` (or add `--push`). The script refuses a version that differs from the constant, a dirty tree, another branch, a stale `main`, or an existing tag.
3. Bump `from:` in each app that should receive the change.

## Use the library from an app

An app created from this template starts with the same `Package.swift`, `Modules/` and path dependency. Within one release it should switch to the tagged library (the rule from the master plan: an app may not carry a copy of module code for more than one release):

```yaml
packages:
  StarterModules:
    url: https://github.com/asavs/ios-app-starter
    from: "0.1.0"
targets:
  StarterApp:
    dependencies:
      - package: StarterModules
        product: TemplateVersion
```

Then delete `Package.swift` and `Modules/` from the app, or keep them under a different package name for app-local modules. Xcode writes `StarterApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` for a URL dependency; commit it. To improve a module from inside an app, point the app at a local clone (`path: ../ios-app-starter`) while developing, open the pull request here, tag, and switch back to `url:` with the new version.

The example above uses only TemplateVersion: the initial `0.1.0` tag predates Theme, Onboarding and Settings. An app enabling those products must select a release that includes them and keep their product dependencies in the manifest. Inspect `Package.swift` at the chosen tag before changing from `path:` to `url:`; the current contents of `main` and the displayed version constant do not establish what an older tag ships. Keep the copied local library until a suitable release exists, within the one-release limit above; never move an existing tag to add products.

## XcodeGen include note

`packages.<name>.path` in the top-level spec is written verbatim, relative to the generated project directory (`StarterApp/`), so the template uses `path: ..`. When a spec includes `project.yml`, XcodeGen rebases that value relative to the including file, which lands one directory too high. Every overlay therefore repeats `packages: StarterModules: path: ..` (see `examples/pocket-notes.yml`), the configuration probes pass an absolute path, and `check-modules.py` fails with a named fix when a generated project's package reference does not resolve to this repository.
