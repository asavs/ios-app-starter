# Choose and update app features

Each feature of the starter is a module you enable in `project.yml`; keep the ones your app needs and remove the rest. The modules are `TemplateVersion`, `Theme`, `Onboarding`, `Settings` and `TabShell`. TabShell is unreleased; use the local path until a new tag includes it. Authentication and persistence modules are planned.

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
| `Settings` | A settings screen with the standard rows every app ends up writing: appearance, About with the version, a Privacy and Data screen (with the privacy policy link App Review requires), Acknowledgements, and Erase Local Data behind a confirmation; plus Keychain-backed secrets. Requires `Theme`. | `SettingsView { } about: { PrivacyNoticeLink(_:); AcknowledgementsLink(_:) }` behind a navigation link; `ResetLocalDataButton(reset:)`; `.storedAppearance()` at the root; `KeychainStore` / `SecureStore`. |
| `TabShell` | Native tabs with typed, restored selection and host-supplied count badges. Requires `Theme`. | `TabShell(tabs:selection:) { tab in ... }`; own `TabSelection` in scene-root `@State`. Unreleased. |
| `SessionTimer` | A session plan of timed phases and a clock that can't drift: start, pause, skip, reset, and a snapshot of where the session is. No UI or other module. | `SessionTimer(plan:)` in a view's `@State`; read `timer.snapshot`. Unreleased. |
| `TimerRing` | One ring that empties as a phase runs out, with its remaining time and title, read by VoiceOver as one element. Requires `Theme`. | `TimerRing(fractionRemaining:title:remaining:)` fed from a `SessionSnapshot`. Unreleased. |
| `Cues` | Foreground sounds and haptics for a session (a start tone, a beep per phase, a chime at the end, each with its tap), mixed with music, with a Sounds & Haptics section for Settings. | `CuePlayer().play(.phaseChange)`, `player.haptic(for:)` inside `sensoryFeedback`; `CueSettingsSection()` inline or `CueSettingsLink()` as a row in `SettingsView { }`. Unreleased. |
| `DurationPicker` | A form row for minutes and seconds that opens native wheels, kept inside a range and on a step. Requires `Theme`. | `DurationPickerRow("Work", value: $duration)`. Unreleased. |
| `Database` | Opens, seeds and erases an app's SwiftData store: a container factory for a versioned schema and migration plan, persistent or in-memory, a once-per-key seed, a loader whose failure shows a recovery screen (Retry, or Start Over on request), and an erase step for Settings. The app owns its models and schemas. Requires `Theme`. | `DatabaseGate(StarterDatabase.loader()) { ContentView() }` at the root; `Database.seed("presets.v1", in: context) { }`; `Database.erase(container)`. Unreleased. |
| `Attachments` | Photos, camera, files and links attached to anything: a picker menu over the system pickers (no Photos permission; the camera is the one), an `Attachment` value for the app's records, a store that keeps originals under Application Support and thumbnails and link metadata under Caches, a grid, Quick Look preview and a link card. Requires `Theme` and `Onboarding` (the camera permission requester). | `AttachmentPicker(model:)` with an `AttachmentPickerModel(store:onAdd:)`; `AttachmentGrid(_:store:selection:onRemove:)` plus `.attachmentPreview(_:in:store:)`; `LinkPreview(_:store:)`; `AttachmentStore.standard()`. Unreleased. |
| `SessionActivity` | A Live Activity for a running session: the Dynamic Island and Lock Screen count the phase down by themselves, with the session's end time, a pause/resume button, and a deep link back to the app; a controller that starts, updates and ends it from session snapshots; a Settings toggle. Needs a widget extension target (`StarterWidgets`). Requires `SessionTimer` and `Theme`. | `SessionActivityController(host: ActivityKitHost(), isEnabled:)` once per app; `controller.sessionChanged(snapshot, plan:, attributes:)`; `SessionActivityWidget()` in the extension's `WidgetBundle`; `SessionActivitySettingsSection()`. Unreleased. |

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

`.onboardingGate(steps:version:record:)` shows the flow in a sheet over its content until the user finishes it once, the same sheet a replay uses. Swiping the sheet down counts as Skip: Apple's guidance is that onboarding is optional and a skipped flow is not shown again, but stays easy to find later. `OnboardingRecord` stores the completed version in `UserDefaults` under `onboarding.completedVersion`, which suits it because nothing here is secret (the Settings module handles Keychain values). Raise `version` when the flow changes enough to show again, and call `reset()` from a settings screen to show it on the next launch. Accessibility identifiers for UI tests: `onboarding.next`, `onboarding.skip`, `onboarding.step.<id>`, `onboarding.page.<id>`, `onboarding.feature.<id>`, `onboarding.choice.<step id>.<option id>`, `onboarding.permission.<id>.footnote`.

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

