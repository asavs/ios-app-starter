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

**First remote attempt:** [Run 37830316583](https://github.com/asavs/ios-app-starter/actions/runs/37830316583), commit `03d7931`, passed both configuration checks and all twelve negative probes. Both variants compiled, but the starter test runner crashed while bootstrapping and Pocket Notes timed out at `app.launch()` before the welcome-screen assertion. Downloaded both failure artifacts and inspected the named failures and exit 65. This is a launch/bootstrap failure, not a confirmed application or configuration defect; the internal cause is not established. Added an explicit native `simctl bootstatus -b` preparation step with a five-minute step limit and disabled parallel workers for the one-test smoke lane. Retry results will determine whether this preparation helps; do not convert failed tests to warnings.

**Artifact usability:** Mixing workspace configuration JSON and runner-temp test files made upload-artifact preserve long paths under their common ancestor. Moved the selected public configuration JSON beside the test reports in runner temp, so artifacts have a simple root. Updated summaries to name the actual matrix artifact. Built-app inspection now also runs after a failed test command, allowing metadata verification independently of simulator test success; a failed test still fails the job.

**Retry evidence and corrected diagnosis:** In [run 37831862240](https://github.com/asavs/ios-app-starter/actions/runs/37831862240), commit `28697b5`, both simulators booted in roughly 90 seconds. The starter passed all checks, including one welcome-screen test and actual app metadata verification. Its image was `20260928.0222.1`, while the stalled Pocket Notes job used `20261006.0244.1`; therefore image version alone does not explain the failures. Cancelled the remaining Pocket Notes job after roughly ten minutes in build/test to retrieve its logs. Those logs showed about five minutes of cold compilation, followed by app launch/automation setup. The test reached its label check at about 113 seconds and exceeded the 120-second execution allowance before finishing. Increased the per-test allowance to 300 seconds; kept a ten-minute build/test step limit and the existing 30-minute job bound. A cancelled job is not successful acceptance evidence. This establishes an overly tight test budget for this observed run; it does not identify the internal cause of every earlier bootstrap failure.

**Verified starter artifact:** Downloaded and inspected flat-root `configuration.json`/`built-app.json`, Markdown/JSON results, exit status, logs, and `.xcresult`. One test passed, zero failed, and the actual app declared Starter App, com.example.StarterApp, MinimumOSVersion 17.0, and UIDeviceFamily [1, 2]. The summary named ios-test-results-starter correctly.

### Completed milestone 3 evidence

- [Implementation commit 76c9db4](https://github.com/asavs/ios-app-starter/commit/76c9db4ee2723a4455e41bab54ed764cbc8d3a32).
- [Successful acceptance run 37833792319](https://github.com/asavs/ios-app-starter/actions/runs/37833792319): both jobs completed successfully using the explicitly selected Xcode 27.0, iOS SDK 27.0, and iPhone 17/iOS 27.0 simulator. Each executed one welcome-screen test with zero failures and exit 0. Actual method durations were roughly 16 seconds for the starter and 21 seconds for Pocket Notes; build/bootstrap time is additional.
- Both Debug and Release resolved settings were verified. Compiled Info.plist values confirmed Starter App/com.example.StarterApp and Pocket Notes/org.example.pocketnotes, with MinimumOSVersion 17.0 and UIDeviceFamily [1, 2] for both apps.
- All twelve actual manifest/generator/Xcode integration probes passed remotely: missing/invalid identifier, empty name, inconsistent/invalid/too-old minimum, unsupported device family/platform, absent shared scheme/UI-test reference, unconfigured capability, and missing source path.
- Downloaded and inspected both final artifacts: public configuration JSON and built-app JSON at the root, Markdown/JSON test summaries, exit status, logs, and one .xcresult each. DerivedData was absent and summaries named the correct matrix artifact. The five existing report tests also passed.
- The final jobs used both observed runner image versions: Pocket Notes on 20260928.0222.1 and the starter on 20261006.0244.1. Both passed. Keep the confirmed tight-budget failure distinct from the still-unexplained internal causes of earlier startup failures; this run does not prove the preview runner will never stall.
- GitHub metadata was queried again and confirmed PUBLIC visibility and template status enabled. Milestone 3 is complete; milestone 4 has not started.

No signing, installation, minimum-OS runtime coverage, or optional-platform support is claimed by this milestone.

## How to maintain this journal

Add dated entries as work proceeds. Explain the symptom, confirmed cause or uncertainty, fix, verification, and downstream implication. Keep reusable guidance in the README or focused setup guides and link to it from here. Keep the roadmap status accurate; do not claim completion while required checks are pending.

## 2026-10-08 — Milestone 4: portable Apple diagnostics

- Audited the ignored CLI checkout at `1fffe67d1` and release 5.14.0. MIT license, native Windows amd64 release, macOS/Linux amd64 and arm64 releases, and read-command pagination were inspected. Integration downloads binaries rather than building the Go 1.27.1 module; the upstream module's original owner name differs from the release repository. Published SHA-256 values are pinned in `scripts/install-asc.py`.
- Confirmed upstream telemetry is on by default and auth can fall back to stored profiles/config/Keychain. The wrapper removes inherited ASC settings except explicit credential fields, isolates the config path, bypasses Keychain, requests strict auth and disables telemetry. It never calls login or credential-persistence commands. Do not replace the wrapper with bare CLI commands when diagnosing secrets.
- The first local Python urllib download failed with `CERTIFICATE_VERIFY_FAILED` because this interpreter lacked a usable issuer certificate chain. This is an observed local runtime issue, not evidence that GitHub's certificate is invalid. Switched to system curl with normal TLS verification, then validated the pinned digest. Windows users need Python 3 and curl.exe. Never fix this by disabling TLS verification.
- CLI errors are human-readable and can omit HTTP status/code. Confirmed in `internal/asc/errors.go`; 401/403 specificity cannot be promised for every response. Recognizable denied/authentication language gets a specific status; all other failed reads remain unverified. Only a successful paginated empty response gets `missing`. Raw errors/responses are not exported.
- Diagnostics consume milestone 3's native `configuration.json`, rather than trying to emulate Xcode on Windows. Artifact freshness must be checked against the intended commit. Certificates are team inventory and profile existence does not establish archive/signing readiness.
- Eight local tests passed, including native 5.14.0 invalid-key rejection, credential-source isolation, permission failures, partial credentials, timeouts, malformed data and canary redaction. No valid Apple key was supplied and no live account readiness is claimed. Windows/Linux/macOS remote verification is pending in this implementation commit; results will be appended after inspecting runs/artifacts.
- Public repository/template flags were rechecked and remain enabled. Ordinary diagnostic jobs are secretless; opt-in account reads use a separate environment and a main-only manual job. Configure environment restrictions and branch protection in each generated repository; this guide does not claim such controls were automatically provisioned.
- While checking the new runs, discovered that the previous documentation commit's iOS run [37835335924](https://github.com/asavs/ios-app-starter/actions/runs/37835335924) had failed only at starter artifact upload: `Failed to CreateArtifact ... ENOTFOUND`. The build/test/metadata steps passed and Pocket Notes completed successfully. This establishes an artifact-endpoint DNS lookup failure; the underlying network cause is unknown. Do not reinterpret a failed report upload as a failed app test, and do not mark the overall run green. A fresh iOS run accompanies the milestone 4 commit; inspect its upload outcome before deciding whether a retry or workflow change is warranted.
- Local project inspection used the Mac's installed SDK 26.5; the milestone 4 GitHub configuration job explicitly asserts Xcode 27.0/SDK 27.0. Local exported settings alone do not verify the pinned remote toolchain.
- [348a929 manual diagnostics run](https://github.com/asavs/ios-app-starter/actions/runs/37838190831) passed on Windows/Linux/macOS and the pinned Xcode preview runner. Downloaded and inspected all JSON reports: SDK 27.0, minimum 17.0, placeholder identifier, missing credentials, and explicit unverified signing/device delivery. All eight tests ran after binary installation on each platform, including native invalid-key rejection.
- [The manually enabled account-job probe](https://github.com/asavs/ios-app-starter/actions/runs/37838380306) passed on Windows with no configured secrets. Before running, verified authenticated environment and repository-secret listings were empty. Download-artifact v6 and sanitized report upload worked. The job reported `accountRequested: true`, `credentials: not_configured`, and `account_reads: not_verified`; no authenticated Apple reads occurred. GitHub created the empty `apple-account` environment when executing the job; it has no secrets or protective policy configured by this work.
- Final audit found inline CLI key material is written to its OS temporary directory before normal cleanup. Confined child TMPDIR/TMP/TEMP to the wrapper-owned directory so a killed/timed-out child cannot leave a key elsewhere. Added a ninth test that simulates key-file creation followed by a subprocess timeout and verifies parent cleanup. Hard termination of the wrapper remains a cleanup limitation on persistent computers.
- Temporary-directory hardening commit `771b122` passed [Windows/Linux/macOS verification 37838797337](https://github.com/asavs/ios-app-starter/actions/runs/37838797337). Inspected logs show all nine tests passed after native binary installation, including child-timeout key-file cleanup and native invalid-credential rejection. This completes milestone 4's portable diagnostic gate. Live account verification remains user-specific and unperformed; signed archives and TestFlight delivery are future milestones, not implied by these green checks.
- [Fresh iOS regression run 37838166104](https://github.com/asavs/ios-app-starter/actions/runs/37838166104) passed for starter and Pocket Notes at `348a929`. Downloaded and inspected both result artifacts: each contains one passed welcome-screen test, zero failures, iOS 27.0, configuration metadata and compiled app metadata. Both artifact uploads succeeded. This establishes that the earlier `ENOTFOUND` upload failure did not repeat; its underlying network cause remains unknown. Small preview-runner smoke builds can still take several minutes; keep their actual results distinct from the much faster portable diagnostic checks.


## 2026-10-08 — Clarify credentials environment and repository description

- The name `apple-account` appeared as a GitHub deployment environment and confused account diagnostics with deployment. Renamed active workflow/guide references to `apple-credentials` and explained GitHub's deployment terminology. Historical entries above retain the original name to match their run evidence.
- GitHub's environment REST API identifies environments by name and has create/update/delete operations rather than an in-place rename field. Verified the old environment had zero secrets, zero variables, no protection rules and no branch policy; replaced this empty environment. For a populated environment, do not repeat that replacement blindly: secret values cannot be read back through the API, and protections/variables need deliberate migration.
- Reviewed all thirteen roadmap milestones. The previous GitHub description implied TestFlight delivery was already implemented and omitted the broader optional modules. Revised it to describe the Windows/GitHub Actions foundation and label TestFlight, additional Apple platforms, backend/AI features and the iMessage bridge as roadmap scope. Milestones 1–4 remain complete; signing is next, with TestFlight following.
- Verification of the live environment name, repository metadata and renamed manual diagnostic workflow is recorded below after completion. No Apple credentials or account operations are part of this rename.

- Rename implementation commit `32ba9eb` passed [manual diagnostics verification 37840884205](https://github.com/asavs/ios-app-starter/actions/runs/37840884205): all three portable jobs, fresh Xcode configuration and the Windows account job succeeded. Downloaded the newly named `apple-credentials-diagnostics` artifact and confirmed missing credentials/unverified account reads were reported correctly. Queried environment inventory: only `apple-credentials` remains. Repository description was read back and matches the broader planned scope; public visibility and template status remain enabled.


## 2026-10-08 — Schedule Windows setup follow-ups

Reviewed GitHub issues #1–4 and PR #5 at head `3f0983d`. Inspected the latest run 37849556702's downloaded configuration, compiled-app and test JSON for all three lanes: expected identities, SDK 27.0, minimum iOS 17.0, iPhone/iPad families, one passing test each and zero failures. All twelve invalid-configuration probes passed. No blocking change was found in the unsigned demo PR; it remains open at this planning update, and signing/device delivery remain unverified.

Added explicit milestone 5 dependency gates in `roadmap.md`: clear account-check status (#2), consistent manifest/identity selection, permissions before key selection (#1), capability/default guidance before App ID setup plus signed-entitlement verification (#3), name/display-name guidance before record creation (#4), and protected no-echo credential entry (#7). The existing diagnostics workflow still selects the default manifest; its demo-selection gap must be fixed before demo account checks/signing. Queue delays (#6) remain an observation to investigate if recurring, not a guessed app defect. Scheduling an issue is not completing it; closure requires acceptance evidence.

This change updates planning only. No project, workflow, Apple account, credential or signing changes were made, and no new build result is inferred from the documentation edit.


## 2026-10-08 — CI caching audit before signing work

The GitHub cache usage endpoint reported zero active caches and zero cached bytes. Neither workflow currently configures Actions caching. `generate-project.sh` downloads and extracts pinned XcodeGen into a new temporary directory on every invocation, including each invalid-configuration probe. `test-ios.sh` deliberately creates a fresh per-run DerivedData directory. No Swift package dependencies are declared in the current manifest, so package-cache setup would not yet save dependency resolution work.

Scheduled a small tool-download/reuse optimization before expanding milestone 5 workflows. Retain checksum verification on cache hits, separate keys by pinned tool and native platform, and verify cold/missing-cache behavior. Measure compile/bootstrap timing before caching DerivedData; a cache does not remove runner queue time or simulator startup. Credentials, profiles, signing private keys and signed release outputs must stay outside caches. No caching implementation or speed improvement is claimed by this audit.

## 2026-10-08 — Verified public tool-download reuse implementation

- Added a shared stdlib downloader used by the XcodeGen generation script and `asc` installer. It checks the pinned SHA-256 on every hit, repairs a tampered cache by redownloading verified bytes, and atomically publishes only verified downloads. The cached XcodeGen archive is extracted into a fresh directory for every generation. Cache paths contain public downloads only; no credential/config/DerivedData/release directory is included.
- Selected and SHA-pinned actions/cache v6.1.0 (`55cc8345863c7cc4c66a329aec7e433d2d1c52a9`) after checking its current release and Node 24 runner requirements. OS/architecture/version plus hashes of the scripts carrying the pins determine keys. The account job uses restore-only; ordinary unsigned jobs populate the caches. Existing Actions cache entries are immutable, so a repeatedly corrupt remote entry should be deleted rather than assuming a local repair updates that entry.
- Four meaningful download tests cover network-free warm reuse, tamper repair, rejection before publication and failed transport cleanup. All eighteen diagnostic/report/download tests passed locally. Removed the duplicated pre-install diagnostic test pass from the portable workflow; its complete suite now runs once after native binary installation.
- One local cold/warm measurement with an isolated cache: asc install 1.455s/0.152s; XcodeGen generation 1.551s/0.914s. This verifies local reuse and gives a single measurement, not a CI-wide speed promise. Remote cold/warm cache checks and iOS regression results remain pending for this implementation commit.
- No package dependencies currently justify package caching. Compiler-output caching, queue handling and simulator startup remain separate potential optimizations; do not infer that tool caching accelerates those phases.
