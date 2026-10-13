# Device diagnostics and OS coverage

**Status (2026-10-12): milestone 7 is planned, not implemented.** Milestone 6 TestFlight delivery is complete for the acceptance app, but this repository does not yet provide a Windows workflow for collecting/triaging device reports or a simulator lane for iOS 17. Treat this page as the design boundary and implementation checklist, not as a claim that diagnostics are already available.

## What can be used now

### TestFlight feedback and crash submissions

TestFlight testers can submit screenshot feedback, general comments, and crash feedback from the TestFlight app. In App Store Connect, an authorized user can filter screenshot/crash feedback by platform, version, build, OS version, and device, then download a ZIP with the screenshot or crash report and comments. Apple's help says crash feedback downloads are available for 120 days; a tester app becoming unresponsive does not guarantee a crash report is included. See [View tester feedback](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-tester-feedback) and [TestFlight](https://developer.apple.com/testflight/).

The current upload policy sets `uploadSymbols=true`, which asks Xcode to upload symbols with the TestFlight build. The release workflow uploads no `.xcarchive`, `.dSYM`, crash report, or IPA to GitHub artifacts; it removes its temporary archive/export after delivery and retains only sanitized reports for seven days. Therefore Apple may symbolicate reports from uploaded symbols, but this repository does not retain a local exact-build archive/dSYM for later manual symbolication. The manifest does not explicitly set `DEBUG_INFORMATION_FORMAT`; confirm the generated Release configuration produces DWARF with dSYM before relying on symbolication. Apple ties dSYMs to binary UUIDs and says to retain each distributed build's archive. See [Building your app to include debugging information](https://developer.apple.com/documentation/xcode/building-your-app-to-include-debugging-information) and [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases).

### Pinned App Store Connect CLI

The ignored `App-Store-Connect-CLI/` reference checkout is exactly **5.14.0**. Its command documentation describes read operations for TestFlight crash submissions/logs (`asc testflight crashes list|view|log`), tester feedback including screenshot URLs (`asc testflight feedback list|view`), and App Store Connect performance data (`asc performance overview|metrics list|view`). The documented crash filters include device model and OS version. The CLI is not an integrated dependency, and `scripts/apple-doctor.py` deliberately allows only its narrow Apple setup reads. No crash, feedback, or performance API call was made for this research; command docs establish an upstream documented surface, not credential availability, role sufficiency, endpoint behavior for this account, data presence, or a supported template command.

For a Windows-first implementation, add fixed, reviewed wrapper subcommands rather than passing arbitrary CLI text through. Use the existing pinned installer/checksum and isolated credential wrapper conventions; request authenticated reads only by explicit opt-in, sanitize upstream output, and treat denied, incomplete, empty, and skipped responses distinctly. The CLI documents destructive feedback/crash deletion too; those commands are outside diagnostics scope. Recheck the CLI's pinned docs and help during implementation before promising these surfaces.

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

The app and test targets declare **iOS 17.0 minimum**, the selected CI toolchain is **Xcode 27.0 / iOS 27.0 SDK**, and current simulator coverage is **iOS 27.0 only**. A deployment target says which OS versions the app claims to support; it is not evidence that the app was run on those versions. The current one-test UI smoke test on an iOS 27 simulator does not verify iOS 17 behavior. The roadmap calls for provisioning minimum-OS coverage before advertising verified compatibility, then adding iOS 18 and 26 lanes when runtimes are available. Record the actual runtime/device and test evidence; do not infer coverage from SDK version or a physical phone on another OS. Check [current Xcode system requirements](https://developer.apple.com/xcode/system-requirements) and the runner's actual installed simulators before selecting lanes because hosted images change.

## Recommended milestone 7 issue scopes

Keep these reviewable and independently verifiable:

1. **Release symbol production and retention:** inspect current generated Release settings and archive UUIDs; explicitly set DWARF with dSYM if needed; retain exact-build dSYMs/archive under access controls and documented retention; confirm exported/uploaded symbols match.
2. **Windows-accessible TestFlight feedback export:** add pinned-CLI fixed read commands for crash feedback, logs, and screenshot feedback; explicit opt-in; pagination/filters; safe sanitized artifacts; tests for no credentials, access errors, empty results, malformed responses, timeout, and redaction. First verify the pinned CLI 5.14.0 commands and Apple role/API behavior with an authorized account; never imply current authenticated access is verified.
3. **Hosted macOS symbolication:** accept only a crash report and exact-build symbols, match UUIDs, symbolicate with Xcode tooling, retain a sanitized output only, and report missing app/OS symbols clearly. Validate with a synthetic or explicitly approved real report; do not expose raw tester identity or report contents in logs.
4. **OS simulator matrix:** provision and run the minimum supported iOS 17 simulator lane; add iOS 18/26 only when the selected runner actually has those runtimes; publish runtime identity and per-lane test outcomes. Compatibility claims must name tested OS versions and distinguish simulator from physical-device acceptance.
5. **Performance reporting decision:** choose either App Store Connect aggregate metrics for a low-setup path, optional MetricKit collection for app-specific reports, or both. State data thresholds/latency and privacy/consent/backend requirements. Do not describe aggregates as per-device telemetry or add a required backend to the starter.

## Sources

- [Apple TestFlight tester feedback help](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-tester-feedback)
- [Apple debug symbols and archives](https://developer.apple.com/documentation/xcode/building-your-app-to-include-debugging-information)
- [Apple crash report symbolication](https://developer.apple.com/documentation/xcode/adding-identifiable-symbol-names-to-a-crash-report)
- [Apple MetricKit updates](https://developer.apple.com/documentation/updates/metrickit)
- [Apple App Store Connect Analytics](https://developer.apple.com/help/app-store-connect-analytics/)
- [Pinned App Store Connect CLI 5.14.0 release](https://github.com/rorkai/App-Store-Connect-CLI/releases/tag/5.14.0), with local reference docs under the ignored `App-Store-Connect-CLI/commands/` tree.
