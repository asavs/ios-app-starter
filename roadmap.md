# iOS App Starter roadmap

The starter is a native iPhone and iPad app with the pieces most apps need already built and prunable: onboarding, theme and UX elements, settings with secure storage, and next sign-in and a database layer. Someone building an app starts from those and spends their time on what makes the app different, without handling builds, signing or delivery.

Those are handled for them. GitHub-hosted macOS runners generate the Xcode project, build, test, sign and upload, so the app can be developed from Windows, from a Mac, or by an AI agent. That has these guarantees:

- No separately managed Mac is required for development, signing or TestFlight delivery. A local Mac is an optional faster loop.
- A persistent Mac is needed only for the optional live iMessage bridge.
- AI, backend services, sign-in, storage and messaging are independent capabilities. A basic app requires none of them.

## Agreed defaults

- Primary CI toolchain: **Xcode 27.0**, explicitly selected and verified on GitHub's **`xcode-27` public-preview runner**.
- SDK: the selected Xcode's bundled **iOS 27 SDK**. SDK and minimum supported OS are separate settings.
- Default app: **iPhone and iPad**, with **iOS/iPadOS 17** as the configurable minimum.
- Optional platforms: Watch, native Mac, Apple TV, and Vision Pro, enabled individually with their own build and test checks.
- Proposed optional-platform minimums: watchOS 10, macOS 14, tvOS 17, and visionOS 2. These become supported configurations only after their checks pass.
- Simulator lanes: required pull-request and `main` checks run on **iOS 27.0**. The manual and weekly **iOS compatibility matrix** plans one lane per iOS runtime available on the hosted images, paired with a Swift 6-capable Xcode. Verified smoke coverage as of 2026-10-16: iOS 17.0.1, 18.1, 26.0.1 and 27.0 ([run 38974328806](https://github.com/asavs/ios-app-starter/actions/runs/38974328806)). Coverage claims name only runtimes whose lane passed.
- Device delivery: manually triggered **TestFlight builds**. Apple Developer membership, account agreements, API access, and credential setup are part of onboarding.
- AI, backend services, authentication, storage, and messaging are independent capabilities. A basic app requires none of them.

Xcode and project-generation tools are pinned and upgraded deliberately. The hosted runner image itself can change; validate required tools and runtimes and fail clearly if they are unavailable.

## Milestones

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
| **8** | **Agent-comfortable iteration loop.** Structured failure output from `xcodebuild` and tests, a run-level review command, feedback-to-issue drafts, measured build caching, and a one-command authorized delivery. | An agent goes from a red run to a named failure in one command and from a fix on `main` to a build on the phone in one authorized dispatch, without opening the Actions UI. |
| **9** | **Module boundaries and app essentials.** Versioned Swift packages in this repository with independently enabled icon pipeline, onboarding, theme/UX, secure settings, then authentication and storage seams. | A basic app builds with no modules enabled. Each package has its own tests and lane. The demo app on the owner's phone consumes the first round through the existing delivery workflow. |
| **10** | **Agent onboarding runbook and guided setup, proven on a second app.** `docs/agent-onboarding.md`, a "Start here" route in `AGENTS.md`, a resumable `scripts/setup.py`, then a timed fresh-repository run and one backpropagation round-trip. | A fresh agent on a fresh machine reaches a build on a phone with only the human-only Apple/GitHub prompts; the first-run report lists every prompt and stall; a module change propagates to both apps by version bump. |
| **11** | **Optional backend and AI.** An authenticated app API, backend-owned shared provider keys, continuity runtime, and explicit provider adapters. | Non-AI apps remain independent. Package and mock-provider end-to-end tests pass; provider switching and failure behavior are explicit. Shared provider secrets stay outside app bundles, logs, and persisted conversations. |
| **12** | **Channel contracts and simulated iMessage bridge.** Identity mapping, authentication, message IDs, deduplication, retries, delivery state, and outbound-echo handling. | Channel and bridge tests pass entirely in GitHub Actions using simulated Messages events. |
| **13** | **Optional live iMessage bridge.** Deployment on a persistent owned or rented Mac signed into Messages; model credentials remain on the backend. | CI validates the bridge artifact and deployment configuration. A separate, explicitly enabled live send/receive acceptance check passes. |
| **14** | **Optional Apple platforms.** Watch first, then native Mac, TV, and Vision Pro. Support Watch companion and standalone configurations; assess Catalyst as an alternative Mac path. Generate required targets, identifiers, and capability configuration. | Each offered platform builds and tests independently on GitHub Actions. Signing/distribution is documented. Relevant-device acceptance checks are distinguished from cloud simulator checks. |
| **15** | **App Store publication and additional build options.** Metadata, release validation, submission tooling, and an optional self-hosted build path. | Upload, review submission, and publication are distinct, reviewable actions. Ordinary pull request CI remains on hosted runners; untrusted code cannot target a persistent runner holding a Messages session. |

**Renumbered 2026-10-16** to follow [the master plan](docs/master-plan.md). Documents and issues written earlier use the previous numbering: old 8 (modules) is now 9, old 9 (platforms) is now 14, old 10 (AI) is now 11, old 11 (simulated bridge) is now 12, old 12 (live bridge) is now 13, old 13 (publication) is now 15. Milestone 8 (iteration loop) and the onboarding/second-app proof in 10 are new. Optional platforms moved late because the module library is the product; they stay in the template because they are testable on hosted runners.

## Current status

As of 2026-10-24. Detailed evidence for every milestone is in [the setup journal](docs/setup-experience.md); the earlier status write-ups are in [the roadmap history](docs/archive/roadmap-history.md).

- **Milestones 1–7 are complete.** The app is generated from `project.yml` and built, tested and reported on GitHub-hosted Xcode 27.0. Configuration is validated with actionable errors. Apple setup diagnostics, signing and TestFlight delivery were accepted for the demo app, which the owner installed on their iPhone on 2026-10-12. Device failures are investigable from Windows, and the compatibility matrix verified the iOS 17.0 minimum on an iOS 17.0.1 simulator alongside 18.1, 26.0.1 and 27.0 ([run 38974328806](https://github.com/asavs/ios-app-starter/actions/runs/38974328806)).
- **Milestone 8 is in place.** Structured failure reports, the run review command, feedback-to-issue drafts, measured caching, one-command TestFlight delivery and `run-on-device` for Macs all exist. The optional ad hoc dev-build channel waits on a hosting decision.
- **Milestone 9, round one, is released.** Theme, Onboarding and Settings ship with TemplateVersion as module library `0.2.0` (2026-10-23). `0.3.0` (2026-10-24) made all module text translatable and moved Keychain calls off the main actor. See [docs/modules.md](docs/modules.md). Sign-in and the SwiftData layer are the second round, built when a real app asks for them.
- **Milestone 10 is in progress.** The [onboarding runbook](docs/agent-onboarding.md), its consent checklist and the resumable `scripts/setup.py` exist. Still to do: the timed run on a fresh second app and one backpropagation round-trip.

## Principles

Every module is a scaffold an app can keep, change or delete: the app builds with any subset enabled, and nothing enters the template until a real app needed it. Onboarding and examples are updated with every milestone. Finish with complete walkthroughs from Windows and from a Mac, and generated non-AI and AI examples proving optional modules remain optional.

Maintain [the setup experience journal](docs/setup-experience.md) throughout development. Record actual failures, fixes, important decisions, verification evidence, and unresolved limitations so future people and agents can reproduce the setup. Root `AGENTS.md` makes this part of the ongoing workflow.

Agent guidance should explain human-only Apple prerequisites, diagnose before changing anything, preview account changes, and keep secrets out of chat. Choose API key types and roles deliberately rather than defaulting to the broadest access. Windows users enter credentials through supported local secret storage or GitHub secrets; Mac Keychain is an optional local path.

Common logic belongs in shared packages; enabled platforms own their interface and lifecycle. An iPhone provides physical iPhone testing. Watch, Mac, TV, and Vision Pro hardware behavior requires the relevant device, another tester, or remote access; cloud tests do not establish physical-device coverage.

## Where Xcode output lives

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

## References

- [GitHub Xcode 27 runner announcement](https://github.com/actions/runner-images/issues/14404)
- [GitHub Xcode 27 runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md)
- [Apple SDKs and deployment-target support](https://developer.apple.com/xcode/system-requirements)
- [Apple App Store Connect API setup](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api)

The separate `platform-and-sdk-notes.md` preserves the earlier pasted text verbatim. This roadmap records the subsequently agreed decisions.
