# Database module research

Checked 2026-10-27. Source grades: A = Apple documentation or first-party code; B = practitioner experiment or maintained implementation; C = anecdote. A describes the contract, not proof of every OS implementation. Recommendations are design judgments, not tested code.

## Recommendation

Build an optional SwiftData scaffolding module for iOS 17+, but keep each app's models, schema history, seed content, and migration decisions in that app. A generic package cannot know the complete schema or safely own another app's migrations. Provide a small throwing container factory accepting the app's schema, migration plan and explicit persistent/in-memory configuration; inject the resulting container at the app root. A failed open must surface a recoverable error and retain the files, never delete a store to recover. Settings remain in UserDefaults and Keychain, as already implemented by Settings; neither secrets nor simple preferences belong in the model store.

Start V1 as a `VersionedSchema` with a `SchemaMigrationPlan` listing V1 and no stages. Freeze each shipped schema, add a distinct V2 and stage when it changes, and retain all older versions. Apple demonstrates an ordered plan, a custom deduplication before a uniqueness change, and a lightweight rename using original-name metadata ([WWDC23, A](https://developer.apple.com/videos/play/wwdc2023/10195/)). A plan alone cannot guarantee preservation; every actual change needs a working migration and tests. Avoid claiming an empty stage guarantees recognition of every pre-versioned store.

## Stores, seeds and tests

Use one configuration choice at composition time for disk versus memory; previews and UI tests should get a fresh in-memory container. Apple's example explicitly inserts and saves sample models in a preview container ([sample-data tutorial, A](https://developer.apple.com/tutorials/develop-in-swift/navigate-sample-data/)). Memory tests cannot prove disk migration. Persistent seed data is app-specific: use stable identifiers and a marker stored in the same transaction as inserts, save explicitly, and make retries idempotent. Do not interpret an empty user collection as first launch: users may intentionally delete everything. Decide whether sample content is opt-in and how a restored store or eventual CloudKit merge handles duplicates. Cross-device once-only seeding is not guaranteed by a local marker.

For each released version, create an on-disk fixture with that version's actual app/schema, including relationships, optional values, deleted records and representative user data. Open a copy with the new app, assert values, counts, relationships and delete rules, close and reopen, and test direct upgrades from each supported version as well as sequential upgrades. Test failed opens, interrupted/backfill retries and duplicate seed prevention; retain the original fixture. Run on iOS 17 and current supported runtimes. In-memory unit tests complement these checks. Test migrations before releasing, not by resetting simulators after a failure.

## Migration limitations

Lightweight migration covers changes SwiftData can infer; it is not a blanket promise for a type conversion or arbitrary relationship rewrite. Use a custom stage when data requires transformation, respecting the old/new schema available in each callback, and consider intermediate schemas for changes needing both shapes. An independent experiment reports a throwing `didMigrate` can leave the schema upgraded without retrying the backfill; treat this as an OS-specific report to reproduce, not an Apple guarantee ([Jerry Zhang, B](https://zhangjipeng.com/post-swiftdata-cloudkit-sync.html)). Make post-migration repair idempotent and independently detectable. Developers report unknown-model-version errors when introducing a staged plan after release ([forum discussion, C](https://www.reddit.com/r/SwiftUI/comments/1d46e0t)); preserve real released fixtures to establish whether a transition works.

## CloudKit later

Model v1 conservatively if sync is plausible: avoid uniqueness constraints, give attributes defaults or make them optional, make relationships optional and define inverses and delete behavior. Apple's Core Data/CloudKit restrictions document no unique constraints and warn production fields cannot be removed or renamed ([model constraints, A](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit)). The pinned SwiftData skill adds optional relationships and defaults; validate the actual SwiftData schema on each supported OS and with a development CloudKit container before promising sync. Design for eventual consistency, duplicates, offline and signed-out states; local uniqueness and a one-time seed cannot enforce global uniqueness. Sync requires entitlements, a container and production schema deployment, plus explicit user and account setup ([deployment, A](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema)). Adding it later still needs migration and multi-device tests; compatible fields do not guarantee a seamless switch.

## Alternatives

Core Data wins for existing stores, mature mapping models, older deployments or capabilities the chosen SwiftData version cannot meet; Apple describes incremental coexistence ([WWDC23, A](https://developer.apple.com/videos/play/wwdc2023/10189/)). GRDB/SQLite wins when explicit SQL, transactions, query control or portable SQLite files dominate; its `DatabaseMigrator` tracks ordered named migrations ([source, B](https://github.com/groue/GRDB.swift/blob/master/GRDB/Migration/DatabaseMigrator.swift)). It adds a dependency and requires an independently designed synchronization strategy. Neither alternative should be added without an app need. SwiftData is the default, not a promise that all migrations or CloudKit use cases are solved.

A practitioner demonstrates an intermediate schema and separate seed, upgrade and reopen processes, and cautions that reconstruction of an unversioned release is not an authentic fixture ([The Swift Dev, B](https://www.theswift.dev/posts/migrate-swiftdata-values-with-an-intermediate-schema/)). Its results need reproduction on the app's actual supported OS versions. Apple's 2025 inheritance examples apply to newer SwiftData releases, so do not infer their availability on iOS 17 ([WWDC25, A](https://developer.apple.com/videos/play/wwdc2025/291/)).

## Candidate API and demo

A workout history, reading log and inventory app could all use container setup without sharing their domain models. Sketch only, not compiled Swift:

```swift
Database.open(schema: Schema, migrationPlan: (any SchemaMigrationPlan.Type)?,
              storage: Storage, cloud: CloudPolicy) throws -> ModelContainer
// Storage: persistent(url: URL), or memory. CloudPolicy defaults to disabled.
Database.preview(schema: Schema, seed: (ModelContext) throws -> Void) throws -> ModelContainer
```

The app supplies its exact schema, migration plan, store location, and explicit CloudKit configuration. The module should preserve configuration identity and support injection, not secretly combine unrelated models or infer migration stages. Seed through a separate app-owned `seedIfNeeded(context:)` using a durable marker saved with the data. Expose errors with enough context for recovery without private data. The preview factory is memory-only and runs its supplied seed exactly once per created container. Main-context isolation and SwiftData initializer signatures must be verified in implementation; the sketch is a contract, not production API.

The demo can add and edit a sample record, restart to show persistence, and use a separate in-memory preview. Its tests exercise a fake seed and store-open failure, while migration fixtures belong to the app that owns schemas. Theme styles views; Settings continues to own UserDefaults and Keychain. An app can omit Database, Theme or Settings independently.

## Open-source implementations and test evidence

| Project | What it demonstrates and limitations | License |
| --- | --- | --- |
| [Strata](https://github.com/GRimAce11/Strata) | A declarative migration layer advertises fixture tests, dry runs, backup and rollback. Its safety assertions are project claims, not independently validated here; snapshot consistency with SQLite WAL, failures and CloudKit require review before any adoption. | MIT, B |
| [swiftdata-migration](https://github.com/tungvt-it-92/swiftdata-migration) | Small versioned-schema upgrade/downgrade example with `DataMigrationTests`; a useful comparison of explicit stages and assertions. Its README alone does not establish old shipped binaries or multi-runtime disk fixtures; inspect and run tests before relying on them. | Apache-2.0, B |
| [GRDB.swift](https://github.com/groue/GRDB.swift) | SQLite library with explicit named migration infrastructure; useful alternative when explicit SQL and transaction control outweigh native SwiftData integration. Does not provide SwiftData/CloudKit migration. | MIT, B |
| [Apple Core Data/SwiftData sample](https://developer.apple.com/documentation/coredata/adopting-swiftdata-for-a-core-data-app) | Demonstrates a shared store during incremental adoption, with persistent history configuration. This is a coexistence example, not proof arbitrary model changes migrate. Check sample license on download. | Apple sample terms, A |

[The Swift Dev's migration experiment](https://www.theswift.dev/posts/migrate-swiftdata-values-with-an-intermediate-schema/) uses separate seed, upgrade and reopen processes, an intermediate schema and disk persistence; it explicitly says compilation is not an iOS runtime migration test (B). Prefer this test shape to an in-memory-only test. No production-app migration fixture suite was independently executed during this research.

## Runtime and compiler risks to test

| Environment | Evidence | Decision |
| --- | --- | --- |
| iOS 17 | SwiftData and versioned plans began here ([WWDC23, A](https://developer.apple.com/videos/play/wwdc2023/10195/)). Reports of unknown schema versions when adopting plans later are anecdotes without a general fix ([report, C](https://www.reddit.com/r/SwiftUI/comments/1d46e0t)). | Build fixtures with the exact shipped schema and run the actual upgrade on iOS 17; do not recreate a guessed old model. |
| iOS 18 | Apple introduced custom data stores and history in this generation ([WWDC24, A](https://developer.apple.com/videos/play/wwdc2024/10137/)). An [iOS 18 report](https://developer.apple.com/forums/thread/805865) describes migrated objects not persisting (C), without a confirmed universal cause. | Keep 18-only features optional, and reopen after migration to verify persisted values. |
| iOS 26 | Apple's 2025 session covers inheritance and schema evolution ([WWDC25, A](https://developer.apple.com/videos/play/wwdc2025/291/)). A [developer forum report](https://developer.apple.com/forums/thread/808442) describes container initialization failures on both 18 and 26 under particular schema changes (C). | Test real old stores on 26 and inspect full errors; do not extrapolate a fix or claim all apps are affected. |
| Swift 6 toolchain | Developers reported `Sendable` diagnostics in migration declarations with older SDKs ([Swift Forums, B](https://forums.swift.org/t/swiftdata-schemamigrationplan-and-versionedschema-not-sendable/75731)). Compiler/SDK availability is distinct from runtime compatibility. | Compile on the pinned Xcode and test each runtime. Do not add unsafe concurrency annotations without verifying the present SDK. |

These are reports and availability distinctions, not a tested matrix. Test a copy with sidecar files and a consistent checkpoint; do not copy a live SQLite file alone and assume its WAL is included. Any backup or rollback design needs its own interruption and file-protection tests.
