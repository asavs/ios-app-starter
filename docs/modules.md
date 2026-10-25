# Choose and update app features

Each feature of the starter is a module you enable in `project.yml`; keep the ones your app needs and remove the rest. The modules are `TemplateVersion`, `Theme`, `Onboarding` and `Settings`. Authentication and persistence modules are planned.

"Use this template" copies the app into your repository once. After that, module improvements reach your app as versioned packages: the modules are products of one Swift package in this repository, which the template app depends on by local path and apps created from it by tagged URL. To share an improvement, open a pull request here, release a tag, then update the version in each app that needs it.

## Layout

| Piece | Where | Rule |
| --- | --- | --- |
| Manifest | `Package.swift` at the repository root | One package, `StarterModules`, with one library product per module. Swift Package Manager resolves a git dependency only from the root manifest and rejects a tagged package that depends on nested path packages, so modules are products, not nested packages. |
| Module | `Modules/<Name>/Sources/` and `Modules/<Name>/Tests/` | Product `<Name>` built from target `<Name>`; test target `<Name>Tests`. UpperCamelCase names. |
| Enablement | `project.yml`, `targets.StarterApp.dependencies` | One `- package: StarterModules` / `product: <Name>` line per enabled module; remove the line to disable it. Nothing else configures modules. |
| Template sources | `StarterApp/StarterApp/` | Reference modules only inside `#if canImport(<Name>)`, so the app builds with any subset. `examples/no-modules.yml` is the overlay with everything disabled. |
| Platform minimum | `platforms:` in `Package.swift` | At or below `options.deploymentTarget.iOS`; `scripts/check-modules.py` compares them. macOS is listed only so host-portable modules run under `swift test`. |
| Version | `Modules/TemplateVersion/Sources/TemplateVersion.swift` | `TemplateVersion.modules` equals the git tag that ships it. The welcome screen shows it. |

`scripts/check-modules.py` checks all of this against `swift package dump-package` and the generated project, and writes `modules.json` (modules, enabled, disabled, platforms), which CI uploads with the test results. The `iOS` workflow runs it on every lane.

## Available modules

| Module | Purpose | Use |
| --- | --- | --- |
| `TemplateVersion` | The library version an app was built against; equals the git tag. | `TemplateVersion.modules`; the welcome screen shows it. |
| `Theme` | Design tokens and shared UX elements, following the system by default. | Read `@Environment(\.appTheme)`; customize once at the root with `.appTheme(_:)`. |
| `Onboarding` | A first-launch flow of typed steps (welcome sheet, choice, tour card, permission primer, custom), remembered per version, and TipKit contextual tips that wait for it. Requires `Theme`. | `ContentView().onboardingGate(steps:version:)`; steps are `OnboardingStep` values. |
| `Settings` | A settings screen, a stored appearance choice and Keychain-backed secrets. Requires `Theme`. | `SettingsView { }` behind a navigation link; `.storedAppearance()` at the root; `KeychainStore` / `SecureStore`. |

### Theme

`AppTheme` carries semantic colors (`accent`, `onAccent`, `background`, `surface`, `textPrimary`, `textSecondary`, `success`, `warning`, `danger`), a spacing scale (4/8/16/24/32), corner radii (8/12/20) and text roles (`title`, `headline`, `body`, `caption`). `AppTheme.standard` uses dynamic system colors, the asset-catalog accent and Dynamic Type styles, so it follows dark mode and text size with no configuration.

The shared elements:

- `PrimaryButtonStyle` and `SecondaryButtonStyle` (`.buttonStyle(.primary)` / `.secondary`): full width, with disabled and pressed states.
- `.prominentButtonStyle()` for a screen's main call to action: Liquid Glass `.glassProminent` on iOS 26 and later, `.primary` before. Give the label `.frame(maxWidth: .infinity)` for full width.
- `ThemedCard { }`: grouped content on `surface`.
- `EmptyStateView(systemImage:title:message:actionTitle:action:)`.

`AppearancePreference` (`system`/`light`/`dark`, with raw values stable for storage) maps to `preferredColorScheme`; the Settings module persists it.

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

In the template, the welcome screen shows its build details on a `ThemedCard` (identifier `welcome.card`) under `#if canImport(Theme)`. The UI test `testThemeRendersInLightAndDark` checks the card and the primary button in both appearances, forcing dark mode with the Settings module's `-settings.appearance dark` and checking the screenshot's background luminance. The tokens and appearance mapping use no UIKit, so the module's tests run on the host (`swift test`) and the views also compile for macOS.

