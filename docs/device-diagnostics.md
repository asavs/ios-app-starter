# Investigate app failures and check OS coverage

When your app fails on a phone, start with the installed build, the device OS and [tester feedback](tester-feedback.md). You can read TestFlight feedback from Windows with the fixed CLI reader or in App Store Connect, then turn actionable reports into sanitized issues. There is no hosted symbolication job or crash-report reader yet; the backlog below lists them.

For OS compatibility, go by the simulator matrix's actual results. On 2026-10-16 the weekly matrix verified the smoke test on iOS 17.0.1, 18.1, 26.0.1 and 27.0 ([run 38974328806](https://github.com/asavs/ios-app-starter/actions/runs/38974328806)).

## What can be used now

### TestFlight feedback and crash submissions

Testers can send screenshot feedback, comments and crash feedback from the TestFlight app. In App Store Connect, an authorized user can filter screenshot and crash feedback by platform, version, build, OS version and device, then download a ZIP with the screenshot or crash report and comments. Apple keeps crash feedback downloads for 120 days, and an app that hangs does not necessarily produce a crash report. See [View tester feedback](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-tester-feedback) and [TestFlight](https://developer.apple.com/testflight/).

The upload policy sets `uploadSymbols=true`, so Xcode uploads debug symbols with the TestFlight build. Apple may use them to symbolicate crash reports, showing function names instead of addresses.

The release workflow keeps only sanitized reports, for seven days. It uploads no `.xcarchive`, `.dSYM`, crash report or IPA to GitHub artifacts, and deletes its temporary archive and export after delivery. Unless you turn on [symbol retention](#implemented-symbol-check-and-retention) in a private repository, there is no exact-build archive or dSYM to download later.

The manifest does not set `DEBUG_INFORMATION_FORMAT`. Confirm that the generated Release configuration produces DWARF with dSYM before relying on symbolication. dSYMs are tied to binary UUIDs, and Apple says to keep each distributed build's archive. See [Building your app to include debugging information](https://developer.apple.com/documentation/xcode/building-your-app-to-include-debugging-information) and [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases).

### Pinned App Store Connect CLI

The ignored `App-Store-Connect-CLI/` reference checkout is version 5.14.0. Its documentation describes reads for TestFlight crash submissions and logs (`asc testflight crashes list|view|log`, filterable by device model and OS version), tester feedback with screenshot URLs (`asc testflight feedback list|view`), and performance data (`asc performance overview|metrics list|view`).

The checkout is a reference, not a dependency. The starter runs a pinned release binary through reviewed wrappers, and `scripts/apple-doctor.py` allows only narrow Apple setup reads. Apart from the fixed [tester feedback](tester-feedback.md) reader, none of these crash, feedback or performance commands has been run against an account, so their access, permissions and data are unverified.

To add a read operation:

- Add a fixed, reviewed wrapper subcommand. Do not pass arbitrary CLI text through.
- Reuse the pinned installer, checksum and isolated credential wrapper.
- Require explicit opt-in for authenticated reads, sanitize upstream output, and distinguish denied, incomplete, empty and skipped responses.
- Leave out the CLI's feedback and crash deletion commands; they are outside diagnostics.
- Recheck the pinned docs and help before promising the operation.

App Store Connect performance data is aggregate, filtered by build and device type where supported, and appears only above Apple's data and privacy thresholds. It is not a live per-device trace. Apple's [Analytics overview](https://developer.apple.com/help/app-store-connect-analytics/) notes that some data needs enough volume and users who opted into sharing diagnostics.

### MetricKit (optional app feature)

MetricKit is not implemented. It delivers daily aggregated performance payloads and diagnostic payloads to an app on physical devices. Adding it means shipping a subscriber and deciding what to persist or send, with a backend, consent and privacy design. Keep it optional and independent of the basic app. See [MetricKit updates](https://developer.apple.com/documentation/updates/metrickit), [MXMetricPayload](https://developer.apple.com/documentation/metrickit/mxmetricpayload) and [MetricManager](https://developer.apple.com/documentation/metrickit/metricmanager).

## Symbolication path

1. Keep symbols enabled in the TestFlight export policy and check that the Release archive has matching dSYMs for the app, extensions and included frameworks. A dSYM from another build or Xcode version does not work; compare UUIDs.
2. Keep the exact archive, or at least its dSYMs, by build number in access-controlled storage with a set retention period. Never put signing credentials or private keys in it. The workflow deletes the archive; the only retention today is the optional private-repository [symbol retention](#implemented-symbol-check-and-retention).
3. When a tester submits crash feedback, get the report from App Store Connect or, once the pinned CLI behavior is verified, a fixed authenticated read command. Record its app version, build, device model and OS version.
4. Apple may already deliver a symbolicated report when symbols were uploaded. Otherwise, download the report and matching dSYMs and symbolicate on a hosted macOS job (`xcrun crashlog` or Xcode) that returns only a sanitized report. Operating-system frames may also need Xcode or device OS symbols. No such job exists yet; it needs hosted macOS and a tightly scoped artifact handoff, not your own Mac.

See Apple's [crash report symbolication guide](https://developer.apple.com/documentation/xcode/adding-identifiable-symbol-names-to-a-crash-report). TestFlight crash feedback is separate from App Store Connect's aggregate crash analytics and from reports users export from device settings.

## OS coverage and claims

Keep these settings and results separate:

| What | Setting or recorded result |
| --- | --- |
| App and test deployment minimum | iOS 17.0 |
| Selected CI toolchain | Xcode 27.0 / iOS 27.0 SDK |
| Required simulator checks | iOS 27.0 |
| Verified smoke-test runtimes, 2026-10-16 | iOS 17.0.1, 18.1, 26.0.1 and 27.0 |

A deployment target declares support; it does not prove the app ran there. An iOS 27 simulator test does not verify iOS 17 behavior, and a physical phone covers only its own OS.

The `iOS compatibility matrix` workflow (`.github/workflows/ios-compatibility.yml`) inventories each hosted image, `scripts/plan-compatibility-matrix.py` pairs each available runtime with a Swift 6-capable Xcode on that image, each pairing runs the app's UI checks, and `scripts/report-compatibility.py` reports only the runtimes that passed.

On 2026-10-16 the images had iOS 17.0.1, 17.2, 17.4, 17.5, 18.1 and 18.2 on `macos-14` (Xcode 16.1/16.2 for Swift 6); 18.5, 18.6 and 26.0.1–26.2 on `macos-15`; and 27.0 on `xcode-27`. Hosted images change and retire, so each run plans from its own inventory. Record the actual runtime, device and test results, and check [current Xcode system requirements](https://developer.apple.com/xcode/system-requirements) and installed simulators before choosing test configurations.

## Conditional diagnostics backlog

The [archived shared plan](archive/mac-windows-coordination.md) has the original sequence. Add each of these only when an investigation needs it, as its own reviewable, separately verified change:

1. **Release symbol production and retention:** inspect the generated Release settings and archive UUIDs, set DWARF with dSYM explicitly if needed, keep exact-build dSYMs or archives under access control with a set retention period, and confirm the exported and uploaded symbols match.
2. **Crash feedback and log reads:** add fixed pinned-CLI reads (the screenshot-feedback reader is in [tester feedback](tester-feedback.md)). Require explicit opt-in, pagination and filters, and sanitized artifacts, with tests for missing credentials, access errors, empty results, malformed responses, timeouts and redaction. First verify the CLI 5.14.0 commands and Apple role and API behavior with an authorized account; an implementation alone does not verify authenticated access.
3. **Hosted macOS symbolication:** accept only a crash report and exact-build symbols, match UUIDs, symbolicate with Xcode tools, keep only sanitized output, and report missing app or OS symbols clearly. Validate with a synthetic or explicitly approved real report; never expose tester identity or report contents in logs.
4. **OS simulator matrix upkeep:** keep testing the minimum iOS 17 runtime, and iOS 18 and 26 while hosted runners have them. Publish runtime identity and results for each configuration. Compatibility claims must name the tested OS versions and say whether they come from simulators or physical devices.
5. **Performance reporting:** choose App Store Connect aggregate metrics (little setup), optional MetricKit collection (app-specific reports), or both. State data thresholds, latency, and privacy, consent and backend needs. Do not describe aggregates as per-device telemetry or make a backend required for the starter.

## Sources

- [Apple TestFlight tester feedback help](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-tester-feedback)
- [Apple debug symbols and archives](https://developer.apple.com/documentation/xcode/building-your-app-to-include-debugging-information)
- [Apple crash report symbolication](https://developer.apple.com/documentation/xcode/adding-identifiable-symbol-names-to-a-crash-report)
- [Apple MetricKit updates](https://developer.apple.com/documentation/updates/metrickit)
- [Apple App Store Connect Analytics](https://developer.apple.com/help/app-store-connect-analytics/)
- [Pinned App Store Connect CLI 5.14.0 release](https://github.com/rorkai/App-Store-Connect-CLI/releases/tag/5.14.0), with local reference docs under the ignored `App-Store-Connect-CLI/commands/` tree.

## Implemented symbol check and retention

`python3 scripts/collect-release-symbols.py --archive <archive> --output <symbols.json>` checks the app/dSYM UUID and architecture pairs. `--ipa <package>` also verifies the exported app's identity and UUIDs. It supports only the starter's single app and rejects embedded extensions and frameworks until they have checks. `--retain <new-directory>` copies only the matching dSYM and manifest, never an archive or signing assets.

TestFlight preflight checks archive symbols and publishes the small UUID manifest; delivery checks both the archive and the validated IPA before upload. The optional `retain_symbols` dispatch input keeps symbols for 90 days, in private repositories only: a public repository fails before credentials are materialized. Anyone who can read the repository can download these artifacts. Keep the input off for public repositories, and pick a separately reviewed private storage destination before delivering a public app that needs independent symbolication. This repository's public demo has no retained symbols, and retention cannot recover symbols for old builds.

In a private repository, download `release-symbols-<configuration>-<build>` with `gh run download <run-id> --name <artifact-name>` and move it to controlled storage before it expires. Retained symbols may reveal source paths and function names. Check the evidence from the run you are relying on: a local unsigned Xcode 26.6 archive does not verify hosted Xcode 27 behavior, and an archive check alone does not verify an exported package.
