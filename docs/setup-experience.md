# Setup experience and troubleshooting journal

This is a living handoff for people and agents setting up the starter. Read it alongside [the roadmap](../roadmap.md). Entries record actual observations; planned improvements are explicitly labeled. Do not paste credentials or unredacted logs here.

## 2026-10-08 — Repository visibility and credentials

**Decision:** The repository was created private because visibility had not been specified. There is no architectural requirement for this starter to be private. It was initially kept private pending user authorization; the public transition is recorded below.

A public template can use GitHub Secrets for signing and upload credentials. Ordinary GitHub Variables are intended for non-sensitive configuration. Secrets can be injected into a job's environment when needed, but should not be embedded in workflow YAML or application code. Environment secrets are limited to jobs using that environment; configured reviewer requirements can gate access. Current build/test CI uses no Apple credentials and no release environment.

Public source does not automatically expose stored Secrets, but code receiving a secret can misuse or leak it. Keep unsigned PR validation separate from credential-bearing release jobs. Fork PR workflows do not normally receive repository secrets. Do not use a privileged workflow to execute untrusted PR code with release credentials. Log masking is a fallback, not permission to print secrets.

Standard GitHub-hosted runners, including the listed `xcode-27` preview runner, are free for public repositories. Private repositories use the account's included minutes and applicable billing. Larger runners have separate pricing; do not generalize the standard-runner policy to them.

**Future improvement:** Document supported GitHub plans, environment protection availability, release branch restrictions, and secret names when signing is implemented. Decide on a license before describing the starter as reusable open-source software; this entry does not choose one.

Sources checked on this date:

- [GitHub Secrets](https://docs.github.com/en/actions/concepts/security/secrets)
- [GitHub secret types and fork behavior](https://docs.github.com/en/code-security/reference/secret-security/secret-types)
- [GitHub Variables](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-variables)
- [GitHub-hosted runner availability and billing](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

## 2026-10-08 — Milestone 1: generated app and GitHub build

**Verified configuration:** Xcode 27.0, bundled iOS 27.0 SDK, XcodeGen 2.46.0, iPhone 17 simulator on iOS 27.0. App and test targets declare an iOS 17.0 minimum. Optional Apple platforms are not implemented yet.

| Observation | Resolution and evidence | Implication for future setup |
|---|---|---|
| Existing workflow selected Xcode 26.2 and iOS 26.2. | Changed to `runs-on: xcode-27`, selected `/Applications/Xcode_27.0.app/Contents/Developer`, and verified Xcode and SDK versions. Both checks passed on GitHub. | Preview runner label and selected Xcode version are distinct settings. Do not rely on the runner's default Xcode. |
| The project existed only as a manually created Xcode project. XcodeGen was not installed locally. | Added `project.yml` and a script downloading the pinned generator into a temporary directory, verifying SHA-256, and running it without a global installation. Regeneration reproduced the committed project. | Windows users edit the manifest and push; the runner executes generation. Pin the generator and update the checksum with version upgrades. |
| Initial launch test launched the app without asserting anything. Unit test was also a placeholder. | Added `testWelcomeScreen`, asserting that “Hello, world!” appears. CI explicitly selects this test. Run logs report one executed test, zero failures, and `TEST SUCCEEDED`. | A green process is not sufficient evidence of useful test coverage. The current gate is only a smoke test; feature tests belong with future capabilities. |
| No Git remote was configured. | Asked for the destination; user authorized creating a new remote. Created `asavs/ios-app-starter` privately and pushed the app and workflow. | Detect missing remotes early while continuing local preparation. Do not guess an existing destination repository. |
| `gh repo create ... --source=. --remote=origin` created the GitHub repository but failed to attach `origin`. | Added the remote separately using approved Git metadata access, then committed and pushed. | Repository creation can partially succeed. Inspect the resulting GitHub repository and local remotes before retrying; do not blindly create another repository. |
| Local `simctl` reported invalid CoreSimulator connections and denied access to simulator logs. | The restricted local execution environment could not access simulator services. Project parsing succeeded locally; the required simulator test ran successfully on GitHub. | Distinguish sandbox/service-access failures from application failures. Local simulator availability is not a prerequisite for the Windows workflow. |
| Local `gh run view --log` failed while writing its default cache. | Set `XDG_CACHE_HOME` to a writable temporary directory for that invocation; log retrieval then succeeded. | An API/log command may require local cache writes. Diagnose that path before changing authentication or workflow settings. |
| CI warned that `actions/checkout@v4` targets deprecated Node.js 20 and was forced onto Node.js 24. | The checkout and build passed. | Follow-up for milestone 2: deliberately update checkout to a supported action version and validate it. This is an observed warning, not a failed build. |
| App Intents metadata extraction warned that no AppIntents framework dependency was found. | Build and tests passed; the minimal app does not use App Intents. | Do not add capabilities merely to suppress unrelated metadata warnings. Revisit when adding App Intents. |
| App Store Connect CLI was cloned inside the starter checkout. | Added `/App-Store-Connect-CLI/` to `.gitignore`; the separate reference repository remains intact locally. | Future users cloning the starter do not receive this reference checkout. Fetch and audit it explicitly before integration; never accidentally stage a nested repository. |

**Verification:**

- [Implementation commit b67df32](https://github.com/asavs/ios-app-starter/commit/b67df3202a69430aa038866dd4a7d7bd6a073bae)
- [Initial successful generation/build/simulator run](https://github.com/asavs/ios-app-starter/actions/runs/37822420937), test job duration 2m37s.
- [Successful run after recording milestone completion](https://github.com/asavs/ios-app-starter/actions/runs/37822901771)
- Local checks: shell syntax, Xcode project property-list validity, target/scheme discovery, clean whitespace, and deterministic project regeneration.

**Coverage limits:** One UI smoke test ran on iOS 27.0. This does not prove iOS 17 runtime compatibility, device installation, signing, TestFlight delivery, or Windows execution of future CLI tools. At milestone 1, CI did not upload `.xcresult` artifacts; milestone 2 adds reports and retention.

### Retrieving logs in a restricted environment

On a Unix-like agent host, substitute the actual run ID and repository. This workaround concerns the agent's local cache, not the GitHub runner:

```sh
XDG_CACHE_HOME="$(mktemp -d)" gh run view RUN_ID --repo OWNER/REPO --log
```

Choose a writable cache location using the host's normal environment configuration on Windows. Do not infer that an inaccessible cache requires a new GitHub token.

## 2026-10-08 — GitHub template setting and milestone 2

**Template setting:** The user requested a GitHub template repository. Ran `gh repo edit asavs/ios-app-starter --template`, then queried repository metadata and verified `isTemplate: true`. Visibility was private at this step. People with access could use GitHub's **Use this template** button; marking a repository as a template does not make it public or copy credentials/settings into generated repositories. New owners must configure their own Actions and later release secrets.

**Reporting design:** `scripts/test-ios.sh` is the shared local-Mac/GitHub command. It creates a fresh report directory for every invocation, saves the build log, captures pipeline statuses immediately after `tee`, exports result-summary JSON with `xcresulttool`, and runs the Python Markdown reporter. The reporter rejects empty/unverified test runs instead of treating a zero command status as sufficient evidence.

**Failure verification:** A manually selected `verify_failure_reporting` input adds an explicit `XCTFail` after the welcome-screen assertion in the runner checkout only. The app remains unchanged, the test fails deliberately, and the workflow must stay red. Artifact upload uses `always()` so failed builds can retain reports. The probe is never enabled by ordinary push/PR events. Build failures may lack a readable `.xcresult`; the reporter falls back to text diagnostics. Setup failures before test execution may have no test artifact and must be diagnosed from step logs.

**Action upgrade:** Replaced checkout v4 with a pinned v6 commit (Node.js 24) and disabled persisted checkout credentials. Initially pinned upload-artifact v4; a successful run then showed that this action still targets Node.js 20. Changed upload-artifact to a pinned v6 commit after verifying its `action.yml` uses Node.js 24. Check runtime compatibility for every action, not just checkout. Artifact paths are limited to reports and result bundles, excluding DerivedData. The upgraded actions passed on GitHub, uploaded artifacts, and removed the Node.js 20 warning.

**Local verification:** Five report tests pass: success counts, named assertion failure, pre-test failure without results, a successful command without results, and zero executed tests. Shell syntax and whitespace checks pass. A controlled shell check also preserved exit 65 through `tee` and produced useful fallback diagnostics without a result bundle. Full success/failure reports and artifacts are verified below.

**Observed workflow validation failure:** The first milestone 2 push failed before executing jobs, and manual dispatch returned HTTP 422: `Unrecognized named-value: 'runner'` for `runner.temp` in job-level `env`. Moved the report-directory environment variable to the test step's `env`, where the runner context is supported. YAML parsing alone does not validate GitHub expression-context availability. Verify allowed contexts for the specific workflow field and confirm GitHub accepts the workflow before diagnosing app code.

**Slow failure probe:** The original negative run substituted a nonexistent UI label and stayed in the build/test step for roughly nine minutes while the normal run passed. Cancelled that run; no completed diagnostic report was available at that point, so the cause was not established. Changed the runner-only probe to an explicit `XCTFail` after the genuine welcome-screen assertion and enabled Xcode's 120-second per-test execution allowance. This bounds individual test execution, not simulator startup or all runner operations; the 30-minute job limit remains the overall bound. A cancelled probe is not evidence that failure reporting works; repeat and inspect a completed probe.

**Follow-up after cancellation:** The cancelled run's completed logs showed the assertion and test suite failed in about 26 seconds, followed by several minutes with no final command result. The delay was after test execution, so a per-test timeout alone does not address it. `xcodebuild -help` documents `-collect-test-diagnostics on-failure|never`, including verbose diagnostics such as sysdiagnose. Routine CI now selects `never`; opt into verbose collection with `IOS_TEST_DIAGNOSTICS=on-failure` for a dedicated investigation. Existing logs and `.xcresult` remain retained. With verbose collection disabled, the explicit-failure probe completed normally and uploaded the report. This supports diagnostic collection as the likely source of the earlier delay; the internal Xcode root cause was not independently proven.

### Completed milestone 2 evidence

Both final runs use implementation commit `f122dae`:

- [Successful run](https://github.com/asavs/ios-app-starter/actions/runs/37826317826): one passed UI test, zero failures, exit 0; report tests passed; artifact upload completed.
- [Deliberate failure run](https://github.com/asavs/ios-app-starter/actions/runs/37826318371): one failed UI test, exit 65, named `testWelcomeScreen()`, with “Deliberate failure probe: verify report delivery” in the Markdown summary and result JSON. The run correctly remains red while artifact upload succeeds.
- Downloaded and inspected both artifacts: Markdown and JSON summaries, exit status, complete logs, and `.xcresult` were present; DerivedData was excluded. These reports are readable from Windows without Xcode.
- Routine CI skips verbose diagnostics, retains standard result bundles, and uses pinned Node.js 24 checkout/upload actions. The job timeout is still the ultimate bound if simulator startup or finalization stalls.
- Cancelled investigative runs do not count as passing or completed failure verification. Milestone 2 is complete based on the final two inspected runs.

## 2026-10-08 — Public template and minimal configuration design

**Visibility:** The user explicitly authorized public visibility. Changed the GitHub repository to public and queried its metadata again: `visibility: PUBLIC`, `isTemplate: true`, URL `https://github.com/asavs/ios-app-starter`. Updated the README and roadmap to match. Earlier private-creation entries describe historical state.

**Design correction before implementation:** An initial proposal introduced a second app configuration file and custom validation/generation layer. The user asked to make the most of GitHub Actions and Xcode instead. No second configuration system was implemented. Revised milestone 3 to keep `project.yml` authoritative, use XcodeGen's built-in generation/structural validation, and inspect the generated project through `xcodebuild` in existing Actions jobs. Small policy checks are appropriate only where the existing tools do not enforce a template requirement.

**Breadcrumb for future agents:** Do not confuse native project validity with template policy or runtime compatibility. A valid Xcode project may still contain a placeholder bundle ID, unsupported template platforms, or capabilities that need account provisioning. Use actual resolved build settings and a customized remote build as evidence. App display name and internal module/target names need not be identical; unnecessary target renaming can break test imports and workflow selection. Milestone 3 remains pending until its required checks pass.

References: [XcodeGen project specification](https://github.com/yonaskolb/XcodeGen/blob/2.46.0/Docs/ProjectSpec.md), [Apple command-line build and test guidance](https://developer.apple.com/library/archive/technotes/tn2339/_index.html).

## 2026-10-08 — Milestone 3 configuration implementation

**Approach:** Retained the native XcodeGen manifest and fixed internal project/target/scheme names. Added a configurable Home Screen display name and a native `include`/override example named Pocket Notes. Actions validates both variants and builds/tests them independently. The policy checker uses `plutil`, `xcodebuild -list -json`, and all-target Debug/Release `-showBuildSettings -json`; it does not parse YAML or introduce a configuration service. A post-build check compares the simulator app's actual Info.plist with the validated configuration. Only selected public settings are saved as artifacts, not the full build environment.

**Output directory:** XcodeGen generation into a previously nonexistent custom directory failed with a Cocoa file-copy error. Creating the destination directory before generation fixed it. The generation script now supports `IOS_PROJECT_SPEC` and `IOS_PROJECT_DIR` for native example/probe specs, with the original defaults preserved.

**Misleading local Xcode result:** All-target settings inspection returned process status 0 but JSON contained per-target `error` fields and empty settings when the sandbox prevented writes to the default DerivedData directory. This first appeared as an unrelated bundle-ID error. The checker now rejects embedded Xcode errors explicitly and uses a writable temporary DerivedData location. `-derivedDataPath` requires a scheme, while `-alltargets` excludes schemes; the invocation-local `-IDECustomDerivedDataLocation=...` user default permits all-target inspection. This avoids changing global Xcode preferences. Local settings inspection uses Xcode 26.6/iOS SDK 26.5; remote acceptance still requires the pinned Xcode 27.0 runner.

**Invalid minimum silently accepted by native tools:** With `options.deploymentTarget.iOS: banana`, XcodeGen generated a project without explicit deployment settings, and Xcode resolved the minimum to its installed SDK version. A resolved-setting range check alone incorrectly accepted it. The checker now also requires explicit numeric project deployment settings in the generated native project, preventing this silent fallback. Preserve this negative integration probe when upgrading XcodeGen.

**Device-family inheritance:** A negative probe revealed that XcodeGen’s iOS target defaults override a project-level `TARGETED_DEVICE_FAMILY`. Moved the editable device-family setting onto the app target, where it takes effect. This reinforces why checks must inspect resolved settings and built output rather than assume manifest placement is sufficient.

**Scheme/capability probes:** Removing the shared scheme still left an automatically discovered scheme in `xcodebuild -list`; the checker therefore verifies the shared scheme file and its test references as well. Capability attributes generated by this XcodeGen version can appear as a non-dictionary value in the native project; reject this explicitly with an account-setup message rather than crashing during inspection. Native generation and policy probes use isolated directories, and individual cases can be reproduced by passing their names to `scripts/tests/check-configurations.py`.

**Verification:** Local and remote acceptance results will be recorded after the checks complete. No signing, installation, minimum-OS runtime coverage, or optional-platform support is claimed by this milestone.

## How to maintain this journal

Add dated entries as work proceeds. Explain the symptom, confirmed cause or uncertainty, fix, verification, and downstream implication. Keep reusable guidance in the README or focused setup guides and link to it from here. Keep the roadmap status accurate; do not claim completion while required checks are pending.