### Onboarding

The module builds a short first-launch flow from the steps your app needs, following Apple's guidance: onboarding is optional and skippable, completion is remembered, and sign-in and permission requests wait.

`OnboardingView(steps:onFinish:)` is a swipeable `TabView` over an ordered `[OnboardingStep]`, with a Skip button, one Continue button and a final call to action (`Get started`). The labels are parameters: `skipTitle: nil` removes Skip everywhere, and a step can set its own `continueTitle`. Continue uses the theme's `.prominentButtonStyle()`. At large Dynamic Type sizes each step scrolls instead of truncating. The step kinds:

- `.welcome(WelcomeContent)`: a Stocks/Journal-style welcome sheet with an icon (`.system` symbol or `.asset` image), a large title, an optional line and `WelcomeFeature` rows (symbol, title, detail), laid out by `WelcomeStepView`.
- `.page(OnboardingPage)`: a tour card (symbol, title, message) laid out by `OnboardingPageView`. `OnboardingStep.pages(_:)` wraps an array, and the `pages:` initializers of the view and the gate still work.
- `.choice(OnboardingChoice)`: one question with fixed answers, laid out by `ChoiceStepView`. `.single` puts a checkmark on the picked answer, as in a Settings list; `.multiple` puts a circle on every row that fills when picked, as in Mail and Photos selection. Ask only what changes the product. `onAnswer` receives the answer every time it changes, as option identifiers in option order, so the host has it whether the user continues, swipes on or skips. Identifiers are required and never shown, so translating a title never changes a stored answer; `titles(for:)` turns an answer back into titles for display. `requiresAnswer: true` disables Continue and swiping at the step until something is picked; `initialSelection` preselects.
- `.permission(PermissionPrimer)`: the HIG pre-permission screen. Its one button is labelled Continue (never Allow), with no Cancel, so Skip is hidden on it by default (`allowsSkip: false`). Continue runs the primer's `PermissionRequesting` requester and moves on whatever the `PermissionOutcome`. `NotificationPermission` ships; add your own requesters for location, camera and the like. `PermissionOverride.resolve(real:)` substitutes a `FakePermission` when the launch argument `-onboarding.permissions granted` (or `denied`, `unavailable`) is present, so simulator UI tests avoid the system alert.
- `.custom(id:content:)`: any SwiftUI view, with the flow's Skip and Continue around it. The sign-in module will plug in here; onboarding itself knows nothing about accounts.

The navigation and per-step rules are plain values and functions with their own tests: `OnboardingPager` (advance, clamp, finish), `OnboardingStep.showsSkip(isLast:)`, `OnboardingView.buttonTitle(for:isLast:continueTitle:finishTitle:)`, `OnboardingChoice.selection(_:tapping:)` and `OnboardingView.reachableIndex(_:in:answers:)`.

`.onboardingGate(steps:version:record:)` shows the flow in place of its content until the user finishes it once. `OnboardingRecord` stores the completed version in `UserDefaults` under `onboarding.completedVersion`, which suits it because nothing here is secret (the Settings module handles Keychain values). Raise `version` when the flow changes enough to show again, and call `reset()` from a settings screen to show it on the next launch. Accessibility identifiers for UI tests: `onboarding.next`, `onboarding.skip`, `onboarding.step.<id>`, `onboarding.page.<id>`, `onboarding.feature.<id>`, `onboarding.choice.<step id>.<option id>`, `onboarding.permission.<id>.footnote`.

The module also wraps TipKit for the contextual tips that follow onboarding:

