# iOS App Starter roadmap

The starter is a native iPhone and iPad app with the pieces most apps need already built and prunable: onboarding, theme and UX elements, settings with secure storage, and next sign-in and a database layer. An app built from it spends its time on what makes it different, not on builds, signing or delivery.

GitHub-hosted macOS runners generate the Xcode project, build, test, sign and upload, so the app can be developed from Windows, from a Mac, or by an AI agent. As a result:

- No separately managed Mac is required for development, signing or TestFlight delivery. A local Mac is an optional faster loop.
- A persistent Mac is needed only for the optional live iMessage bridge.
- AI, backend services, sign-in, storage and messaging are independent capabilities. A basic app requires none of them.

## Agreed defaults

- CI toolchain: Xcode 27.0, explicitly selected and verified on GitHub's `xcode-27` public-preview runner.
- SDK: that Xcode's bundled iOS 27 SDK. SDK and minimum supported OS are separate settings.
- Default app: iPhone and iPad, with iOS/iPadOS 17 as the configurable minimum.
- Optional platforms: Watch, native Mac, Apple TV and Vision Pro, each enabled individually with its own build and test checks. Proposed minimums are watchOS 10, macOS 14, tvOS 17 and visionOS 2; each becomes supported only after its checks pass.
- Simulator lanes: required pull-request and `main` checks run on iOS 27.0. A manual and weekly compatibility matrix runs one lane per iOS runtime on the hosted images, each paired with a Swift 6-capable Xcode. Verified as of 2026-10-16: iOS 17.0.1, 18.1, 26.0.1 and 27.0 ([run 38974328806](https://github.com/asavs/ios-app-starter/actions/runs/38974328806)). Coverage claims name only runtimes whose lane passed.
- Device delivery: manually triggered TestFlight builds. Apple Developer membership, agreements, API access and credential setup are part of onboarding.

Xcode and the project generator are pinned and upgraded deliberately. The hosted runner image can change underneath them, so validate required tools and runtimes and fail clearly when one is missing.

## Milestones

A milestone can span several small, reviewable commits. **Do not begin the next milestone until the current milestone's required checks pass.** Fix failures within the same milestone. Local checks help development but do not replace the required GitHub Actions build.

| Order | Milestone | Required checks before moving on |
|---|---|---|
| **1** | **Minimal app and GitHub build.** A tiny iPhone/iPad SwiftUI app generated from a human-editable manifest, with Xcode 27.0 and the generator pinned and a meaningful simulator smoke test. | GitHub Actions generates the project, builds the app and passes the simulator test on the pinned toolchain. |
| **2** | **Useful build reports.** A reusable test command, readable failure summaries, and uploaded logs and `.xcresult` artifacts. | Passing and deliberately failing runs produce useful reports readable from Windows. |
| **3** | **Template configuration.** Validate app name, bundle ID, deployment targets, project, scheme, and requested platforms and capabilities. iPhone/iPad first; reject platform options not yet implemented. | Valid configuration generates a buildable app; missing, invalid and unsupported values fail with actionable errors. |
| **4** | **Apple setup guidance and diagnostics.** Explain enrollment, roles, agreements, API access, key types, identifiers, capabilities and signing readiness. Assess the cloned App Store Connect CLI for reuse; package portable agent instructions backed by narrow commands. | Read-only diagnostics run on Windows or GitHub and identify missing setup without changing the account or printing secrets. |
| **5** | **Credentials and signing.** Secure credential entry, a preview of intended account changes, and reuse of existing identifiers and signing assets where appropriate. Automatic signing in GitHub Actions, with manual signing and local Mac paths as alternatives. | A signed archive passes validation. Credentials do not appear in source, logs, app bundles or uploaded artifacts. Repeated setup creates no unnecessary duplicate assets and never silently revokes certificates or profiles. |
| **6** | **TestFlight delivery.** Build numbers, export configuration, archive validation, and a protected, manually triggered upload workflow. App Store publication stays separate. | A Windows user changes the app and installs the resulting build on their iPhone. Pull requests cannot upload builds or access signing credentials. |
| **7** | **Device diagnostics and OS compatibility.** Accessible crash feedback and diagnostic export; simulator lanes for supported OS versions. | A device failure can be investigated from Windows. Minimum-OS tests pass before compatibility is advertised as verified. Coverage gaps are documented and new toolchains tested separately. |
| **8** | **Agent-comfortable iteration loop.** Structured failure output from `xcodebuild` and tests, a run-level review command, feedback-to-issue drafts, measured build caching, and one-command authorized delivery. | An agent goes from a red run to a named failure in one command, and from a fix on `main` to a build on the phone in one authorized dispatch, without opening the Actions UI. |
| **9** | **Module boundaries and app essentials.** Versioned Swift packages in this repository with independently enabled icon pipeline, onboarding, theme/UX, secure settings, then authentication and storage seams. | A basic app builds with no modules enabled. Each package has its own tests and lane. The demo app on the owner's phone consumes the first round through the existing delivery workflow. |
| **10** | **Agent onboarding runbook and guided setup, proven on a second app.** `docs/agent-onboarding.md`, a "Start here" route in `AGENTS.md`, a resumable `scripts/setup.py`, then a timed fresh-repository run and one backpropagation round-trip. | A fresh agent on a fresh machine reaches a build on a phone with only the human-only Apple/GitHub prompts; the first-run report lists every prompt and stall; a module change reaches both apps by version bump. |
| **11** | **Optional backend and AI.** An authenticated app API, backend-owned shared provider keys, a continuity runtime and explicit provider adapters. | Non-AI apps remain independent. Package and mock-provider end-to-end tests pass; provider switching and failure behavior are explicit. Shared provider secrets stay out of app bundles, logs and persisted conversations. |
| **12** | **Channel contracts and simulated iMessage bridge.** Identity mapping, authentication, message IDs, deduplication, retries, delivery state and outbound-echo handling. | Channel and bridge tests pass entirely in GitHub Actions on simulated Messages events. |
| **13** | **Optional live iMessage bridge.** Deployed on a persistent owned or rented Mac signed into Messages; model credentials stay on the backend. | CI validates the bridge artifact and deployment configuration. A separate, explicitly enabled live send/receive acceptance check passes. |
| **14** | **Optional Apple platforms.** Watch first, then native Mac, TV and Vision Pro. Watch companion and standalone configurations; Catalyst assessed as an alternative Mac path. Generate the required targets, identifiers and capability configuration. | Each offered platform builds and tests independently on GitHub Actions. Signing and distribution are documented. Device acceptance checks are distinguished from cloud simulator checks. |
| **15** | **App Store publication and additional build options.** Metadata, release validation, submission tooling and an optional self-hosted build path. | Upload, review submission and publication are distinct, reviewable actions. Ordinary pull-request CI stays on hosted runners; untrusted code cannot target a persistent runner holding a Messages session. |

**Renumbered 2026-10-16** to follow [the master plan](docs/master-plan.md). Earlier documents and issues use the old numbers: old 8 (modules) is now 9, 9 (platforms) is 14, 10 (AI) is 11, 11 (simulated bridge) is 12, 12 (live bridge) is 13, and 13 (publication) is 15. Milestone 8 and the second-app proof in 10 are new. Optional platforms moved late because the module library is the product; they stay in scope because hosted runners can test them.

## Current status

As of 2026-10-24. Evidence for every milestone is in [the setup journal](docs/setup-experience.md); earlier status write-ups are in [the roadmap history](docs/archive/roadmap-history.md).

- **Milestones 1–7 are complete.** The app is generated from `project.yml` and built, tested and reported on GitHub-hosted Xcode 27.0, with configuration validated. Apple setup diagnostics, signing and TestFlight delivery were accepted for the demo app, which the owner installed on their iPhone on 2026-10-12. Device failures can be investigated from Windows, and the compatibility matrix verified the iOS 17.0 minimum (see the simulator lanes under Agreed defaults).
- **Milestone 8 is in place.** Structured failure reports, the run review command, feedback-to-issue drafts, measured caching, one-command TestFlight delivery and `run-on-device` for Macs all exist. The optional ad hoc dev-build channel waits on a hosting decision.
- **Milestone 9, round one, is released.** Theme, Onboarding and Settings shipped with TemplateVersion as module library `0.2.0` (2026-10-23); `0.3.0` (2026-10-24) made all module text translatable and moved Keychain calls off the main actor. See [docs/modules.md](docs/modules.md). Sign-in and the SwiftData layer are round two, built when a real app asks for them.
- **Milestone 10 is in progress.** The [onboarding runbook](docs/agent-onboarding.md), its consent checklist and the resumable `scripts/setup.py` exist. Still to do: the timed run on a fresh second app and one backpropagation round-trip.

## Principles

Every module is a scaffold an app can keep, change or delete: the app builds with any subset enabled, and nothing enters the template until a real app needed it. Update onboarding and examples with every milestone. Finish with complete walkthroughs from Windows and from a Mac, and generated non-AI and AI examples that prove optional modules stay optional.

Keep [the setup experience journal](docs/setup-experience.md) current throughout: failures, fixes, decisions, verification evidence and open limitations, so people and agents can reproduce the setup. `AGENTS.md` makes this part of the workflow.

Agent guidance explains the human-only Apple prerequisites, diagnoses before changing anything, previews account changes, and keeps secrets out of chat. Choose API key types and roles deliberately rather than defaulting to the broadest access. Windows users enter credentials through supported local secret storage or GitHub Secrets; Mac Keychain is an optional local path.

Common logic belongs in shared packages; each enabled platform owns its interface and lifecycle. An iPhone covers physical iPhone testing. Watch, Mac, TV and Vision Pro hardware behavior needs the device, another tester or remote access; cloud tests do not establish physical-device coverage.

## Where Xcode output lives

Xcode is a source of native configuration and evidence, stored as follows:

| Xcode-derived material | Where it goes |
| --- | --- |
| Target settings, shared schemes, entitlements and capability configuration | Represent settings in `project.yml` and regenerate the checked-in project when the manifest changes. Commit native source files once the capability is supported. A change made in the Xcode UI must not become an untracked second source of truth. |
| `.xctestplan` files | Commit when multiple test configurations justify them, not to duplicate the current single smoke test. |
| `ExportOptions.plist` | Committed as `config/ExportOptions-TestFlight.plist`: reviewed, non-secret export choices, based on the options the selected Xcode actually supports. |
| Resolved settings, compiled-app identity, structured failures and screenshots | Fresh per-run GitHub artifacts, tied to the manifest and commit. Existing configuration, identity and summary exports cover part of this. |
| Archives and debug symbols | Keep only under an explicitly reviewed release/diagnostics policy; never commit generated binaries to Git. The initial signing-validation job deliberately removes its archive. |
| Private keys, certificate private keys and account sessions | Secure credential storage only; never repository files or public artifacts. |

None of this needs a local Xcode, which stays an optional debugging aid. A green local build with existing account or Keychain state does not replace the fresh hosted-runner gate.

## References

- [GitHub Xcode 27 runner announcement](https://github.com/actions/runner-images/issues/14404)
- [GitHub Xcode 27 runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md)
- [Apple SDKs and deployment-target support](https://developer.apple.com/xcode/system-requirements)
- [Apple App Store Connect API setup](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api)

`platform-and-sdk-notes.md` preserves earlier pasted text verbatim; this roadmap records the decisions agreed since.