Under `#if canImport(Onboarding)`, the template app gates `ContentView` behind `OnboardingStep.template(onChoice:)` at version 3: a welcome sheet, a multiple-choice "What will you build?" whose answer the welcome screen shows as "Building: ...", one tour card and a notifications primer. `OnboardingStep.templateDefaults` is the same flow without an answer handler. The welcome screen's "Take the tour" button (`onboarding.replay`, primary style) replays the flow in the same sheet without touching the record. After onboarding, the welcome screen shows "See the tour again" as a popover on the replay button, the template's example tip. Without TabShell, an inline Settings tip comes first, above the greeting, pointing people to the gear; a labeled Settings tab gets no tip, since the HIG's [Offering help](https://developer.apple.com/design/human-interface-guidelines/offering-help) advises against explaining how standard components work.

UI tests force the flow with `-onboarding.completedVersion 0` (`UserDefaults` reads launch arguments ahead of stored values), skip it with `-onboarding.completedVersion 1`, and pass `-onboarding.permissions granted` so the primer never shows a system alert. `testOnboardingSteps` screenshots each of the four steps, picks and clears answers on the choice step, checks the answer on the welcome screen, asserts that Skip disappears on the primer, and checks that the two tips appear in turn (`-tips.reset YES`). The welcome-screen smoke test taps through whatever flow is configured. The page style exists only on iOS, so the view uses it under `#if os(iOS)` and a plain step switch elsewhere, which keeps `swift test` running on the host.

The research behind the design and the planned conversion steps is in [research/onboarding.md](research/onboarding.md): Apple's guidance, tutorial studies, first-launch patterns of well-regarded apps, and a strength-graded review of what converts to trials and purchases, with sources.

### Settings

`SettingsView(version:extra:about:)` is a `Form` with an Appearance section (a segmented `AppearancePreference` picker), the app's own sections from the `extra` builder, and an About section: `AppInfo.version()` (`CFBundleShortVersionString (CFBundleVersion)`, copyable), the `about` rows, and a footer saying text size, contrast and Reduce Motion follow the system, which is the HIG's reason not to duplicate those settings. The two `about` rows the module provides, and what the research behind them says ([research](research/settings-sections.md)):

- `PrivacyNoticeLink(_:)` pushes `PrivacyNoticeView`, built from a `PrivacyNotice`: a summary, what is stored on the device, what leaves it (an empty list says "Nothing"), how to delete it, and the privacy policy `URL`. App Review Guideline 5.1.1(i) requires that link "within the app in an easily accessible manner"; the template leaves it `nil` until the app publishes a policy (docs/human-steps.md), and the row stays hidden until then.
- `AcknowledgementsLink(_:)` pushes `AcknowledgementsView`, one row per `Acknowledgement` (name, author, licence, URL), hidden while the list is empty. The list is kept by hand; nothing is fetched at run time.
- `ResetLocalDataButton(reset:)` goes in a section of its own at the end of `extra`: a destructive row that erases a `LocalDataReset` after a `confirmationDialog` named for what it does. `LocalDataReset` is a list of steps, `.defaults()` (every key the app wrote, one by one so `@AppStorage` views update), `.secrets(in:)` (a `SecureStore`), and the app's own, such as the database store; every step runs even when one fails, and the failures are reported together. Apps with accounts still need account deletion under 5.1.1(v); that lands with the sign-in module.

The module and the app each ship a `PrivacyInfo.xcprivacy` declaring `UserDefaults` use (reason `CA92.1`), which App Store Connect requires; `scripts/check-modules.py` fails a module that uses `UserDefaults` without one.

The appearance picker is an example to keep or delete. Apple's [Dark Mode guidance](https://developer.apple.com/design/human-interface-guidelines/dark-mode) says to "avoid offering an app-specific appearance setting": people then have to adjust more than one setting, and may think the app is broken when it ignores their systemwide choice. It defaults to System. Most apps should delete it and drop `.storedAppearance()`; without it, a UI test can force dark mode with `XCUIDevice.shared.appearance`. `AppSettings` reads and writes the same defaults from non-view code (`appearance`, `reset()`); it holds nothing secret.

