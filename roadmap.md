# Windows-first Apple app starter roadmap

The core workflow is **Windows → GitHub Actions → TestFlight → iPhone**. Users edit and configure their apps on Windows or through GitHub. GitHub-hosted macOS runners generate Xcode projects, build, run simulator tests, sign, and upload. Users do not need to own, rent, manage, or log into a Mac for this workflow.

A separately managed Mac is an optional build alternative. A persistent Mac becomes necessary only for users enabling the live iMessage bridge.

## Agreed defaults

- Primary CI toolchain: **Xcode 27.0**, explicitly selected and verified on GitHub's **`xcode-27` public-preview runner**.
- SDK: the selected Xcode's bundled **iOS 27 SDK**. SDK and minimum supported OS are separate settings.
- Default app: **iPhone and iPad**, with **iOS/iPadOS 17** as the configurable minimum.
- Optional platforms: Watch, native Mac, Apple TV, and Vision Pro, enabled individually with their own build and test checks.
- Proposed optional-platform minimums: watchOS 10, macOS 14, tvOS 17, and visionOS 2. These become supported configurations only after their checks pass.
- Initial simulator lane: **iOS 27.0**. Add minimum-OS coverage before advertising verified iOS 17 compatibility; add iOS 18 and 26 coverage as runtimes are provisioned.
- Device delivery: manually triggered **TestFlight builds**. Apple Developer membership, account agreements, API access, and credential setup are part of onboarding.
- AI, backend services, authentication, storage, and messaging are independent capabilities. A basic app requires none of them.

Xcode and project-generation tools are pinned and upgraded deliberately. The hosted runner image itself can change; validate required tools and runtimes and fail clearly if they are unavailable.

## Commit and milestone order

Each milestone can span several small, reviewable commits. **Do not begin the next milestone until the current milestone's required checks pass.** Fix failures within the same milestone. Local checks support development but do not substitute for the required GitHub Actions build.

| Order | Milestone | Required checks before moving on |
|---|---|---|
| **1** | **Minimal app and GitHub build.** A tiny iPhone/iPad SwiftUI app generated from a human-editable manifest. Pin Xcode 27.0 and the generator. Include a meaningful simulator smoke test. | GitHub Actions generates the project, builds the app, and passes the simulator test using the pinned toolchain. |
| **2** | **Useful build reports.** A reusable test command, readable failure summaries, and uploaded logs and `.xcresult` artifacts. | Successful and deliberately failing runs produce useful reports accessible from Windows. |
| **3** | **Template configuration.** Validate app name, bundle ID, deployment targets, project, scheme, and requested platforms/capabilities. Enable iPhone/iPad first; reject platform options not implemented yet. | Valid configuration generates a buildable app; missing, invalid, and unsupported values fail with actionable errors. |
| **4** | **Apple setup guidance and diagnostics.** Explain enrollment, roles, agreements, API access, key types, identifiers, capabilities, and signing readiness. Assess the cloned App Store Connect CLI for reuse; package portable agent instructions backed by narrow commands. | Read-only diagnostics run on Windows or GitHub and identify missing setup without changing the account or printing secrets. |
| **5** | **Credentials and signing.** Secure credential entry; preview intended account changes; reuse existing identifiers and signing assets where appropriate. Support automatic signing in GitHub Actions, with manual signing and local Mac paths as alternatives. | A signed archive passes validation. Credentials do not appear in source, logs, app bundles, or uploaded artifacts. Repeated setup does not create unnecessary duplicate assets or silently revoke certificates/profiles. |
| **6** | **TestFlight delivery.** Build numbers, export configuration, archive validation, and a protected, manually triggered upload workflow. Keep App Store publication separate. | A Windows user changes the app and installs the resulting build on their iPhone. Pull requests cannot upload builds or access signing credentials. |
| **7** | **Device diagnostics and OS compatibility.** Accessible crash feedback and diagnostic export; provision simulator lanes for supported OS versions. | A device failure can be investigated from Windows. Minimum-OS tests pass before compatibility is advertised as verified. Document coverage gaps and separately test new toolchains. |
| **8** | **Module boundaries and app essentials.** Shared packages with independently enabled storage, secure settings, and authentication seams. | A basic app builds without optional capabilities. Meaningful storage/auth tests pass when those capabilities are enabled. |
| **9** | **Optional Apple platforms.** Watch first, then native Mac, TV, and Vision Pro. Support Watch companion and standalone configurations; assess Catalyst as an alternative Mac path. Generate required targets, identifiers, and capability configuration. | Each offered platform builds and tests independently on GitHub Actions. Signing/distribution is documented. Relevant-device acceptance checks are distinguished from cloud simulator checks. |
| **10** | **Optional backend and AI.** An authenticated app API, backend-owned shared provider keys, continuity runtime, and explicit provider adapters. | Non-AI apps remain independent. Package and mock-provider end-to-end tests pass; provider switching and failure behavior are explicit. Shared provider secrets stay outside app bundles, logs, and persisted conversations. |
| **11** | **Channel contracts and simulated iMessage bridge.** Identity mapping, authentication, message IDs, deduplication, retries, delivery state, and outbound-echo handling. | Channel and bridge tests pass entirely in GitHub Actions using simulated Messages events. |
| **12** | **Optional live iMessage bridge.** Deployment on a persistent owned or rented Mac signed into Messages; model credentials remain on the backend. | CI validates the bridge artifact and deployment configuration. A separate, explicitly enabled live send/receive acceptance check passes. |
| **13** | **App Store publication and additional build options.** Metadata, release validation, submission tooling, and an optional self-hosted build path. | Upload, review submission, and publication are distinct, reviewable actions. Ordinary pull request CI remains on hosted runners; untrusted code cannot target a persistent runner holding a Messages session. |

