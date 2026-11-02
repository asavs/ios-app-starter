# Feature tabs for the starter app

Agreed with the owner on 2026-11-02. This is an implementation plan; the screens and tab chooser below have not shipped.

The app should offer useful screens a builder can keep in their own app. Each tab has a purpose: Home, Library, Notes, Timer or Settings. There is no Examples tab. More features can bring more tabs; people choose which ones they want during onboarding and can change that choice later.

## Screens and capabilities

| Tab | What a person does | Supporting capabilities |
| --- | --- | --- |
| Home | Open recent content and jump to enabled features | Theme, navigation, summaries from feature stores |
| Library | Collect, browse, search, preview and remove photos, files and links | Attachments, Database |
| Notes | Write, edit, search and delete notes; attach collected material | Database, Attachments when enabled |
| Timer | Configure and run sessions, save plans and follow the session outside the app | SessionTimer, TimerRing, DurationPicker, Cues, SessionActivity, optional Database |
| Settings | Set preferences, choose tabs, read privacy information and manage local data | Settings and each enabled module's settings contribution |

Database and Attachments support several features. Sounds, haptics and theme apply across the app. Live Activities belong to the running activity. None needs a separate tab just because it is a module.

Keep Timer's useful presets and attachments working. Library and Notes provide additional homes for persistence and attachments, so Timer no longer carries the whole demonstration. Feed and Chat remain future features: their existing research does not justify offering blank tabs.

The reusable template keeps its minimal essentials. The demo app can enable all implemented feature tabs, including Timer. Distinguish module inclusion in project.yml from a person's tab choices: hiding a tab never unlinks a package or deletes content. Build-time feature removal must still work. Keep new screen composition in the host app initially; extract another package only when reuse establishes its boundary.

## Delivery slices

Land one implementation PR at a time for shared shell, schema and manifest changes. Each slice includes its own meaningful checks; final acceptance is not a substitute for testing individual changes.

### 1. Feature availability and persistent tab choices

Introduce host-owned feature descriptors with stable IDs, localized names, symbols, build availability and defaults. Preserve the stored welcome identity when its label becomes Home. Store ordered choices independently of the last selected destination. Keep Settings reachable, normalize duplicate, unknown and unavailable IDs, and retain a usable destination when stored choices become invalid. A skipped first-run choice uses the app configuration's defaults. Do not surprise existing installations by automatically enabling every newly added feature.

TabSelection currently fixes its tabs at initialization and TabShell requires exactly matching ordered IDs. Extend that contract deliberately before wiring a changing list into it. Preserve per-tab navigation and drafts where possible; test selection restoration, reordering, removal and removed-module combinations. Define deep links to hidden features: reveal an available destination and persist its visibility; unavailable compiled features show a clear fallback rather than a blank screen. Apply that policy consistently to Live Activity links.

### 2. Session lifetime independent of tab presentation

Before enabling runtime tab changes, move active session ownership above the Timer screen's lifetime. Hiding or reordering Timer, switching tabs, or rebuilding the shell must not reset a running session. Hiding is navigation customization, not a stop command. Preserve pause, resume, completion, background restoration, screen-awake behavior and Live Activity toggles. Include the existing mid-session setting-toggle fix in regression coverage; coordinate with its open PR rather than replacing it.

### 3. Content schema and attachment ownership

Current main has shipped schema V1 and V2; V2 adds attachments to timer presets. Freeze both. Add the next schema and explicit migration stages for Library items and Notes, preserving existing presets, their attachments and seed markers. Cover installations with Database enabled both with and without Attachments. An incompatible configuration must offer recovery without silently erasing a store.

Define file ownership before linking notes to Library items. Use stable references to collected items; removing a note's reference does not delete the collected item. Before deleting a referenced Library item, explain the effect and offer cancellation. Remove originals only after the final owning record is removed successfully; failures must be recoverable. Extend Erase Local Data to new records, original files and caches. Hiding a feature must not erase or reseed data. Verify a real V2 store migrates with its contents intact, and cover V1 upgrade too.

### 4. Library

Build a standalone collection screen with import actions, browse/search, item details, preview and deletion. Reuse Attachments' existing pickers, previews and store. Persist metadata and references across relaunch. Include useful empty states, cancellation, denied permissions, missing files, failed imports and retryable errors. Camera and external-provider behavior that cannot run on the simulator gets an explicit phone check; deterministic UI scenarios exercise the corresponding fake paths without accessing ordinary user data.

### 5. Notes

Build a plain-text notes list and editor with create, edit, search, delete and relaunch persistence. Handle draft lifetime, navigation and visible save failures. Add attachment references using the ownership rules from slice 3; text-only notes still work when Attachments is removed. Keep Notes and Library distinct: authored text belongs to Notes; collected files and links belong to Library.

### 6. Choose tabs in Settings

Offer enabled feature choices and reordering using slices 1 and 2. Settings remains reachable. Hiding preserves data and active sessions; bringing a feature back restores access. Check several destinations, an invalid saved selection, a hidden-tab deep link, a running timer and unsaved note text. The same choice model will support onboarding.

### 7. Choose tabs in onboarding

Add an optional Choose your tabs step using the same available-feature list and persistence as Settings. Describe each feature in one short sentence. Skipping uses defaults on a new installation and preserves an existing choice on replay. Merely opening or replaying onboarding must not overwrite choices. Only implemented, compiled features appear. Do not force existing users through onboarding again solely because this step was added.

### 8. Home

Replace the greeting placeholder with recent Notes and Library content and shortcuts to enabled features. Show truthful empty states with create/import actions; no fabricated activity or counts. Hide unavailable features and respect tab choices. Keep tour replay reachable. Reuse feature queries rather than inventing another content store.

### 9. Navigation scale and device acceptance

Exercise six or more destinations with test-only destinations until enough real features exist. Verify native overflow or an equivalent accessible destination chooser on iPhone and an appropriate iPad arrangement. Do not assume the existing shell handles many tabs correctly across all supported runtimes. Every chosen feature must remain reachable, including after reordering, narrow-window changes and relaunch.

Each visible slice needs the pinned accessibility audit, localization, VoiceOver labels and order, largest Dynamic Type, adequate contrast and touch targets. Add deterministic UI scenarios using the shared harness and identifiers, including screenshots of the main paths. Test the minimal template and enabled demo, plus relevant removed-module combinations. Regenerate the checked-in Xcode project on a Mac or hosted runner whenever project.yml changes. Inspect actual hosted test results and distinguish minimum-OS coverage from newer-runtime results. Keep required CI near ten minutes; use targeted local simulator iteration and the existing CI improvement work.

## Dependencies and first work

Feature availability and session lifetime can be designed separately, but tab customization waits for both. Content schema precedes Library and Notes; serialize their schema edits. Settings selection precedes onboarding selection. Home follows real feature data. Navigation-scale verification belongs in the shell slice and is repeated in final device acceptance.

Start by finishing the existing CI and Live Activity fixes, then preserve Timer in the demo while removing its default-template dependency. Build slices 1 through 3 next, followed by Library, Notes, Settings selection, onboarding selection and Home. Carry forward existing accessibility fixes; do not bury them inside a broad redesign. Release and phone delivery follow the existing workflow after visible work passes its checks.