Secrets go through the `SecureStore` protocol: `data(for:)`, `set(_:for:)`, `remove`, `removeAll`, `keys()`, the helpers `string(for:)`/`set(String, for:)` and `contains`, and `perform { }`, which runs calls off the caller's actor (`try await store.perform { try $0.contains(key) }`). Keychain calls block their thread, so main-actor code such as a view uses `perform`.

- `KeychainStore` is the implementation: generic-password items scoped by `service` (the bundle identifier by default) and keyed by account. Items use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` unless `.whenUnlocked` is requested. An app's own items need no entitlement. A failing Security call throws `SecureStoreError.keychain(status:operation:)`.
- `InMemorySecureStore` stands in for tests and previews.
- `SecureSettingRow("API key", key: "api.key")` is the matching form row. It never shows the stored value: it reports "Checking…" until its first read returns, then "Stored securely on this device." or "Not set.". Save replaces the value, Clear forgets it, and every Keychain call goes through `perform`.

`SettingsLink(_:systemImage:id:) { }` is the row that pushes a screen of its own (a `Form` with the content), for a module's settings or the app's; see "Settings from other modules" below.

Accessibility identifiers for UI tests: `settings.appearance`, `settings.version`, `settings.<id>` for each `SettingsLink`, `settings.privacy` (and `settings.privacy.summary`, `settings.privacy.policy` on its screen), `settings.acknowledgements` (and `settings.acknowledgements.<id>` rows), `settings.reset` / `settings.reset.confirm`, `settings.secure.<key>.field` / `.save` / `.clear` / `.status`.

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

In the template, `StarterSettingsView` supplies the Cues sounds section, the example secret and onboarding-reset rows. With TabShell it appears in the Settings tab; without TabShell the welcome screen's gear button (`settings.open`) pushes it. The root applies `.storedAppearance()`.

#### Settings from other modules

Settings doesn't depend on feature modules, and feature modules don't depend on Settings. A module with something people can change follows the Cues pattern, and the app composes the pieces:

- **Keys and defaults in one value type** in the module, such as `CuePreferences`: keys namespaced by module (`cues.sound`, `cues.playsInSilentMode`), each default a `static let`, and an `init(defaults:)` that reads stored values or falls back to those defaults. Code that acts on a setting reads it at the moment it acts, so a change applies at once.
- **A form section the module exports**, such as `CueSettingsSection(defaults:)`, using `@AppStorage` with the same keys and defaults. It's a plain `Section`, so it works in `SettingsView`'s builder or any other form.
- **A row that pushes that section**, such as `CueSettingsLink()`, for apps whose Settings nests like iOS Settings (the HIG: "iOS Settings uses a hierarchy of lists"). The Settings module's `SettingsLink(_:systemImage:) { }` builds one for any content, so every module's row looks the same: a `Label` with a symbol, a disclosure indicator, the title as the pushed screen's navigation title.
- **The app places one or the other**: `StarterSettingsView` keeps Appearance inline as the most-touched control and lists `CueSettingsLink()` under `#if canImport(Cues)`, so removing the module's product line removes its settings with it. Its top level is four groups, mostly rows: the app, the examples, data (Privacy and Data, Erase Local Data) and About ([research](research/settings-sections.md#information-architecture)).
- Preferences stay in `UserDefaults`; secrets go through `SecureStore`. Tests inject a defaults suite. UI tests must not pass a module's keys as launch arguments, because the argument domain outranks what a toggle stores and the toggle would seem not to stick.


#### Keychain and signing in tests

The simulator Keychain returns `errSecMissingEntitlement` (-34018) to a process without an `application-identifier` entitlement, and an app built with `CODE_SIGNING_ALLOWED=NO` has none. So `scripts/test-ios.sh` signs the app ad hoc (`CODE_SIGN_IDENTITY=-`, no certificate or team needed) with `scripts/simulator-tests.entitlements`, which declares only that identifier, and the UI test `testSettingsScreen` stores and clears a secret in the real simulator Keychain. Xcode's package test host has no identifier either, so the module's three Keychain tests are `.enabled(if:)` a probe write succeeds, and the package lane reports them as skipped with that reason; the in-memory and preference tests run everywhere. Release and device builds are unaffected: they get the identifier from the provisioning profile.

### TabShell

Choose tabs in Swift. `TabItem` takes a stable string-backed enum ID, a `LocalizedStringResource` title, an SF Symbol name and an optional `badgeCount` (zero hides it). The module supplies no destinations. `StarterTab.swift` chooses the demo's Welcome and optional Settings tabs; `StarterTabsView.swift` supplies their existing screens in separate `NavigationStack`s. Without TabShell, the original welcome screen and Settings gear remain available.

