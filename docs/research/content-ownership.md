# Library and Notes: migration and file ownership

Built as: `StarterSchemaV3` and `StarterSchemaText2` in StarterApp/StarterApp/Data/StarterSchema.swift, `ContentCoordinator` for ownership and cleanup, `ResetJournal` for Erase Local Data, with the authentic V1 and V2 fixtures under StarterApp/StarterAppTests/Fixtures (2026-11-03, task ios-125.3; journal entry of that date). The rest of this document is the research as written on 2026-11-02 against iOS 17 API availability, before that implementation.

Recommend an additive next schema, app-owned UUID references from Notes to Library, and one app coordinator for record mutations and file cleanup. Preserve shipped V1 and V2, including their attachment encoding and seed markers. Commit record removal before deleting an original; persist enough cleanup intent to retry after a crash. Hiding a tab changes navigation only.

This extends [database research](database.md) and [attachment research](attachments.md), without replacing their container, picker or preview guidance. The feature scope comes from [the feature-tabs proposal, PR #147](https://github.com/asavs/ios-app-starter/pull/147/files), reviewed at `8842cd55c654248041998780a5dd80fb4c9dff50`. That PR was open at initial inspection; it subsequently merged into `main` at `12c7ee8` while this draft was being prepared. Its schema and ownership constraints remain the basis for this recommendation.

## Shipped constraints

Source inspection used `main` at `101cb2818ba62f6fea54222663e659598cf7d473`:

| Source | Observed behavior and consequence |
| --- | --- |
| [StarterSchema.swift](../../StarterApp/StarterApp/Data/StarterSchema.swift) | V1 contains TimerPreset (name, plan, work, rest, rounds, createdAt) and Database.SeedMarker. With Attachments, V2 adds `attachments: [Attachment] = []` and a lightweight V1-to-V2 stage. Without Attachments the app still opens V1 with no stages. These are different supported store histories. |
| [StarterDatabase.swift](../../StarterApp/StarterApp/Data/StarterDatabase.swift) | Uses the same `StarterApp` store location across those builds; `presets.v1` seeds two presets using a durable marker. Preserve marker key and date even when the person deleted every preset. |
| [Attachment.swift](../../Modules/Attachments/Sources/Attachment.swift) | A Codable value holds UUID, kind, display name, type, byte count, creation date, relative path and optional link URL. It is metadata, not a SwiftData relationship or ownership counter. V2 depends on this encoding as well as the model definition. |
| [AttachmentStore.swift](../../Modules/Attachments/Sources/AttachmentStore.swift) | Copies originals under Application Support; thumbnails and link archives live under Caches, keyed by attachment UUID. `remove` deletes the original before caches and can fail partway. `sweep(keeping:)` deletes UUID-named files absent from the supplied set; it has no database knowledge or protection for imports in progress. |
| [TimerPresetAttachmentsView.swift](../../StarterApp/StarterApp/Timer/TimerPresetAttachmentsView.swift) | Removing a value launches file deletion with `try?`; save errors are also discarded. A failed save can leave a persisted reference to a deleted file. This is a source-derived failure path, not a reproduced incident. |
| [TimerPresetsView.swift](../../StarterApp/StarterApp/Timer/TimerPresetsView.swift) | Deleting a preset saves with `try?` and does not clean its files. The next implementation must include Timer in ownership accounting. |
| [StarterLocalData.swift](../../StarterApp/StarterApp/StarterLocalData.swift), [StarterAttachments.swift](../../StarterApp/StarterApp/Data/StarterAttachments.swift) | Reset removes attachment directories before the appended database step. Settings' LocalDataReset continues through failures. Reordering independent steps alone cannot make this operation recoverable. |
| [SchemaMigrationTests.swift](../../StarterApp/StarterAppTests/SchemaMigrationTests.swift) | Creates a V1 disk store using today's frozen type, upgrades, then round-trips a link through a second context in the same container. It does not open an authentic released V2 fixture, verify original bytes, preserve a seed marker, or reopen in another process. |

Database.SeedMarker is a shared module model referenced by both historical schemas. Freeze its persisted shape too; editing it or Attachment's Codable representation can change the effective historical schema without touching the V1/V2 declarations.

## Next schema and migration paths

Apple describes ordered versioned schemas and explicit lightweight or custom stages in [Model your schema with SwiftData](https://developer.apple.com/videos/play/wwdc2023/10195/). [MigrationStage](https://developer.apple.com/documentation/swiftdata/migrationstage) is available from iOS 17. The following is a proposed design; successful inference and preservation require the disk tests below.

For **Database and Attachments enabled**, add a media-capable V3 containing:

- An unchanged V2-shaped TimerPreset and the unchanged SeedMarker. Do not move existing preset attachments into Library during migration.
- LibraryItem with an app UUID, title, created/modified dates and one Attachment value. Preserve the attachment UUID and relative path if an existing attachment is deliberately collected later. A URL remains durable metadata even when its preview cache disappears.
- Note with an app UUID, title, plain-text body and dates.
- NoteLibraryReference with its own UUID, note UUID, LibraryItem UUID and ordering value. These are app-level references; do not copy an Attachment payload into each note. The app validates targets and deletes reference rows explicitly. No cascade from a note or reference to LibraryItem.
- PendingAttachmentDeletion carrying the complete Attachment metadata needed by `remove`, plus retry state. It is cleanup intent, not a live owner. This belongs in the next schema from the start so deletion recovery does not require another schema release.

Give new attributes defaults or make them optional where appropriate. Keep IDs stable after insertion, validate collisions, and save explicitly. Avoid model inheritance, newer indexing/uniqueness macros and history APIs as requirements for iOS 17. If ordinary SwiftData relationships replace UUID joins, specify inverses and delete rules, and test them on iOS 17 before adoption; default nullification does not implement the ownership policy.

Keep the existing `V1 -> V2` stage and append a candidate lightweight `V2 -> V3` stage. The new tables start empty. There is no content backfill or new sample-content seed to run. A direct V1 upgrade traverses both stages. If the actual generated schema requires transformation, stop and introduce a tested custom/intermediate stage; never edit V1 or V2 to make it pass. Keep file operations and network requests outside migration callbacks.

For **Database enabled, Attachments absent**, add a separately identified text-only successor to V1 with Note and unchanged TimerPreset/SeedMarker, and a candidate lightweight `V1 -> next text schema` stage. It must compile without importing Attachments. Library and attachment-reference creation are unavailable; Notes remains useful. Do not define a smaller model set under the media V3 identity or pretend the existing V2 type compiles without its module.

The first implementation should support these two explicit histories independently. Opening a V2/media store in a text-only build, or a new text-only store in a media build, remains an unsupported configuration transition until a separate bridge is tested. Keep the same store location and show recovery, rather than silently opening a new empty file. Restoring a compatible build must still find the old data. A future requirement for seamless module switching needs an app-owned compatibility payload and bridge schema; changing V2's Attachment type in place is unsafe. Runtime tab hiding never selects a different schema.

## Record ownership and deletion

LibraryItem owns its Attachment; TimerPreset owns each value in its attachment array. A NoteLibraryReference is a non-owning link to a LibraryItem. Deleting a note removes its reference rows and text, leaving collected items intact. The initial Notes UI should collect an imported attachment into Library before linking it; private note-only files would require another explicit owner category.

Use the LibraryItem UUID for links across edits and relaunch, not a list index, title, file URL or unsaved SwiftData identifier. Enforce one reference per note/item pair through the app's serialized mutation path. A missing target is an integrity error with a visible unavailable-item state; it must never resolve to a different item with the same name.

Deleting a referenced Library item first counts references and explains the effect: for example, “Used in 2 notes. Deleting this item removes it from those notes. Their text stays.” Offer Cancel and Delete. Cancel performs no mutation. On confirmation, recheck references under the coordinator, remove the item and its reference rows, and save together. Preserve the notes' text. Any Timer attachment owning the same attachment UUID remains intact. If undo or retention is added later, retained originals need to count as owners until that period expires.

Use a coordinator on the app's model-context isolation domain. Pass Attachment values to AttachmentStore's actor, never ModelContext or model objects. All imports, owner changes, cleanup and reset must go through this coordinator; the file-store actor alone cannot serialize a database save with file deletion.

1. Before removal, compute owners across **all persisted** Library items and preset attachments, including hidden features. If the last owner will go, insert PendingAttachmentDeletion in the same explicit save as the record change. A failed save leaves files untouched, restores the editing context or preserves the draft for retry, and shows an error. [ModelContext.save()](https://developer.apple.com/documentation/swiftdata/modelcontext/save()) writes pending inserts, changes and deletes and can throw.
2. After save succeeds, process pending entries. Recheck committed owners before removing any original. Prevent new ownership of that UUID while deletion is executing; cancel its pending entry if it acquires an owner before execution. Coordinator serialization must cover actor suspension points, for example through an explicit operation queue.
3. Call `AttachmentStore.remove`. On success, remove and save the pending entry. If removal fails after the original or some cache files were removed, retain the entry and show retryable cleanup failure. On relaunch retry the remaining paths. Missing paths count as already cleaned; do not recreate an owner for a missing original. [FileManager.removeItem(at:)](https://developer.apple.com/documentation/foundation/filemanager/removeitem(at:)) can throw; it provides no transaction with SwiftData.

This recovery means retrying unfinished deletion, not restoring an original already deliberately deleted. If saving removal of a completed pending entry fails, retrying it must be harmless. Never reuse deleted attachment UUIDs. Existing shared IDs must resolve to identical metadata/path; quarantine conflicts for diagnosis rather than guessing which bytes to delete.

Import has the reverse crash window: the file exists before its owner saves. Register in-flight attachment IDs, keep them out of cleanup, and persist the owner before reporting success. Failed saves retain the draft and bytes for retry or explicit cancellation. For a crash before ownership saves, reconcile leftover UUID files only after a successful store open and complete owner fetch, with no imports or reset in progress. Prefer recoverable quarantine before permanent orphan removal; define the retention policy before shipping it. Do not apply a time delay alone as proof a file is unowned.

If using `sweep(keeping:)`, supply the union of every committed owner's attachment IDs and protected in-flight IDs. Never sweep after a failed fetch, during migration, in database recovery, or from the visible tab's query results. Pending deletion retries handle their own errors. The current sweep stops on a thrown removal and does not report every partial result; retain reconciliation intent and rerun safely. Validate stored relative paths against the attachments root before destructive operations. Unknown files and invalid metadata require an explicit policy, not a broader recursive sweep.

## Erase Local Data and recovery

Extend the host's reset coordinator to cover Notes, Library, reference rows, presets, SeedMarkers, cleanup entries, original attachments, thumbnails, link metadata and app-created import/preview/quarantine files. Include these even when their tab is hidden. Imported source documents and the person's Photos library are outside this erase operation.

Persist a reset-in-progress journal under app support before changing stores, outside the database being erased and outside defaults that reset wipes. Block new edits, imports, cleanup and seeding. Clear unsaved model contexts/drafts so autosave cannot resurrect records. Erase database records first and verify the store is empty; then remove the app-owned originals and caches. Retain the journal if either phase fails or the app terminates, expose the incomplete phase and retry on relaunch. Do not report success while files remain. Clear the journal only after verification. Settings, Keychain and tips can keep their separate reset reporting, but the content phase needs dependency-aware orchestration.

Apple's [deleteAllData()](https://developer.apple.com/documentation/swiftdata/modelcontainer/deletealldata()) permanently removes persisted model data and is available on iOS 17. Its documented signature does not throw; the current Database.erase wrapper's throwing signature alone is no evidence it detects a failed erase. Verify emptiness and fault behavior, or use explicit throwing record deletions/saves if the implementation needs observable failure. Neither route erases AttachmentStore files automatically.

After a completed explicit reset, the current app intentionally seeds `presets.v1` again on its next fresh launch. Preserve that behavior unless product review changes it. Library and Notes start empty. Tab hide/show and onboarding replay must never erase markers, call reset or trigger an empty-table seed.

An incompatible or corrupt store enters DatabaseGate recovery: Retry keeps the same files; Cancel leaves them; destructive Start Over needs explicit confirmation. Keep originals and sidecars, suspend seeding and sweeping, and explain which compatible build can reopen a known unsupported configuration. Do not promise that a failed migration changed no bytes: the current recovery copy says this, but no rollback guarantee has been established. Any backup/restore must be a verified consistent store snapshot with WAL/SHM and matching originals, taken while writers are quiescent. Start Over currently removes only database files; route a whole-content reset through the coordinator with an accurate scope message. Offer preservation/export only once a safe implementation exists.

Keep originals and the reset journal in durable app support. Caches and temporary previews must be disposable. Apple's [backup guidance](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup) excludes Caches/tmp by default and says arbitrary imported files should remain backed up because people may be unable to recreate them. Cache loss must not remove metadata or trigger an automatic network fetch for every link.

## Verification required before implementation can ship

These are acceptance requirements, not completed checks. Use the existing isolated test harness; a reset launch must never erase an upgrade fixture before it opens.

| Check | Required evidence |
| --- | --- |
| Authentic V2 upgrade | Use a pinned released V2 app/build to write a disk fixture with multiple presets, non-default times, fixed dates, `presets.v1` key/date, photo/file/link metadata and actual original bytes. Include deleted seed presets and an empty attachment array. Record writer commit, configuration, OS, schema and file hashes. Stop the writer; retain a consistent store and sidecars with its attachment root. Synthetic fixtures from today's frozen types supplement this evidence. |
| V2 to media V3 | Upgrade a copy without resetting. Assert every preset field, attachment field/UUID/path, seed marker, original hash and preview readability. New content tables must be empty. Relaunch in a separate process, recheck, add/edit content and relaunch again. Running seeding must not recreate deleted presets. Keep the untouched source fixture. |
| V1 upgrades | Write an authentic V1 fixture with a marker and deleted samples. Test direct V1-to-latest media, sequential V1-to-V2-to-V3 and V1-to-next text schema. Check all preset fields, marker dates, empty default attachments where applicable, save/relaunch and absence of duplicate seeds. |
| Optional modules | Build/test Database with Attachments absent and with both present. Test an unsupported V2/media store in the text build, text store in the media build, unknown newer schema and corrupt store. Each must retain data, avoid seeding/sweeping and offer recovery. Restore the writer-compatible build and prove it can reopen an incompatible-configuration fixture. |
| Ownership | Two notes reference one Library item; rename and relaunch without breaking links. Remove a reference/delete a note and verify the item and bytes remain. Cancel a referenced-item deletion, then confirm it: references disappear, note text stays. A preset sharing the attachment keeps its original until its own final ownership is removed. |
| Failures and concurrency | Inject save failure before deletion, original/cache removal failures, cleanup-entry save failure, failed owner fetch and crashes between each phase. Retry/relaunch must finish safely without deleting any owned file. Race import against sweep, and relinking against queued deletion. Test duplicate IDs, missing originals, cache purge and invalid paths. |
| Reset and hiding | Populate every owner type and cache, hide all content tabs, confirm reset and verify no old records or files remain after relaunch. Inject failure/termination at each reset phase and verify journal recovery before seeds/imports resume. Cancel must change nothing. Hide/show tabs and replay onboarding with data present and with intentionally empty collections; neither erases nor reseeds. |

Run targeted disk and UI scenarios on an actual iOS 17 runtime and current supported runtimes, naming OS/toolchain in the evidence. The required iOS 27 CI lane cannot establish iOS 17 preservation. Include XCUITests using accessibility identifiers and screenshots for reference removal, deletion confirmation/cancel, failure/retry and erase. Run the pinned accessibility audit on those visible flows; camera and provider-specific import acceptance belongs to the later feature/phone checks. Windows source review and API availability checks here establish no runtime migration coverage.

## Questions to settle during implementation

- Is seamless switching of compiled Attachments support required for an existing installation? The safe initial boundary above blocks it. Supporting it requires a bridge design and authentic fixtures for both directions, without changing historical models.
- Confirm that deleting a collected item removes its note references while preserving note text, and whether deletion needs an undo/retention period. Retention changes when the last owner releases bytes.
- Choose orphan quarantine retention, storage limits and the recovery action for conflicting IDs or missing originals. No automatic destructive policy is established by this research.
- Obtain the released V1/V2 writer revisions and fixtures; the existing migration unit test does not provide them. Decide whether an export/restore feature belongs in scope before promising it in recovery copy.

Apple links above were checked on 2026-11-02, using WWDC transcript and documentation Markdown endpoints where the HTML required JavaScript. Apple documents API contracts and availability; the migration, ownership coordinator and reset journal described here are repository-specific recommendations awaiting implementation and failure testing.
