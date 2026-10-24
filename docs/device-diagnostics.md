# Investigate app failures and check OS coverage

Start with the installed build, device OS and [tester feedback](tester-feedback.md) when your app fails on a phone. You can read TestFlight feedback from Windows with the fixed CLI reader or App Store Connect, then turn actionable reports into sanitized issues. The repository has no hosted symbolication job or crash-report reader; possible follow-ups are listed below.

For OS compatibility, use the simulator matrix's actual results. The weekly matrix verified the smoke test on iOS 17.0.1, 18.1, 26.0.1 and 27.0 on 2026-10-16 ([run 38974328806](https://github.com/asavs/ios-app-starter/actions/runs/38974328806)). TestFlight preflight also checks that the archive app and its debug symbols have matching UUIDs.

## What can be used now

### TestFlight feedback and crash submissions

TestFlight testers can submit screenshot feedback, general comments, and crash feedback from the TestFlight app. In App Store Connect, an authorized user can filter screenshot/crash feedback by platform, version, build, OS version, and device, then download a ZIP with the screenshot or crash report and comments. Apple's help says crash feedback downloads are available for 120 days; a tester app becoming unresponsive does not guarantee a crash report is included. See [View tester feedback](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-tester-feedback) and [TestFlight](https://developer.apple.com/testflight/).

The upload policy sets `uploadSymbols=true`, which asks Xcode to upload debug symbols with the TestFlight build. These symbols let a crash report show function names instead of addresses; this is called symbolication. Apple may symbolicate reports using the uploaded symbols.