```swift
import SwiftUI
import TabShell

enum SectionID: String, CaseIterable {
    case library, activity
}

struct AppTabs: View {
    @State private var selection = TabSelection(tabs: SectionID.allCases, defaultTab: .library)

    var body: some View {
        TabShell(tabs: [
            TabItem(id: SectionID.library, title: "Library", systemImage: "books.vertical"),
            TabItem(id: .activity, title: "Activity", systemImage: "bell", badgeCount: 3),
        ], selection: selection) { tab in
            switch tab {
            case .library: NavigationStack { LibraryView() }
            case .activity: NavigationStack { ActivityView() }
            }
        }
    }
}
```

`LibraryView` and `ActivityView` above stand for the app's own screens. Change badge counts by recreating the descriptors from host state; keep their IDs fixed. The shell and selection must have the same unique IDs in the same order. Tabs are fixed for a selection instance's lifetime; create a new instance when the app's available destinations change.

`TabSelection.selectedTab` is observable and writable for native bindings. It remembers the stable raw value in `UserDefaults` under `tabs.selected` (customizable with `storageKey:` and `defaults:`). A missing, unknown or removed stored destination falls back to the host's `defaultTab`. Unavailable assignments are ignored. Each scene owns an independent instance; existing windows navigate independently, while a new scene restores the last saved selection. This persists the selected tab, not navigation paths or app data.

For deep links, first validate and authorize the URL in the app, then call `selection.select(rawValue: "activity")`. It returns `false` without changing selection for an unknown or unavailable ID. URL schemes, domains, authentication, and routes inside a destination belong to the host; the module does not register or accept URLs itself. The template registers `APP_URL_SCHEME` from `project.yml` (`starterapp`) in `StarterApp/StarterApp/Info.plist`, and `StarterTabsView` passes `<scheme>://<tab>` links, such as `starterapp://settings`, to `select(rawValue:)` through `DeepLink.tab(in:)`. That parser rejects other schemes and any path, query, fragment, user or port, since any app or web page can open the link. An app that adds routes inside a tab, or actions, validates each in `DeepLink` before acting on it. `testDeepLinkSelectsTab` opens real links; `DeepLinkTests` covers the parser. Badge counts stay unused in the template until a module has something worth counting, such as sign-in or a database.

The view uses the native `Tab` API on iOS 18 / macOS 15 and later, with `tabItem` confined to the iOS 17 / macOS 14 fallback. Theme supplies its accent; the system supplies material, placement, safe areas and accessibility traits. On iPhone, this allows the system's Liquid Glass tab bar on iOS 26 and later. The module adds no custom glass layer, tab-reordering UI or forced bottom placement on iPad.

UI identifiers are `tabs.<raw value>`, such as `tabs.welcome` and `tabs.settings`. iOS 26.3 leaves tab bar buttons without them (iOS 27 keeps them), so UI tests fall back to the tab's title when the identifier is empty. Existing UI tests force `-tabs.selected welcome` to start consistently. `testTabShellSwitchesAndRestoresSelection` removes that argument on its second launch to verify actual persistence. Module tests cover restoration, removed and invalid destinations, deep-link selection, independent keys/scenes, identity and badge boundaries. Native compilation and runtime acceptance are pending Mac review of the first implementation. [Research and verification boundaries](research/tab-navigation.md).

### SessionTimer

A session is a `SessionPlan` of `SessionPhase`s, each with a stable `kind` (never shown), a `LocalizedStringResource` title and a positive `Duration`. `SessionPlan.intervals(work:rest:rounds:)` builds rounds with a rest between them and none after the last, so a session ends on work. The same types fit an interval workout, a Pomodoro (25 minutes focus, 5 minutes break) or a meditation with a lead-in and a closing phase.

```swift
import SessionTimer

struct FocusView: View {
    @State private var timer = SessionTimer(plan: .intervals(
        work: SessionPhase(kind: "work", title: "Focus", duration: .seconds(25 * 60)),
        rest: SessionPhase(kind: "rest", title: "Break", duration: .seconds(5 * 60)),
        rounds: 4))

    var body: some View {
        let snapshot = timer.snapshot
        Text(snapshot.phaseRemaining, format: .time(pattern: .minuteSecond))
        Button(snapshot.status == .running ? "Pause" : "Start") {
            snapshot.status == .running ? timer.pause() : timer.start()
        }
    }
}
```

