# Dynamic tab choices and navigation

Checked 2026-11-02 against Apple's documentation, HIG and WWDC sessions. Minimum: iOS/iPadOS 17. Build toolchain: Xcode 27.0, independently of runtime support. Built as: pending. Research only; this change adds no app behavior and verifies no simulator or device behavior.

Keep the native TabShell and add host-owned, persisted choices with a Settings editor that works on iOS 17. Keep Settings reachable, preserve feature state outside removable tab views, and reveal a hidden compiled destination when a valid link opens it. Start with five or fewer default destinations. Accept native overflow only after the tests below establish that every chosen destination is reachable on each supported presentation.

## What the repository already does

Source baseline: [main at 101cb28](https://github.com/asavs/ios-app-starter/tree/101cb2818ba62f6fea54222663e659598cf7d473). The earlier [tab navigation research](tab-navigation.md) covers the original shell and its design rationale. The [feature plan in PR #147](https://github.com/asavs/ios-app-starter/blob/8842cd55c654248041998780a5dd80fb4c9dff50/docs/design/feature-tabs.md) was read at its head, 8842cd5; PR #147 merged while this research was being prepared. Its feature screens and chooser remain planned behavior, not implemented behavior in the source baseline. This research supplies the dynamic-navigation contracts and verification requirements for that plan.

| Existing source | Observed behavior and limitation |
| --- | --- |
| [TabItem](../../Modules/TabShell/Sources/TabItem.swift) | String-backed ID, localized title, symbol, nonnegative badge and `tabs.<raw ID>` identifier. Labels and positions are independent of identity. |
| [TabSelection](../../Modules/TabShell/Sources/TabSelection.swift) | `tabs` is immutable and ordered. Initialization requires unique, nonempty IDs and a valid default. Stores only the selected raw ID in `tabs.selected`; a removed or unknown saved ID falls back in memory to the default. It does not immediately repair that stored value. Invalid programmatic selections return false or are ignored. |
| [TabShell](../../Modules/TabShell/Sources/TabShell.swift) | Requires its ordered item IDs to exactly match `selection.tabs`. Uses native `Tab` on iOS 18+, `tabItem`/`tag` on 17. Has no runtime choice editor, `sidebarAdaptable` style or `TabViewCustomization`. |
| [StarterTab](../../StarterApp/StarterApp/StarterTab.swift), [StarterTabsView](../../StarterApp/StarterApp/StarterTabsView.swift) | Welcome, optional Timer and optional Settings are compiled with `canImport` guards. Each destination has its own NavigationStack; paths are not bound to persistent route storage. Each scene owns a selection instance. |
| [DeepLink](../../StarterApp/StarterApp/DeepLink.swift) | Validates a registered scheme and tab host; rejects credentials, ports, non-root paths, queries and fragments. The host then asks TabSelection to select the raw ID. Unknown/unavailable destinations currently leave selection unchanged without an explanation. There is no hidden-tab concept. |
| [StarterSessionActivity](../../StarterApp/StarterApp/Timer/StarterSessionActivity.swift), [widget](../../Modules/SessionActivity/Sources/Views/SessionActivityWidget.swift) | Activity attributes link to the Timer raw ID; the widget applies `widgetURL`. This reaches the same URL handler. [StarterTimerView](../../StarterApp/StarterApp/Timer/StarterTimerView.swift) currently owns TimerScreenModel in `@State`, so removing that view is a lifetime risk. |

[TabSelectionTests](../../Modules/TabShell/Tests/TabSelectionTests.swift) cover selection persistence, invalid stored values, removed IDs, rejected links and independent open scenes. [DeepLinkTests](../../StarterApp/StarterAppTests/DeepLinkTests.swift) cover URL parsing. They do not establish dynamic ordering, hiding, six-tab overflow, retained drafts or per-tab path restoration.

## Platform boundaries

Apple's current HIG includes newer platform appearances; do not apply those descriptions to iOS 17. These availability boundaries come from Apple's symbol documentation metadata.

| Runtime | Supported approach |
| --- | --- |
| iOS/iPadOS 17 | Existing selection-bound TabView with tags and tabItem. The host can render its own ordered subset and provide a native List/Form editor. NavigationStack and SceneStorage are available. No new `Tab`, adaptable tab/sidebar style or TabViewCustomization. |
| iOS/iPadOS 18+ | [`Tab`](https://developer.apple.com/documentation/swiftui/tab), [`sidebarAdaptable`](https://developer.apple.com/documentation/swiftui/tabviewstyle/sidebaradaptable) and [`TabViewCustomization`](https://developer.apple.com/documentation/swiftui/tabviewcustomization). The adaptable style presents bottom tabs on iPhone and a top bar convertible to a sidebar on iPad. Native customization is not a universal iPhone editor: [`customizationBehavior`](https://developer.apple.com/documentation/swiftui/tabcontent/customizationbehavior(_:for:)) documents customization on iPad and no effect on unsupported platforms/styles. |
| iOS/iPadOS 26+ | Liquid Glass presentation described in [WWDC25: Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/). [`TabBarMinimizeBehavior`](https://developer.apple.com/documentation/swiftui/tabbarminimizebehavior) and [`TabViewBottomAccessoryPlacement`](https://developer.apple.com/documentation/swiftui/tabviewbottomaccessoryplacement) begin at 26. These are presentation/accessory tools, not a persistence or overflow solution. Scroll-triggered minimization is supported only on iPhone. Keep the default behavior for this work. |

[WWDC24: Elevate your tab and sidebar experience in iPadOS](https://developer.apple.com/videos/play/wwdc2024/10147/) at 6:41 and 10:45 demonstrates the adaptable style and customization. Customizable items use stable customization IDs; customization can be persisted with AppStorage. Essential destinations can disable customization in both tab bar and sidebar placements. This could support a later iPad enhancement, but would require synchronizing its changes with the iOS 17 choice model. Avoid two independent sources of truth in the first implementation.

## Choices, identity and normalization

The following are recommended app policies, not automatic SwiftUI behavior. Extend the existing TabSelection/TabShell contract before passing a changing item list to it. Update ordered items and valid selection together; do not use a new random identity or a whole-shell `.id(choices)` to force rebuilding.

Keep three concepts separate: the registry of implemented, compiled destinations; the person's ordered visible choices; and this scene's selected destination. Overflow is a presentation of a chosen destination, not a hidden feature. Empty content or denied permissions should produce an explanatory screen in an available tab. The [tab bar HIG](https://developer.apple.com/design/human-interface-guidelines/tab-bars) discourages tabs disappearing as content becomes unavailable; intentional user customization is a separate operation.

Use stable raw IDs for choices, selection, route state and drafts. Preserve `welcome` when its title becomes Home, as PR #147 specifies. Never persist translated titles, array indices or SF Symbols as identity. If native customization is added, derive its IDs from those same stable identities.

Normalize a versioned preferences record on load and on every edit:

1. Decode defensively, remove duplicates while preserving the first occurrence, and filter unknown and uncompiled IDs from the effective choices. Persist the repaired record so relaunch gives the same result. For this first version, removed choices are discarded; reinstalling a module does not silently restore its visibility. Do not delete its feature data.
2. Keep compiled Settings in the choices and make its visibility non-editable. Recommend allowing its position to move; reachable includes a verified overflow row. If the Settings module is absent, omit the editor and use the host's remaining valid defaults. No feature may depend on a missing Settings tab to escape an empty shell.
3. Distinguish an absent record from an intentionally minimal choice. An absent or undecodable record uses configuration defaults; a valid record does not gain every newly introduced feature. Ensure at least one compiled destination survives, using the host default (currently `welcome`) before selecting another available destination.
4. Retain selection by ID after a reorder. If it was hidden, removed or is unknown at launch, select the visible host default, otherwise the first normalized choice, and persist the repair. Ordinary restoration does not reveal a previously hidden destination. An explicit valid deep link does.

Settings and optional onboarding must use the same normalization and persistence. Replay/skip must preserve an existing choice; a new installation's skip uses defaults. Neither operation may erase records, drafts or a running session.

## Overflow and iPad adaptation

The [HIG](https://developer.apple.com/design/human-interface-guidelines/tab-bars) describes More on both iOS and iPadOS when space limits visible tabs, advises avoiding overflow, and recommends five or fewer default items for customization. UIKit's documented [More controller](https://developer.apple.com/documentation/uikit/uitabbarcontroller/morenavigationcontroller) is automatic; the classic [UITabBarController](https://developer.apple.com/documentation/uikit/uitabbarcontroller) behavior for six or more controllers is four items plus More. This documents UIKit behavior, not a tested guarantee about every SwiftUI TabView style or width.

Keep native rendering initially and test six and ten destinations. Do not promise that an iPad always fits more tabs, or hardcode the screen's width: Split View, window resizing, orientation, localization and text size change the space available. On iPadOS 17, the existing native TabView remains the baseline; a custom sidebar would be additional app work. On 18+, consider an adaptable sidebar for the larger feature set, while preserving a compact path to every destination.

Apple's [`TabView` documentation](https://developer.apple.com/documentation/swiftui/tabview) includes a compact Browse destination that lists destinations otherwise grouped in a regular-width sidebar. It explicitly maps selection and path when changing size class. An adaptable sidebar alone does not solve compact overflow; secondary tabs flatten into the compact bar.

If native More fails the reachability/state tests, use that Browse pattern as an explicit, scrollable All tabs destination within native navigation. It can list every chosen feature and Settings with labeled rows; a separate Settings editor controls visibility. Map the logical selected feature to its displayed tab or chooser route without overwriting its stable identity. Maintain feature-owned paths rather than pushing the same feature into unrelated shared stacks. A custom chooser works on 17 with List/NavigationStack, but introduces selection mapping, Back behavior and focus work that system More otherwise owns. Do not create a custom floating tab bar or an action disguised as a tab.

Do not rely on a native More Edit screen to persist the host's ordered choices. TabShell currently exposes no bridge for system reorder changes. If that interaction appears, verify it cannot contradict Settings or add an explicit synchronization policy before shipping.

## Restoration and feature lifetime

| State | Recommended ownership and survival |
| --- | --- |
| Ordered choices | App preferences shared by the app's scenes. Survive relaunch, reorder and hide/show. Include a schema version and a migration for renamed IDs. |
| Selected tab | Keep scene-local navigation, retaining the existing last-saved selection as the default for a new scene. Existing open scenes must not follow another scene's selection. Normalize an affected scene when shared choices remove its selected tab. |
| Per-tab stack | Host-owned route paths keyed by tab ID, above the removable destination view. Preserve across switching, reorder and hide/show in the current scene. For relaunch restoration, encode lightweight route identifiers and validate that referenced objects still exist; drop an invalid suffix safely. |
| Drafts and sessions | Durable feature storage/models independent of tab presence. Preserve draft text, attachment references and active timer state across hiding and relaunch. Show save failures and retain recoverable edits. Hiding must not trigger deletion, reseeding or a timer stop. |

[WWDC22: The SwiftUI cookbook for navigation](https://developer.apple.com/videos/play/wwdc2022/10054/) demonstrates path-based navigation and encoding restoration state. [`SceneStorage`](https://developer.apple.com/documentation/swiftui/scenestorage) is lightweight, per scene, has no guaranteed persistence schedule and is deleted with a discarded scene. Use it for recoverable UI context; save drafts and authoritative session data through the feature's storage. The current unbound stacks do not promise restoration after their tab is removed. Stable ForEach IDs alone cannot preserve state of a destroyed view.

Move Timer model ownership above tab presentation before enabling hiding. The shared activity controller does not by itself establish that all screen-owned timer state survives. Verify the existing session record restoration and background activity toggles as part of that lifetime change.

## Links to hidden and unavailable destinations

Preserve DeepLink's strict URL validation and keep routing in the host. After parsing and any required authorization, resolve through the compiled registry before mutating choices:

| Link target | Recommended result |
| --- | --- |
| Available and chosen, including overflow | Select it and open its valid route. Never change choices just because it currently sits in More. |
| Available but hidden by the user | Insert before Settings (or append if Settings is absent), persist visibility and select it as one coordinated update. Keep other relative ordering. Repeating the link must not duplicate it. This implements PR #147's reveal policy. |
| Recognized feature absent from this build | Keep valid choices, open the safe Home/default destination, and show a localized explanation that this feature is unavailable in this app configuration. Do not install modules, enable account capabilities or fabricate an empty destination. |
| Unknown destination or malformed URL | Ignore without changing choices/selection. A syntactically valid unknown host is not authority to create a tab. |

Keep a host-level list of recognized link IDs even when their feature enum cases are compiled out, so an unavailable known feature can receive the explanation. Nested links need validation of their own; the current parser deliberately rejects them. On cold launch, complete preference normalization before applying a queued link so restoration cannot overwrite it. Revalidate after onboarding or an authorization flow. Canceling authorization must not reveal content.

Apply exactly this route resolver to Live Activity URLs. Apple's [Launching your app from a Live Activity](https://developer.apple.com/documentation/activitykit/launching-your-app-from-a-live-activity) recommends opening the matching context through widgetURL or Link. The repository already supplies a Timer URL; test that it reveals a hidden Timer and that a stale activity URL in a build without Timer gets the explanatory fallback. Opening a URL must not restart or toggle a session. Actual activity pause intents are separate commands.

## Accessible overflow and reordering

Follow Apple's [accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility). Native controls provide a starting point; inspect their runtime accessibility tree. Keep spoken labels distinct from automation identifiers and expose selected/on/off state. VoiceOver traversal should follow the displayed order after every reorder, including More/All tabs and its rows. Preserve sensible focus after an item moves or disappears; keep Done, Back and Settings reachable.

Offer native list editing plus a non-drag method such as localized Move up/Move down buttons or [`accessibilityAction(named:_:)`](https://developer.apple.com/documentation/swiftui/view/accessibilityaction(named:_:)). Disable impossible moves at the boundaries and explain that Settings stays available. Verify the new order is announced and persisted using VoiceOver; a successful drag with touch is insufficient.

Support [DynamicTypeSize](https://developer.apple.com/documentation/swiftui/dynamictypesize) through accessibility5. Let chooser/editor rows wrap and scroll, keep touch targets at least 44 by 44 points, and avoid fixed row heights or clipped action labels. Verify long translations, right-to-left layout, contrast, Reduce Motion and Reduce Transparency. Do not use accessibility sort priorities to preserve the old order after visually reordering rows.

## Verification required before implementation acceptance

1. Add model tests for absent/malformed/versioned preferences; duplicates; unknown, hidden and uncompiled IDs; zero valid choices; mandatory Settings; defaults without Settings; stable `welcome` identity; newly added features; and idempotent normalization. Reorder preserves selection by ID. Removing the current tab repairs selection and persists it. Shared choices update open scenes without coupling independent scene selections.
2. Test URL rejection using the existing DeepLink cases, plus chosen/overflow/hidden/known-uncompiled/unknown targets, repeated reveal, cold launch, onboarding deferral and denied authorization. Assert both selected ID and stored order after relaunch. Cover Live Activity URLs through the same resolver.
3. Add same-PR XCUITests using the shared UITestLaunch harness and identifier constants. With at least six and then ten test-only destinations, open the final overflow destination, return, reorder it, hide the selected feature, reach Settings, reveal by URL and relaunch. Attach screenshots and assert visible content and selected destination, not just that a button exists.
4. Test each tab's pushed route and a dirty draft across switching, reorder, hide/show and relaunch. Start a real test timer; repeat edits while running and paused, then check elapsed time, completion, background restoration, activity toggles and unchanged saved content. Inject a draft save failure and confirm edits remain recoverable. Remove a referenced route object and check safe restoration.
5. Run relevant TabShell/host tests and UI scenarios on actual iOS 17 and 18 runtimes, 26 for its presentation, and the required iOS 27 lane. Exercise iPhone portrait/landscape and iPad full width, Split View and a narrow resized window, including regular-to-compact transitions while an overflow feature is selected. Record exact toolchains, runtimes, test counts and screenshots. A 27 pass establishes no 17 result. Use local Mac iteration where supported and the hosted compatibility workflow for remaining runtime lanes.
6. Audit VoiceOver traversal/activation and non-drag reordering, accessibility5, long localized labels and Settings reachability in those presentations. Use Accessibility Inspector plus manual assistive-technology checks; automated audits alone cannot establish usable reorder announcements. Run the pinned accessibility auditor before closing each visible implementation slice. Test minimal, fully enabled and relevant removed-module builds. No phone acceptance or build is required for this research-only document.

## Questions the implementation must settle

- Does native More preserve the selected binding, per-feature paths and Settings access on every supported SwiftUI presentation? No six-tab runtime evidence was collected here. Record the result before choosing between native overflow and the Browse fallback.
- Can native overflow expose reordering that competes with the host editor? If so, how will changes round-trip, or how will that interaction be constrained?
- Should iPad native customization ship in the first version? Recommendation: defer it until changes can round-trip through the shared host model; use the Settings editor everywhere initially.
- Does product acceptance require durable nested-route restoration after a force quit, beyond best-effort scene restoration? Recommendation: persist validated route IDs explicitly if that guarantee is required. Draft text and active sessions must be durable regardless.
- Confirm the proposed removal policy (discard unavailable choices without deleting content) and Settings position policy (movable, always included). Neither policy has shipped. A future requirement to remember temporarily unavailable choices needs a separate dormant-preferences field and migration tests.