By default, the release workflow retains only sanitized reports for seven days. It uploads no `.xcarchive`, `.dSYM`, crash report or IPA to GitHub artifacts, and removes its temporary archive/export after delivery. Optional private-repository [symbol retention](#implemented-symbol-check-and-retention) keeps matching dSYMs for later investigation. Without it, this repository has no exact-build archive/dSYM to download later.

The manifest does not explicitly set `DEBUG_INFORMATION_FORMAT`. Confirm that the generated Release configuration produces DWARF with dSYM before relying on symbolication. Apple ties dSYMs to binary UUIDs and says to retain each distributed build's archive. See [Building your app to include debugging information](https://developer.apple.com/documentation/xcode/building-your-app-to-include-debugging-information) and [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases).

### Pinned App Store Connect CLI

The ignored `App-Store-Connect-CLI/` reference checkout is version 5.14.0. Its documentation describes reads for TestFlight crash submissions/logs (`asc testflight crashes list|view|log`), tester feedback including screenshot URLs (`asc testflight feedback list|view`), and App Store Connect performance data (`asc performance overview|metrics list|view`). The documented crash filters include device model and OS version.

The reference checkout is not an integrated dependency. The starter uses a pinned release binary through reviewed wrappers; `scripts/apple-doctor.py` allows only narrow Apple setup reads. No crash, feedback or performance API call was made during the original command-documentation review. That review alone established no account access, role permissions, endpoint behavior, available data or supported template command. The fixed feedback reader was implemented and verified separately; see [tester feedback](tester-feedback.md).

To add another read operation, use a fixed, reviewed wrapper subcommand. Do not pass arbitrary CLI text through. Reuse the pinned installer/checksum and isolated credential wrapper. Authenticated reads need explicit opt-in; sanitize upstream output and distinguish denied, incomplete, empty and skipped responses. The CLI also documents feedback/crash deletion, which is outside diagnostics scope. Recheck the pinned docs and help before promising a new operation.

App Store Connect analytics/performance data is an aggregate service with filters such as build and device type where supported, and availability depends on Apple's data and privacy thresholds. It is not a live per-device trace or guaranteed immediate report. Apple's [Analytics overview](https://developer.apple.com/help/app-store-connect-analytics/) notes that some quality/usage data requires sufficient volume and opted-in diagnostics sharing.

### MetricKit (optional app feature)

MetricKit is a separate, future app capability. Apple describes daily aggregated performance payloads and diagnostic payloads delivered to an app on physical devices; it does not make simulator smoke tests equivalent to a device fleet. Shipping a MetricKit subscriber, deciding what payloads to persist/transmit, and obtaining a backend/consent/privacy design are not implemented. It should remain optional and independent of the basic app. See [MetricKit updates](https://developer.apple.com/documentation/updates/metrickit), [MXMetricPayload](https://developer.apple.com/documentation/metrickit/mxmetricpayload), and [MetricManager](https://developer.apple.com/documentation/metrickit/metricmanager).

## Symbolication path

1. Keep symbols enabled in the reviewed TestFlight export policy and verify the Release archive has matching dSYMs for the app, extensions, and included frameworks. A dSYM from another build or Xcode build is not interchangeable; compare UUIDs.
2. Retain the exact archive or at least its dSYMs by build number in access-controlled storage with a documented retention period. Do not put signing credentials or private key material in the artifact. The current workflow deletes the archive, so retention needs an explicit, reviewed change.
3. A tester submits crash feedback; retrieve the report via App Store Connect UI or, after verifying the pinned CLI/API behavior, a fixed authenticated read command. Associate it with app version, build, device model and OS version.
4. Apple may deliver an already symbolicated TestFlight crash report when upload symbols are available. For local investigation from Windows, download the report and matching dSYMs and use a reviewed hosted macOS symbolication job (`xcrun crashlog`/Xcode) that returns only a sanitized report. Xcode/device OS symbols may also be required to symbolicate operating-system frames. No such download/symbolication workflow exists today; users do not need a separately managed Mac, but the symbolication job needs hosted macOS and a carefully scoped artifact handoff.

See Apple's [crash report symbolication guide](https://developer.apple.com/documentation/xcode/adding-identifiable-symbol-names-to-a-crash-report). TestFlight's tester crash feedback is distinct from App Store Connect's broader aggregate crash/performance analytics and from reports users may separately export from device settings.

## OS coverage and claims

Keep these settings and results separate:

| What | Setting or recorded result |
| --- | --- |
| App and test deployment minimum | iOS 17.0 |
| Selected CI toolchain | Xcode 27.0 / iOS 27.0 SDK |
| Required simulator checks | iOS 27.0 |
| Verified smoke-test runtimes, 2026-10-16 | iOS 17.0.1, 18.1, 26.0.1 and 27.0 |

A deployment target declares supported OS versions; it does not prove the app ran on them. An iOS 27 simulator test does not verify iOS 17 behavior. A physical phone result covers only that phone's OS.

The `iOS compatibility matrix` workflow (`.github/workflows/ios-compatibility.yml`) inventories each hosted image. `scripts/plan-compatibility-matrix.py` pairs available runtimes with a Swift 6-capable Xcode on that image. Each pairing runs the app's UI checks, and `scripts/report-compatibility.py` combines the results into a report naming only passed runtimes.

The 2026-10-16 inventories found iOS 17.0.1, 17.2, 17.4, 17.5, 18.1 and 18.2 on `macos-14` (Xcode 16.1/16.2 for Swift 6); 18.5, 18.6 and 26.0.1–26.2 on `macos-15`; and 27.0 on `xcode-27`. Hosted images change and retire, so each run plans from its own inventory. Record the actual runtime, device and test results. Check [current Xcode system requirements](https://developer.apple.com/xcode/system-requirements) and installed simulators before selecting test configurations.

## Conditional diagnostics backlog

The [archived shared plan](archive/mac-windows-coordination.md) records the original feedback and diagnostics sequence. The feedback reader and simulator matrix now exist. Add symbol storage, more CLI operations or performance collection when an investigation shows a need. Keep each change reviewable and verify it separately:

1. **Release symbol production and retention:** inspect current generated Release settings and archive UUIDs; explicitly set DWARF with dSYM if needed; retain exact-build dSYMs/archive under access controls and documented retention; confirm exported/uploaded symbols match.
2. **Additional TestFlight exports:** the fixed screenshot-feedback reader is documented in [tester feedback](tester-feedback.md). Add fixed pinned-CLI reads for crash feedback and logs only when needed. Require explicit opt-in, pagination/filters, sanitized artifacts, and tests for no credentials, access errors, empty results, malformed responses, timeout and redaction. First verify the pinned CLI 5.14.0 commands and Apple role/API behavior with an authorized account; implementation alone does not verify authenticated access.
3. **Hosted macOS symbolication:** accept only a crash report and exact-build symbols, match UUIDs, symbolicate with Xcode tooling, retain a sanitized output only, and report missing app/OS symbols clearly. Validate with a synthetic or explicitly approved real report; do not expose raw tester identity or report contents in logs.
4. **Maintain the OS simulator matrix:** run the minimum supported iOS 17 simulator test and include iOS 18/26 only while hosted runners have those runtimes. Publish runtime identity and results for each test configuration. Compatibility claims must name tested OS versions and distinguish simulator from physical-device acceptance.
5. **Performance reporting decision:** choose either App Store Connect aggregate metrics for a low-setup path, optional MetricKit collection for app-specific reports, or both. State data thresholds/latency and privacy/consent/backend requirements. Do not describe aggregates as per-device telemetry or add a required backend to the starter.

## Sources

- [Apple TestFlight tester feedback help](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-tester-feedback)
- [Apple debug symbols and archives](https://developer.apple.com/documentation/xcode/building-your-app-to-include-debugging-information)
- [Apple crash report symbolication](https://developer.apple.com/documentation/xcode/adding-identifiable-symbol-names-to-a-crash-report)
- [Apple MetricKit updates](https://developer.apple.com/documentation/updates/metrickit)
- [Apple App Store Connect Analytics](https://developer.apple.com/help/app-store-connect-analytics/)
- [Pinned App Store Connect CLI 5.14.0 release](https://github.com/rorkai/App-Store-Connect-CLI/releases/tag/5.14.0), with local reference docs under the ignored `App-Store-Connect-CLI/commands/` tree.

## Implemented symbol check and retention

`python3 scripts/collect-release-symbols.py --archive <archive> --output <symbols.json>` checks the actual app/dSYM UUID and architecture pairs. `--ipa <package>` also verifies exported app identity and UUIDs. It currently supports the starter's single app, rejecting embedded extensions/frameworks until their checks are implemented. `--retain <new-directory>` copies only the matching dSYM and manifest, never an archive or signing assets.

TestFlight preflight now checks archive symbols and publishes the small UUID manifest. Delivery checks both archive and validated IPA before upload. Its optional `retain_symbols` dispatch input retains symbols for 90 days, only in private repositories; an attempted public-repository retention fails before credential materialization. Repository readers can access these artifacts. Keep this input off for public repositories and select a separately reviewed private storage destination before public-app delivery when independent symbolication is required. This repository's public demo has no retained symbols from its earlier delivery. Retention cannot recover symbols for old builds.

Private repository users can download `release-symbols-<configuration>-<build>` with `gh run download <run-id> --name <artifact-name>`. Preserve it in controlled storage before expiry. Retained symbols may reveal source paths and function names. Check the selected run's evidence: a local unsigned Xcode 26.6 archive does not verify hosted Xcode 27 behavior, and an archive check alone does not verify an exported package.