- Call `ContextualTips.configure()` once in the `App` initializer.
- `ContextualTip(id:title:message:systemImage:maxDisplayCount:)` describes a tip as values. Every tip waits for `ContextualTips.isEligible`, which the onboarding gate turns off while its flow is on screen.
- Show one tip with `.contextualTip(tip)` (a popover) or `ContextualTipView(tip)` (inline). Show several one at a time with `@State var tips = ContextualTipSequence([...])` and `.contextualTip("id", in: tips)` or `ContextualTipView("id", in: tips)`. The sequence is a `TipGroup(.ordered)` on iOS 18; iOS 17 has no `TipGroup`, so only the first tip shows there.
- Call `tips.invalidate("id")` when the user does what a tip suggests.
- TipKit resets its datastore only before configuring, so `ContextualTips.resetOnNextLaunch()` (the template's Settings row "Show tips again on next launch") takes effect at the next launch.
- Launch arguments for tests: `-tips.reset YES` forgets every tip's history, `-tips.testing hideAll` keeps tips off screens a test inspects, `-tips.testing showAll` ignores the display rules.
- A popover anchored to a toolbar button did not appear on iOS 26.5, so make tips about toolbar items inline.

```swift
@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().onboardingGate(steps: [
                .welcome(WelcomeContent(icon: .asset("AppIconPreview"), title: "Welcome to Notes", features: [
                    WelcomeFeature(id: "write", systemImage: "square.and.pencil", title: "Write anywhere", detail: "Notes sync to every device."),
                    WelcomeFeature(id: "private", systemImage: "lock", title: "Private by default", detail: "Nothing leaves the device unless you share it."),
                ])),
                .permission(PermissionPrimer(id: "notifications", systemImage: "bell.badge", title: "Reminders",
                                             message: "Get a nudge when a note is due.",
                                             requester: PermissionOverride.resolve(real: NotificationPermission()))),
            ], version: 1)
        }
    }
}
```

Under `#if canImport(Onboarding)`, the template app gates `ContentView` behind `OnboardingStep.template(onChoice:)` at version 3: a welcome sheet, a multiple-choice "What will you build?" whose answer the welcome screen shows as "Building: ...", one tour card and a notifications primer. `OnboardingStep.templateDefaults` is the same flow without an answer handler. The welcome screen's "Take the tour" button (`onboarding.replay`, primary style) replays the flow in a sheet without touching the record. After onboarding, the welcome screen shows two tips in order: Settings, inline above the greeting, then "See the tour again" as a popover on the replay button.

UI tests force the flow with `-onboarding.completedVersion 0` (`UserDefaults` reads launch arguments ahead of stored values), skip it with `-onboarding.completedVersion 1`, and pass `-onboarding.permissions granted` so the primer never shows a system alert. `testOnboardingSteps` screenshots each of the four steps, picks and clears answers on the choice step, checks the answer on the welcome screen, asserts that Skip disappears on the primer, and checks that the two tips appear in turn (`-tips.reset YES`). The welcome-screen smoke test taps through whatever flow is configured. The page style exists only on iOS, so the view uses it under `#if os(iOS)` and a plain step switch elsewhere, which keeps `swift test` running on the host.

The research behind the design and the planned conversion steps is in [research/onboarding.md](research/onboarding.md): Apple's guidance, tutorial studies, first-launch patterns of well-regarded apps, and a strength-graded review of what converts to trials and purchases, with sources.

### Settings

`SettingsView(version:extra:)` is a `Form` with an Appearance section (a segmented `AppearancePreference` picker), the app's own sections from the `extra` builder, and an About section showing `AppInfo.version()` (`CFBundleShortVersionString (CFBundleVersion)`, e.g. `1.0 (1)`). Push it from a navigation link; it sets its own title. The picker binds to `@AppStorage(AppSettings.appearanceKey)` (`settings.appearance`), and `.storedAppearance()` on the root view applies the same key as `preferredColorScheme`, so a change in Settings restyles the app at once. `AppSettings` reads and writes the same defaults from non-view code (`appearance`, `reset()`); it holds nothing secret.

Secrets go through the `SecureStore` protocol: `data(for:)`, `set(_:for:)`, `remove`, `removeAll`, `keys()`, the helpers `string(for:)`/`set(String, for:)` and `contains`, and `perform { }`, which runs calls off the caller's actor (`try await store.perform { try $0.contains(key) }`). Keychain calls block their thread, so main-actor code such as a view uses `perform`.

- `KeychainStore` is the implementation: generic-password items scoped by `service` (the bundle identifier by default) and keyed by account. Items use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` unless `.whenUnlocked` is requested. An app's own items need no entitlement. A failing Security call throws `SecureStoreError.keychain(status:operation:)`.
- `InMemorySecureStore` stands in for tests and previews.
- `SecureSettingRow("API key", key: "api.key")` is the matching form row. It never shows the stored value: it reports "Checking…" until its first read returns, then "Stored securely on this device." or "Not set.". Save replaces the value, Clear forgets it, and every Keychain call goes through `perform`.

Accessibility identifiers for UI tests: `settings.appearance`, `settings.version`, `settings.secure.<key>.field` / `.save` / `.clear` / `.status`.

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

In the template, under `#if canImport(Settings)`, the welcome screen has a gear button (`settings.open`) that pushes `SettingsView` with an example secret row and, under `#if canImport(Onboarding)`, a "Show the welcome tour on next launch" button that calls `OnboardingRecord().reset()`. The root applies `.storedAppearance()`.

#### Keychain and signing in tests

The simulator Keychain returns `errSecMissingEntitlement` (-34018) to a process without an `application-identifier` entitlement, and an app built with `CODE_SIGNING_ALLOWED=NO` has none. So `scripts/test-ios.sh` signs the app ad hoc (`CODE_SIGN_IDENTITY=-`, no certificate or team needed) with `scripts/simulator-tests.entitlements`, which declares only that identifier, and the UI test `testSettingsScreen` stores and clears a secret in the real simulator Keychain. Xcode's package test host has no identifier either, so the module's three Keychain tests are `.enabled(if:)` a probe write succeeds, and the package lane reports them as skipped with that reason; the in-memory and preference tests run everywhere. Release and device builds are unaffected: they get the identifier from the provisioning profile.

## Localization

Every piece of text a module shows can be translated.

- **Text an app passes in** (onboarding titles and messages, tips, `SecureSettingRow`'s title, `EmptyStateView`) is a `LocalizedStringResource`. A string literal is looked up in the app's own string catalog (`StarterApp/StarterApp/Localizable.xcstrings` in the template), so `title: "Write anywhere"` needs no change; Xcode adds such literals to the catalog when it builds. Wrap text held in a variable: `LocalizedStringResource(stringLiteral: name)` shows it as written, `LocalizedStringResource(String.LocalizationValue(key))` looks it up.
- **Text a module owns** ("Skip", "Continue", "Choose one", "Save", "Appearance", the template's onboarding copy, …) is looked up in that module's `Modules/<Name>/Sources/Resources/Localizable.xcstrings` (`Package.swift` sets `defaultLocalization: "en"`). Module code writes it as a literal directly followed by `bundle: .module`: `Text("Choose one", bundle: .module)`, `String(localized: "Not set.", bundle: .module)` or `LocalizedStringResource("Skip", bundle: .module)`. Public defaults are constants such as `OnboardingView.defaultSkipTitle`, because a public default argument cannot reference the internal `Bundle.module`.
- **Identifiers are never text.** `OnboardingPage`, `WelcomeFeature` and `OnboardingChoice.Option` take a required `id`, so translations never change identity, accessibility identifiers or stored answers.
- `python3 scripts/check-module-strings.py` fails when a module looks up a key its catalog lacks, or when the catalog holds a key no source uses. `--update` rewrites the catalogs and adds new keys with their English value (an entry without one compiles to nothing). The required iOS lane runs the check. To translate, open a catalog in Xcode and add a language, or add `localizations.<language>` entries by hand.

## Add a module

1. Create `Modules/<Name>/Sources/<Name>.swift` and `Modules/<Name>/Tests/<Name>Tests.swift` (Swift Testing).
2. Add the product and both targets to `Package.swift`, with explicit `path:` values like the existing entries.
3. Enable it in `project.yml` under `targets.StarterApp.dependencies`, run `bash scripts/generate-project.sh`, and commit the regenerated project.
4. Use it in template sources only under `#if canImport(<Name>)`. Handle text as described under Localization: parameters as `LocalizedStringResource`, module text in `Sources/Resources/Localizable.xcstrings` (declare `resources: [.process("Resources")]`), then run `python3 scripts/check-module-strings.py --update`.
5. Run `python3 scripts/check-modules.py`, `bash scripts/test-module.sh <Name>` (simulator) and `bash scripts/test-ios.sh` (every UI test in `StarterAppUITests`). If the module adds something visible, add a UI test of its main path in the same pull request, gated with `requireModuleUI("<Name>", appeared:_:)`. The gate skips when the module is disabled and fails when `test-ios.sh` reports the module enabled (`TEST_RUNNER_IOS_ENABLED_MODULES`, read from the generated project) but its UI did not appear, so a stale launch argument cannot hide behind a skip. If the module compiles on macOS, `swift test` from the repository root is a fast host-side check.
6. Open the pull request. The required iOS lane checks the layout and builds the app with the module.

## Test a module

```bash
bash scripts/test-module.sh TemplateVersion            # one module's tests on the iOS simulator
bash scripts/test-ios.sh                               # the app: every UI test except the performance and launch tests
IOS_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 17,OS=26.5' bash scripts/test-module.sh TemplateVersion
swift test                                             # host-side, all host-portable modules
```

Xcode derives one scheme per product plus `StarterModules-Package` (just `StarterModules` when there is a single product), and only the package-wide scheme has a test action. `test-module.sh` therefore runs that scheme with `-only-testing:<Name>Tests` and writes the same `summary.md`, `results.json` and log layout as `test-ios.sh`. The required iOS workflow runs one simulator test lane per module it finds under `Modules/`. It also generates the `examples/no-modules.yml` app, verifies that it enables no module products, and builds it for the iOS Simulator.

The app, module and compatibility lanes cache Xcode's cloned Swift package sources in `build/swiftpm-cache/`, keyed on the Xcode version and hashes of the package manifests, resolved pins and XcodeGen specs. A miss or stale entry falls back to normal package resolution. DerivedData is never cached. The cache saves downloads only once the root package has a remote dependency.

## Release a version

Tags on this repository version the module library; app builds are numbered separately. Use semantic versions without a `v` prefix, as Swift Package Manager expects.

1. In a pull request, set `TemplateVersion.modules` and the welcome-screen UI test's expected version to the new version. Merge once the required app, module and no-modules checks pass.
2. From a clean `main` checkout at the merged commit, run `python3 scripts/tag-modules.py 0.3.1`, then the printed `git push origin 0.3.1` (or add `--push`). The script refuses a version that differs from the constant, a dirty tree, another branch, a stale `main`, or an existing tag.
3. Pushing the tag starts **Module release check** ([workflow](../.github/workflows/module-release-check.yml)). It creates a separate consumer that depends on the GitHub URL at the exact version and imports all four round-one products, builds it for the iOS simulator with Xcode 27.0, and checks the resolved version against the library's displayed version. Wait with `gh run watch <id> --exit-status`, then download `module-release-check` and inspect `release-check.json` (the version, commit and products actually built) and `Package.resolved`. A failed check means the release is not verified: fix it in a new version and do not move the tag. To recheck a published version: `gh workflow run module-release-check.yml --ref main --field version=0.3.1`.
4. Bump `from:` in each app that should receive the verified change. A passing check shows the package can be consumed and compiled, not app UI behavior or runtime coverage on the minimum OS.

## Use the library from an app

An app created from this template starts with the same `Package.swift`, `Modules/` and path dependency. Switch it to the tagged library within one release; the master plan does not allow an app to carry a copy of module code for longer:

```yaml
packages:
  StarterModules:
    url: https://github.com/asavs/ios-app-starter
    from: "0.3.1"
targets:
  StarterApp:
    dependencies:
      - package: StarterModules
        product: TemplateVersion
      - package: StarterModules
        product: Theme
      - package: StarterModules
        product: Onboarding
      - package: StarterModules
        product: Settings
```

Then delete `Package.swift` and `Modules/` from the app, or keep them under a different package name for app-local modules. Xcode writes `StarterApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` for a URL dependency; commit it. To improve a module from inside an app, point the app at a local clone (`path: ../ios-app-starter`) while developing, open the pull request here, tag, and switch back to `url:` with the new version.

Keep only the products the app needs; Onboarding and Settings require Theme. Before switching from `path:` to `url:`, inspect `Package.swift` at the chosen tag, because `main` and the displayed version constant do not show what an older tag ships. Check a tag's **Module release check** result before adopting it. Never move an existing tag to add products.

Releases so far:

- `0.3.1` (current): rewords the template's onboarding copy and lets code off the main actor read `OnboardingView`'s default titles.
- `0.3.0`: made module text translatable (see Localization), which changed public API: `String` parameters became `LocalizedStringResource` and `id` became required.
- `0.2.0`: the round-one release.
- `0.1.0`: TemplateVersion only, before Theme, Onboarding and Settings existed.

## XcodeGen include note

In the top-level spec, `packages.<name>.path` is written verbatim relative to the generated project directory (`StarterApp/`), so the template uses `path: ..`. When a spec includes `project.yml`, XcodeGen rebases that value relative to the including file, which puts it one directory too high. So every overlay repeats `packages: StarterModules: path: ..` (see `examples/pocket-notes.yml`), the configuration probes pass an absolute path, and `check-modules.py` fails with a named fix when a generated project's package reference does not resolve to this repository.
