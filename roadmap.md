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

- Repository: [asavs/ios-app-starter](https://github.com/asavs/ios-app-starter) (private).
- Verified implementation commit: `b67df32`.
- Required remote check: [successful iOS build and simulator test](https://github.com/asavs/ios-app-starter/actions/runs/37822420937).
- **Milestone 2 is in progress:** reusable test execution, Markdown/JSON reports, and retained logs/result bundles. Completion requires a successful run and an intentional assertion-failure run with inspected reports and artifacts.

The cloned `App-Store-Connect-CLI` is a reference checkout for milestone 4, not an integrated template dependency. Audit its implementation, platform support, license, and command coverage before reuse.

## References

- [GitHub Xcode 27 runner announcement](https://github.com/actions/runner-images/issues/14404)
- [GitHub Xcode 27 runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md)
- [Apple SDKs and deployment-target support](https://developer.apple.com/xcode/system-requirements)
- [Apple App Store Connect API setup](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api)

The separate `platform-and-sdk-notes.md` preserves the earlier pasted text verbatim. This roadmap records the subsequently agreed decisions.