`SessionClock` is the value underneath: it stores when the session last started and how long it had run before that, and derives the phase, remaining time and status from the instant it's asked about, so time is never added up tick by tick. It uses `ContinuousClock`, which keeps counting while the phone sleeps. A boundary belongs to the next phase; pauses don't count; skipping from the last phase finishes; a finished session stays finished until `reset()`. Tests pass fixed instants (`clock.snapshot(at: t0 + .seconds(25))`) instead of waiting. `SessionTimer` is the `@MainActor @Observable` driver: `snapshot` refreshes every 100 ms while running (set `refreshInterval:`) and stops refreshing when paused or finished. It takes `now:` so tests control the clock instead of sleeping. A late refresh never loses time, but nothing runs while the app is suspended: cues with the screen locked need scheduling that the research is still settling ([background cues](research/background-audio.md)). `snapshot` is `Equatable`, so `.sensoryFeedback(trigger: snapshot)` can tap on phase changes, as the template does.

The template's Timer tab (`StarterApp/StarterApp/Timer/`, shown with TabShell) runs two plans through the same modules: three rounds of 20 s work and 10 s rest, and four 25-minute focus blocks. **Edit** (`timer.edit`, with DurationPicker) opens a sheet for the chosen plan's work and rest lengths and rounds, disabled while a session is underway; `TimerScreenModel` holds the tab's logic (plan choice, stored times, the primary button, which cue each change plays) so `TimerScreenModelTests` can check it against an isolated defaults suite and a controlled clock; the views only lay it out. Times are stored per plan in `UserDefaults` (`timer.intervals`, `timer.focus` as `work,rest,rounds` seconds) until the database module saves plans. It taps on each phase change and on finishing, and keeps the screen awake only while a session runs on that screen. Identifiers: `timer.plan`, `timer.ring`, `timer.step`, `timer.primary`, `timer.skip`, `timer.reset`. `testTimerEditsAPlan` sets the work phase to 0:30 with the hours, minutes and seconds wheels, adds a round and checks the ring, step count and a relaunch; `testTimerRunsAPlan` pins both plans' times with launch arguments, starts, pauses (the countdown must not move), skips through every phase to Done, resets and switches to the focus plan. Module tests cover phase derivation, boundaries, crossing several phases in one late snapshot, pause accounting, repeated calls, finishing once, skip while running and paused, reset and the driver's refresh. [Research](research/interval-timing.md).

### TimerRing

`TimerRing(fractionRemaining:title:remaining:tint:)` draws what it's given and keeps no time: pass `snapshot.phaseFractionRemaining`, the phase title and `snapshot.phaseRemaining` on every update. The fraction is clamped to 0...1 (non-finite values draw an empty ring), and the time shows whole seconds rounded up, so a 20-second phase reads 0:20 for its first second and 0:00 only when it ends. `tint` defaults to Theme's accent; the template tints rests with `success`. It's a single ring on purpose: the HIG reserves concentric Activity rings for Move, Exercise and Stand and says not to imitate them.

VoiceOver reads one element, the title as its label and "45 seconds remaining" as its value, when someone moves to it, never on every update. The line width scales with Dynamic Type; the time and title shrink to fit inside the ring rather than overflow it, so at the largest text sizes they stay inside the circle while the screen around it scrolls. Module text ("%@ remaining") is in its string catalog. [Research](research/progress-ring.md), including the open-source rings compared.

### Cues