## Issue schedule and milestone 5 gates

[PR #5](https://github.com/asavs/ios-app-starter/pull/5) is merged. After preserving both branches' setup journal entries, updated head `6c9083b` passed [all three iOS configurations](https://github.com/asavs/ios-app-starter/actions/runs/37880098030). Downloaded artifacts confirm one passing smoke test per configuration, zero failures and the expected compiled identities; all portable checks also passed. Its acceptance does not establish signing or TestFlight readiness.

The preparation for milestone 5 includes selectable native-manifest diagnostics, prominent account-check summaries/warnings, and expanded [Apple setup guidance](docs/apple-setup.md). The draft [PR #8](https://github.com/asavs/ios-app-starter/pull/8) milestone 5 implementation adds a demo-only team ID, a no-echo local-key bootstrap, runner key materialization, and a manually dispatched signing-validation workflow. The workflow gates on the protected `apple-credentials` environment, regenerates its selected manifest, reads Apple state through the pinned CLI wrapper, and validates archive identity, team, profile, certificate, expiry and entitlements before uploading only a sanitized report. It does not upload to TestFlight. The PR implementation at `ee0f1f5` passed [portable checks](https://github.com/asavs/ios-app-starter/actions/runs/37886669154), [credential-free native signing preflight](https://github.com/asavs/ios-app-starter/actions/runs/37886668932), and [all three simulator lanes](https://github.com/asavs/ios-app-starter/actions/runs/37886669022). Downloaded reports show one passing UI assertion per app; fixtures do not establish live signing. Signed-archive evidence remains required. Its credential-free preflight exercises the native list-shaped configuration export and signing-validator fixtures before any credential access. Bootstrap supports explicitly selected independent review or personal-repository solo-owner approval; it verifies the policy without changing environment settings. GitHub environment deployment access is restricted to exactly `main`, but required reviewers are not yet configured, credentials have not been stored, and the bootstrap is expected to refuse credential storage until that review control is verified. Read-only Chrome inspection found the existing demo identity and team access; no Apple account state was changed. Apple role documentation conflicts remain unresolved. Milestone 5 is still open; no live Apple account or signing readiness is inferred.

[Integrated main iOS regression](https://github.com/asavs/ios-app-starter/actions/runs/37880872209) also passed all three configurations at `7fe45df`; downloaded artifacts confirm one passing UI assertion per app and the expected compiled identities. This preparation is complete. Milestone 5 itself remains open until the credential, permission and signed-archive gates below pass.

The initial CI-efficiency improvement is complete at `25ac193`: checksum-verified XcodeGen downloads are reused across generation calls, and reviewed public tool downloads are cached by version/digest/OS/architecture. [Cold/configuration verification](https://github.com/asavs/ios-app-starter/actions/runs/37875269100), [warm restoration on all platforms](https://github.com/asavs/ios-app-starter/actions/runs/37875337210) and [both iOS regression lanes](https://github.com/asavs/ios-app-starter/actions/runs/37875237501) passed. All eighteen portable tests passed. No additional infrastructure optimization needs to block app setup. Measure cold and warm runs before adding compiler-output caching; keep signed outputs and credentials out of caches. Cache misses must remain functional and required build/test checks must still execute. Swift package dependency caching becomes relevant when packages are introduced. Consider avoiding superseded unsigned runs and unnecessary simulator builds for documentation changes while preserving required-check reporting. This is an optimization task, not evidence of signing readiness.

Implement milestone 5 in this order. Each gate must be satisfied before its dependent action, and all milestone 5 acceptance checks must pass before starting TestFlight delivery.

| When | Tracked work | Required evidence / gate |
| --- | --- | --- |
| First, before relying on authenticated diagnostic results | [#2: distinguish a credential-free account dispatch](https://github.com/asavs/ios-app-starter/issues/2) | A prominent workflow summary/warning distinguishes requested-but-skipped account reads, authentication/access failures, and completed reads. Missing credentials never look like verified account readiness; logs and artifacts stay sanitized. |
| Before demo account diagnostics or archive/signing | Configuration-selection follow-up from the PR review | Reuse the native manifest selection so the chosen configuration drives the Xcode export, account bundle-ID checks and archive. Verify the demo export resolves its demo identifier and adopters can select their own identity. Keep reusable defaults unchanged; do not silently diagnose/sign the placeholder app when the demo was requested. |
| Before choosing or provisioning any new key | [#1: least-privilege key type and role](https://github.com/asavs/ios-app-starter/issues/1) | Map the exact pinned read commands and planned signing operations to documented permissions or verified access. Distinguish app access from provisioning access; show the intended team, key type and role. Reuse appropriate existing access and explain any human-only step. Do not broaden, replace or revoke keys automatically. |
| Before implementing App ID/capability setup; verify again during signed-archive validation | [#3: Apple's default In-App Purchase toggle](https://github.com/asavs/ios-app-starter/issues/3) | Update setup guidance with Apple's documented default and distinguish account defaults from app implementation. Inspect generated signing configuration and actual signed entitlements for consistency; add no unrelated StoreKit code or optional capabilities. |
| Before any new App Store Connect record creation; carry into milestone 6 onboarding | [#4: record-name availability and display-name separation](https://github.com/asavs/ios-app-starter/issues/4) | Explain record name versus Home Screen display name. Confirm name, bundle ID, permanent SKU, language and intended access before creation; handle a name collision with a reviewed alternative. Reuse the existing demo record rather than creating another. |
| After the role/key plan and environment policy are settled, before storing release credentials | [#7: no-echo optional credential bootstrap](https://github.com/asavs/ios-app-starter/issues/7) | Accept a securely stored local key file and send it directly to the intended protected GitHub environment without printing its contents or asking for secrets in chat. Verify only secret metadata. Unsigned builds and pull requests remain secretless; template users who only build/test need no Apple setup. |

Milestone 5 finishes only after a signed archive for the selected identity passes validation, including certificate/profile validity and matching entitlements, with no secret exposure. Close each issue only when its acceptance evidence exists; this schedule does not resolve the issues. Milestone 6 then adds reviewed export/upload, build numbering and installation through TestFlight. Recheck role permissions if upload operations need different access.

[#6: preview-runner queue delays](https://github.com/asavs/ios-app-starter/issues/6) remains a separate CI observation. Investigate if it recurs; a queue delay alone does not block credential design or justify declaring the app defective. Required build/signing checks must still complete successfully before their milestone advances.

## Next execution sequence and Xcode outputs

The next hands-on walkthrough runs in the existing Windows chat that authored PR #8; use [the exact handoff prompt](docs/windows-milestone-5-handoff.md). Windows CI verifies executable portability, while this walkthrough verifies real PowerShell paths, browser/account setup, secure credential entry and readable reports. Windows is an acceptance surface, not a requirement for operating signing; all Xcode work remains on GitHub-hosted macOS. Use the platform already holding the securely stored key rather than copying it to another machine merely for a test.

1. **Windows, milestone 5:** Fetch the updated PR, preserve local changes and both journals, start credential-free diagnostics, and inspect current configuration/test artifacts. After review and required CI pass, merge PR #8 and verify main. This installs the workflow on main without claiming signed-archive acceptance.
2. **Windows, milestone 5:** Present and approve the environment policy, existing key and intended operations. Solo-owner approval is the recommended personal-repository path, subject to explicit selection; independent approval remains available. Verify the approved protections before secret transfer. Confirm existing key-file availability without exposing its contents. Do not create a replacement key or broaden roles automatically.
3. **GitHub, operated from Windows, milestone 5:** After explicit opt-in, run authenticated read-only diagnostics for the existing demo with that run's fresh native export. After concrete signing-plan approval, run automatic signing and inspect the actual archive validation report. Failures return to milestone 5 diagnosis; only a validated real signed archive completes it.
4. **Report improvement in the existing milestone 2 tooling:** Add individual test-failure details and screenshot attachments extracted by the runner's native `xcresulttool`, linked from the existing Markdown/JSON report. This is a small repository/workflow enhancement rather than a new service. It can be developed independently of account setup, but must not delay or replace milestone 5 acceptance. Verify successful and deliberately failing runs, artifact readability from Windows, and failure exit status. Preserve `.xcresult` for optional Xcode inspection; upload screenshots only from controlled test data.
5. **Milestone 6, after milestone 5 passes:** Add reviewed export configuration, build numbers and protected manual TestFlight upload; then perform the visible-app-change, GitHub-build and iPhone-install loop from Windows. Recheck upload permissions, and keep App Store publication separate. Device diagnostics/minimum-OS runtime coverage follow in milestone 7; optional platforms remain milestone 9.

Use Xcode as a source of native configuration and evidence, with these storage boundaries:

| Xcode-derived material | Repository / artifact decision |
| --- | --- |
| Target settings, shared schemes, entitlements and capability configuration | Review and represent settings through `project.yml`; regenerate the checked-in project when the manifest changes. Commit native source files when the relevant capability is supported. A UI change must not become an untracked second source of truth. |
| `.xctestplan` files | Commit when multiple test configurations justify them; do not add one only to duplicate the current single smoke test. |
| `ExportOptions.plist` | Review and commit non-secret export choices during milestone 6, based on the selected Xcode's actual supported options. |
| Resolved settings, compiled-app identity, structured failures and screenshots | Produce fresh per-run GitHub artifacts; associate them with the manifest and commit. Existing configuration/identity/summary exports already cover part of this. |
| Archives and debug symbols | Retain through an explicitly reviewed release/diagnostics policy when needed; do not commit generated binaries into Git history. The initial signing-validation job deliberately removes its archive. |
| Private keys, certificate private keys and account sessions | Secure credential storage only; never repository files or public artifacts. |

No local Xcode installation is needed to produce these outputs. Local Xcode remains an optional debugging aid. A green local build with preexisting accounts/Keychain state cannot replace the fresh hosted-runner gate.

## Milestone 3 implementation approach

Reuse the existing infrastructure: `project.yml` is the configuration, XcodeGen generates and validates the project structure, and GitHub Actions runs `xcodebuild` to inspect resolved settings, build, and test. Do not introduce a separate `app.config.json`, configuration service, custom project generator, or hosted setup backend.

- Document app display name, bundle identifiers, deployment minimum, device families, targets, and schemes in the existing manifest. Keep display/product naming separate from internal Swift module and test target names so customization does not accidentally break imports or CI selection.
- Use XcodeGen's existing validation for malformed manifests and missing source/target references. Use `xcodebuild -list -json` and `-showBuildSettings -json` to check the actual generated project and selected scheme. Add only small checks for template policies that those tools do not enforce, such as the currently supported platform set and identifier format.
- Prove customization with a changed app name and bundle ID that builds and passes the smoke test on GitHub. Verify representative invalid and unsupported configurations fail with useful messages. Generating a project alone is not the acceptance check.
- Keep capability setup in Apple's native entitlements/build settings and the later signing milestones. A declared entitlement does not prove Apple has enabled the capability for the account.

GitHub Actions orchestrates these commands; Xcode performs Apple's compilation, testing, and later signing/archive work. This remains a repository with scripts and workflows, without a separately operated service. Milestone 3 is complete based on the remote checks and inspected artifacts linked below.

## First end-to-end acceptance check

Milestone 6 is the first major success point: a person using **Windows, GitHub Actions, an iPhone, and an Apple Developer membership** can configure an app, change visible behavior, pass remote checks, trigger a signed build, and install it through TestFlight without using a Mac themselves.

The first milestones make this loop work before adding AI, server, or messaging features. Unsigned build/test workflows remain usable before Apple account setup is complete.

## Onboarding, accounts, and platform boundaries

Onboarding and examples are updated with every milestone. Finish with a complete Windows walkthrough and generated non-AI and AI examples proving optional modules remain optional.

Maintain [the setup experience journal](docs/setup-experience.md) throughout development. Record actual failures, fixes, important decisions, verification evidence, and unresolved limitations so future people and agents can reproduce the setup. Root `AGENTS.md` makes this part of the ongoing workflow.

Agent guidance should explain human-only Apple prerequisites, diagnose before changing anything, preview account changes, and keep secrets out of chat. Choose API key types and roles deliberately rather than defaulting to the broadest access. Windows users enter credentials through supported local secret storage or GitHub secrets; Mac Keychain is an optional local path.

Common logic belongs in shared packages; enabled platforms own their interface and lifecycle. An iPhone provides physical iPhone testing. Watch, Mac, TV, and Vision Pro hardware behavior requires the relevant device, another tester, or remote access; cloud tests do not establish physical-device coverage.

## Current status

**Milestone 1 is complete.** The app is generated from `project.yml` with pinned XcodeGen 2.46.0. GitHub Actions selected and verified Xcode 27.0 and the iOS 27 SDK, generated the project, built the app and test targets, and passed the welcome-screen simulator test. Regeneration also reproduced the checked-in project without changes.

- Repository: [asavs/ios-app-starter](https://github.com/asavs/ios-app-starter) (public).
- Verified implementation commit: `b67df32`.
- Required remote check: [successful iOS build and simulator test](https://github.com/asavs/ios-app-starter/actions/runs/37822420937).
- **Milestone 2 is complete:** reusable `scripts/test-ios.sh`, Markdown/JSON summaries, and retained logs/result bundles. Five report tests and a shell failure-status check passed locally; success and explicit assertion-failure reports/artifacts were downloaded and inspected on GitHub.
- Verified milestone 2 implementation commit: `f122dae`.
- [Successful build/test and report upload](https://github.com/asavs/ios-app-starter/actions/runs/37826317826).
- [Deliberate assertion-failure check](https://github.com/asavs/ios-app-starter/actions/runs/37826318371): expected red run; named failure, exit 65, logs, and result bundle verified.
- GitHub repository metadata confirms **template repository enabled**; visibility is public, as authorized by the user.
- **Milestone 3 is complete:** native configuration checks, a renamed-app example, twelve invalid-configuration probes, and compiled-app settings verification.
- Verified implementation commit: `76c9db4`.
- [Successful starter and Pocket Notes acceptance run](https://github.com/asavs/ios-app-starter/actions/runs/37833792319): both built with Xcode 27.0/iOS SDK 27.0 and passed one welcome-screen test each on iOS 27.0. Downloaded artifacts confirm distinct app names/identifiers, iOS 17.0 minimum, and iPhone/iPad support in the compiled apps. All twelve invalid-configuration probes passed.
- Slow bootstrap/automation exposed the previous 120-second test allowance. CI now prepares the simulator explicitly, allows 300 seconds per test, and bounds build/test to ten minutes. Native runner timing still varies; the journal records the observed failures and limits of the diagnosis.
- **Milestone 4 is complete:** Windows-first Apple setup/agent guidance, pinned CLI integration, and read-only Markdown/JSON diagnostics. [Portable Windows/Linux/macOS verification](https://github.com/asavs/ios-app-starter/actions/runs/37838797337) passed all nine tests; [fresh Xcode configuration/report verification](https://github.com/asavs/ios-app-starter/actions/runs/37838190831) and [missing-secret account-job verification](https://github.com/asavs/ios-app-starter/actions/runs/37838380306) passed. [Fresh iOS builds/tests and report uploads](https://github.com/asavs/ios-app-starter/actions/runs/37838166104) also passed for both example configurations. No live Apple account was authenticated; those checks remain explicitly unverified.
- **Next: milestone 5**, secure credential handling, signing setup and validation of a signed archive. Follow the [issue schedule and dependency gates](#issue-schedule-and-milestone-5-gates) before account checks, new keys, account changes or credential storage.

The cloned `App-Store-Connect-CLI` remains an ignored reference checkout. Milestone 4 audited it and integrates the pinned 5.14.0 release binary through narrow read commands; unsigned app builds do not depend on the CLI.

## References

- [GitHub Xcode 27 runner announcement](https://github.com/actions/runner-images/issues/14404)
- [GitHub Xcode 27 runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md)
- [Apple SDKs and deployment-target support](https://developer.apple.com/xcode/system-requirements)
- [Apple App Store Connect API setup](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api)

The separate `platform-and-sdk-notes.md` preserves the earlier pasted text verbatim. This roadmap records the subsequently agreed decisions.

## Milestone 4 implementation approach

The optional authenticated diagnostic job uses the GitHub environment `apple-credentials`. Its purpose is credential access; GitHub's “deployment” wording does not mean account setup or app publication occurred.

The Windows-first [Apple setup guide](docs/apple-setup.md) pairs human prerequisites with portable `scripts/apple-doctor.py` reports. Project findings consume milestone 3's native Xcode JSON export; no second configuration format or hosted service is introduced. The `asc` 5.14.0 subprocess is checksum-pinned, telemetry-disabled and constrained to paginated read commands with isolated credential resolution. Optional account reads run only on explicit request; ordinary checks need no Apple account.

Windows/Linux/macOS CI exercises the native binary and diagnosis/redaction contract. Real Apple account reads require user-owned credentials and remain unverified until the opt-in workflow runs with them. Milestone 5 adds persistent credential handling, signing-asset validation/setup and a validated signed archive; milestone 6 adds the first TestFlight installation.