`CuePlayer().play(.start)` plays two quick rising notes, `.phaseChange` a short beep and `.finished` a rising chime. The tones are generated in code (`Tone`), so the module ships no audio files. Sounds mix with music and podcasts and never lower them. With "Play in silent mode" on (the default, like the Clock app's timer) they use the playback audio category and sound through the Ring/Silent switch; off, they use the ambient category and the switch silences them. "Sounds" off plays nothing. `CuePlayer` reads `CuePreferences` from `UserDefaults` on every cue.

Cues play only while the app is open: the module declares no background mode and keeps nothing running, because a silent keep-alive loop risks App Review rejection under guideline 2.5.4 ([research](research/background-audio.md)). Locked-screen cues wait on phone measurements of the notification budget (`ios-1mo`); speech and countdown beeps join this module after that.

The template's Timer tab plays them from `SessionSnapshot.transition(from:)`, which reports `.started` (from the beginning, or again after finishing), `.resumed`, `.phaseStarted(index:)` while running and `.finished`, once each, and nothing for pauses, skips while paused, resets or plan changes. Start and resume play `.start`. The same transition drives the haptics. `testCueSettings` turns Sounds off, checks "Play in silent mode" is disabled and that the choice survives a relaunch; the sound itself is checked on the phone. Module tests cover the preferences, that sound off plays nothing, that a changed setting applies to the next cue, the WAV data and the tone envelope. [Research](research/background-audio.md) and [cue preferences research](research/cue-preferences.md).

Each cue has a haptic too: `Cue.haptic` maps `.start` to `SensoryFeedback.start`, `.phaseChange` to `.impact` and `.finished` to `.success`, the system's semantic feedback types ([research](research/haptics.md)). SwiftUI plays haptics from a view's `sensoryFeedback(trigger:_:)`, so the player only decides: `CuePlayer.haptic(for:)` returns the cue's haptic, or nil when the Haptics toggle is off. The Timer tab returns `model.haptic(from:to:)` from its trigger closure. The section's three toggles are Sounds, Play in silent mode and Haptics, under `cues.sound`, `cues.playsInSilentMode` and `cues.haptics`; haptics don't depend on sounds, since a silent tap is a common choice. The Onboarding choice step's selection tick is not a cue: it's the system's picker feedback and stays on.

### DurationPicker

`DurationPickerRow(_:value:range:step:)` is a form row for a `Duration`, laid out like the Clock app's timer: hours, minutes and seconds wheels with "hours", "min" and "sec" fixed beside the selection. It shows the title and value; tapping it opens the wheels below it, the way a date row opens in Calendar, so a form can hold several (the template's Work and Rest). Apple doesn't offer Clock's picker to other apps (`UIDatePicker`'s countdown mode has no seconds), so the row puts three native `.wheel` pickers side by side, each clipped so their touches don't overlap. Unlike Clock, each wheel draws its own selection highlight, since SwiftUI has no way to replace it with one band.

The range defaults to 0:01 ... 23:59:59 (Clock's limit, also the most it accepts); the hours wheel is hidden when the range stays under an hour. Seconds move in `step`s, one second by default (it must divide a minute). Every value it writes is inside the range and on a step. VoiceOver reads the row's value in words ("30 seconds") and adjusts each wheel natively ("Number of minutes, 0"). `DurationOptions` holds the arithmetic and is what the module tests cover: wheel choices, the Clock default, clamping and rounding to a step, splitting and combining hours, minutes and seconds, odd ranges and steps. [Research](research/duration-picker.md).

### Database

`Database.open(schema:migrationPlan:storage:)` returns a `ModelContainer` for the app's `Schema` (built from its `VersionedSchema`) and `SchemaMigrationPlan`, at `.persistent(url)` (`.applicationSupport(named:)` is the usual place) or in `.memory` for previews and tests. The module owns no models: a package can't know an app's schema or decide its migrations, so the schema history, seed content and migration stages stay in the app ([research](research/database.md)). A failed open throws `DatabaseOpenError` (the file name and the reason, nothing from inside) and leaves the files alone.

- `DatabaseLoader(schema:migrationPlan:storage:)` opens the store at launch and holds `.ready(container)` or `.failed(error)`; `retry()` opens the same files again, `startOver()` removes them (with the `-wal` and `-shm` sidecars) and opens a fresh store, only when the person asks. `DatabaseGate(loader) { content }` puts the container in the environment on success and shows `DatabaseRecoveryView` otherwise: the reason, Try Again, and Start Over behind a confirmation. Identifiers `database.retry`, `database.startOver`, `database.startOver.confirm`.
- `Database.seed(key, in: context) { }` runs its closure once per key and saves a `SeedMarker` with the inserted records in the same transaction, so deleting every seeded record doesn't bring them back. Add `SeedMarker.self` to the schema.
- `Database.preview(schema:seed:)` is an in-memory container with the seed run once, for `#Preview`.
- `Database.erase(container)` deletes every record (`deleteAllData()`), for a `LocalDataReset` step; the seed marker goes too, so sample content returns on the next launch, as on a fresh install.

The template's store is `StarterSchemaV1` (`TimerPreset` and `SeedMarker`) with an empty `StarterMigrationPlan`, opened by `StarterDatabase.loader()` in the App and seeded once with two presets (`SeedOnLaunch`). The Timer tab's Presets button lists them (`TimerPresetsView`: tap to load, swipe to delete, Save Current to add one). UI tests pass `-database.store <name>` for a store of their own in the temporary directory and `-database.reset` to empty it on the first launch. When a model changes, add `StarterSchemaV2` and a stage; never edit V1, and test the migration against a store written by the shipped V1 build.

### SessionActivity

A Live Activity is a view the system archived, not running code: it draws a countdown to a date by itself while the app is suspended, and nothing in it runs when the date passes ([research](research/live-activities.md)). The module is built around that. `SessionActivityState` is the activity's content: the phase (index, count, title, kind, duration), the running phase as a `ClosedRange<Date>` or the paused remaining time, and the session's end date, which the system counts down to without any update. `SessionActivityState(snapshot, plan:, now:)` maps a `SessionSnapshot` to it (nil for a session that hasn't started), and `staleDate` is the phase's end, so the view can say the phase is over until the app publishes the next one. `SessionActivityAttributes` holds what doesn't change: the plan's title, the session's identifier and the link the activity opens. Everything encodes well under ActivityKit's 4 KB.

- `SessionActivityController(host:isEnabled:now:)` keeps one activity in step with a session: `sessionChanged(_:plan:attributes:)` starts it on the first running or paused snapshot, updates it on later ones, ends it with a final state on finish (dismissed after 15 minutes, the HIG's suggestion) and at once on reset; `settingChanged(sessionID:)` removes it when the person turns the setting off. Calls are queued in order. A refused start (Live Activities off for the app, too many activities, the app in the background) is not retried every tick. Own one per app, not per screen: `ActivityKitHost` looks activities up by session identifier in `Activity.activities`, so one from an earlier launch is updated or ended rather than leaked. The `SessionActivityHost` protocol stands for ActivityKit, so the controller has tests with a recorder and compiles on the Mac host; the ActivityKit types are under `#if os(iOS)` (ActivityKit's module exists on macOS, with every type unavailable, so `canImport` is the wrong guard).
- `SessionActivityWidget` is the `Widget` for the extension's `WidgetBundle`: the Lock Screen banner (`SessionLockScreenView`) and the Dynamic Island's compact (a ring and the countdown, framed at 52 points because timer text in a widget otherwise grows to fill the width), minimal (the ring) and expanded presentations (ring, countdown, plan and phase, "Ends at" and the one button). Rest phases take the theme's success colour. The keyline and tint are the theme's accent. Identifiers `sessionActivity.lockScreen`, `sessionActivity.toggle`.
- `ToggleSessionIntent` is the button's `LiveActivityIntent`: the system performs it in the app's process, launching the app in the background if needed, so the app installs what to do in `SessionActivityIntents.toggle` at launch. The extension only shows the button.
- `SessionActivityPreferences` (`sessionActivity.enabled`, on by default) and `SessionActivitySettingsSection` (one toggle, identifier `sessionActivity.enabled`) follow the Cues pattern: the app places the section.

The activity needs a widget extension, which is an Xcode target, not a package product: `StarterWidgets` in `project.yml` (`type: app-extension`, extension point `com.apple.widgetkit-extension`, embedded by the app's `- target: StarterWidgets` dependency), with `StarterApp/StarterWidgets/StarterWidgets.swift` listing `SessionActivityWidget()` and `NSSupportsLiveActivities` in the app's Info.plist. Its bundle identifier must be a child of the app's (`com.example.StarterApp.Widgets`), so an overlay that changes the app's identifier sets this one too, as the two examples do. `scripts/check-configuration.py` allows that one extra target and checks the identifier; `collect-release-symbols.py` and `testflight-release.py` validate the embedded `.appex`. Signing it registers one more App ID under the team and creates its profiles; no capability or entitlement (docs/human-steps.md). Remove the target with the module.

The template wires it in the Timer tab. `TimerScreenModel` gives each run of a session a `sessionID`, saves a `SessionRecord` (plan, times and the clock's position as dates, `SessionClockState`) on every change and clears it on reset, and passes each snapshot to `StarterSessionActivity.shared`, which owns the controller, installs the intent handler from the App's `init`, and reattaches on launch. The intent loads the record, pauses or resumes the clock, saves it and updates the activity; when the app returns to the foreground the Timer screen takes the stored position over (`restoreFromRecord`). A phase change while the phone is locked reaches the activity only when the app next runs: scheduled notifications for that are `ios-1mo`, and AlarmKit on iOS 26 is a later example. UI tests pass `-sessionActivity.readout` to show the activity count (`timer.activityCount`); `testTimerLiveActivity` starts a session, checks one activity exists, screenshots the island from the Home Screen, pauses and resets.

### Attachments

Built around one fact from the research ([research](research/attachments.md)): since iOS 16 every picker here is a system view in another process, so the app needs no permission for a person to choose a photo or a file, and the only permission in the feature is the camera's. `Attachment` is a value (identifier, kind, display name, content type identifier, byte count, date, and the file's path relative to the store or the link) that an app keeps on its own records; the template puts a `[Attachment]` on `TimerPreset`. The bytes live in `AttachmentStore`, an actor: originals under `Application Support/Attachments` (the person's data, backed up with the database that names them), thumbnails and link metadata under `Caches/Attachments` (rebuilt on demand). It never reads a file's dates, so no privacy manifest reason is needed; sizes and dates are recorded on the value.

- `AttachmentPickerModel(store:sources:allowedContentTypes:maxPhotoSelection:onAdd:)` does the work and `AttachmentPicker(model:)` is the Add menu: Photos (`PhotosPicker`, loaded as files through a `FileRepresentation` so a large HEIC never sits in memory), Camera (`UIImagePickerController` full screen; hidden where there is no camera), Files (`fileImporter`, copied while the security-scoped access is held and never kept as a bookmark) and Link (a typed web address; `https://` assumed). Each import runs in its own task, is counted for the menu's progress indicator, and reports a failure in an alert. `onAdd` receives each new attachment.
- `AttachmentStore.add(link:)` fetches the link's metadata once, from the device, when the person adds it, and caches the `LPLinkMetadata` archive; `LinkPreview` draws it with `LPLinkView` without fetching again. `LinkMetadataFetching` is the seam: `FakeLinkMetadataFetcher` answers offline for tests.
- `AttachmentGrid` is an adaptive grid of `AttachmentCell`s (thumbnail, name, kind), one column with the name beside the thumbnail at the accessibility text sizes; each cell is one VoiceOver element ("Photo, invoice.pdf") with Remove as an accessibility action and a context menu entry. Tapping sets the selection; `.attachmentPreview(_:in:store:)` opens a file in Quick Look (paging through the others) and a link in the browser.
- `CameraPermission` adopts Onboarding's `PermissionRequesting` for an app whose point is the camera; the template asks on the first tap instead, which `UIImagePickerController` does by itself. The app's Info.plist needs `NSCameraUsageDescription` (project.yml `info.properties`); `scripts/check-modules.py` fails a build that enables the module without it.
- `AttachmentStore.remove(_:)` deletes the file and its caches; `sweep(keeping:)` removes every file the app no longer names, for after a database erase. Tests cover placement, thumbnails, links, removal and the sweep in a temporary store.
- Launch arguments for UI tests (`AttachmentTestOverrides`, read from the process arguments): `-attachments.root <dir>` and `-attachments.reset` for an isolated store, `-attachments.fakeCamera` and `-attachments.fakePhotos` to add a generated photo instead of presenting a picker, `-attachments.fakeLink <title>` for offline link metadata.

The template attaches to presets: swipe a preset from the leading edge for its Attachments screen (`timer.presets.row.<name>.attachments`), where the Add menu, the grid, Quick Look and the link card are. `TimerPreset` gained `attachments` in `StarterSchemaV2`, with `StarterSchemaV1` frozen inside the schema file and a lightweight stage in `StarterMigrationPlan`; `SchemaMigrationTests` writes a V1 store and opens it under the plan. Erase Local Data removes the store's directories (`StarterAttachments.resetStep`). Identifiers: `attachments.add` and `.add.photos/.camera/.files/.link`, `attachments.link.field`, `attachments.link.add`, `attachments.grid`, `attachments.item.<id>` (and `.remove` as the action), `attachments.linkPreview`, `timer.presets.attachments.done`.

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
5. Run `python3 scripts/check-modules.py`, `bash scripts/test-module.sh <Name>` (simulator) and `bash scripts/test-ios.sh` (every UI test in the `StarterAppUITests` target). If the module adds something visible, add a UI test of its main path in the same pull request, in the class for its area (`OnboardingUITests`, `SettingsUITests`, `TimerUITests`, or `StarterAppUITests` for the shell; a new area gets a new class, since parallel clones take a class each), gated with `requireModuleUI("<Name>", appeared:_:)`. The gate skips when the module is disabled and fails when `test-ios.sh` reports the module enabled (`TEST_RUNNER_IOS_ENABLED_MODULES`, read from the generated project) but its UI did not appear, so a stale launch argument cannot hide behind a skip. If the module compiles on macOS, `swift test` from the repository root is a fast host-side check.
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
