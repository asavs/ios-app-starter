# Builds, tests and delivery on GitHub

This guide covers how the starter builds, tests, signs and ships an app on GitHub-hosted Macs, and how to read the results from any machine. The [README](../README.md) covers what the app contains and how to start one; this guide fills in its "Run it" and "What's handled for you" sections.

Everything here works from Windows because GitHub's runners do the Xcode work. A Mac is optional and only speeds up the inner loop.

## The pull-request loop

Open a pull request. The **iOS** workflow generates the project, builds the app, and runs its UI tests on an iPhone simulator. Its `ios-gate` check and the three portable `portable (...)` checks are required before merging to `main`. Documentation-only pull requests pass the gate without a simulator run, and draft pull requests wait until marked ready for review. Enable auto-merge (`gh pr merge <number> --auto --merge`) and move on; GitHub merges when the checks pass. Pushes to `main` run all three configurations, and a newer push to `main` cancels the superseded iOS run. Signing and TestFlight preflights run on pull requests or by manual dispatch, not again on push.

Open the workflow run in GitHub's **Actions** tab. Read its test summary and download the **ios-test-results-starter** artifact (or **ios-test-results-pocket-notes** / **ios-test-results-starter-app-demo** for the examples) for full logs, JSON counts, and the `.xcresult` bundle. Artifacts are retained for 14 days. You can also select **iOS → Run workflow** to run it manually.

This workflow is unsigned and needs no Apple credentials. It produces no installable build. Installable builds come from the manually triggered [TestFlight delivery workflow](testflight-delivery.md).

## What the checks verify

XcodeGen validates the native manifest and its references. `scripts/check-configuration.py` then inspects the generated project, shared scheme, and Xcode-resolved Debug/Release settings. Its errors explain missing or invalid identifiers, blank names, invalid or inconsistent deployment minimums, missing tests, and unsupported platforms or capabilities. Initial capability and account signing setup is pending, so the check rejects entitlement files and enabled account capabilities in this unsigned starter. Do not enable Mac compatibility flags or add Watch, Mac, TV, or Vision Pro targets yet.

CI runs the starter and two [native XcodeGen override examples](../examples/pocket-notes.yml) independently. The [Starter App demo](../examples/starter-app-demo.yml) validates the separately registered demo identity. The reusable `project.yml` default stays `com.example.StarterApp`. Each configuration builds and tests the welcome screen, then checks the compiled app's `Info.plist` against the validated name, identifier, deployment minimum, and device families. The examples inherit the manifest but override the display name and three bundle identifiers. Artifacts include `configuration.json` and `built-app.json`, which hold only the checked public app settings. Setup and preflight failures appear in the Actions step logs. Test summaries exist only after testing starts.

The workflow selects its simulator in job-level `IOS_TEST_DESTINATION` and waits for it to boot, with a five-minute limit on the startup step. The app's UI suite runs without parallel test workers and covers the welcome screen, onboarding, theme and settings when enabled.

On an optional Mac, run generation followed by `python3 scripts/check-configuration.py`. To repeat the integration probes, run `python3 scripts/tests/check-configurations.py`. They use temporary projects and need Xcode and XcodeGen downloads, but no Apple credentials.

## Configuration rules

Edit the marked settings in `project.yml`, commit, and push. Actions regenerates the project before checking or building it, so Windows users do not need XcodeGen installed. The checked-in project is there for Mac users' convenience.

Choose distinct reverse-DNS bundle identifiers containing letters, numbers, hyphens, and periods. The `com.example` identifiers work for unsigned template checks. Choose your own before signing or distribution. Keep project name, target names, Swift module/product names, and the `StarterApp` scheme stable. The displayed app name is independent of those internal names.

The deployment minimum can be 17.0 or newer, up to the selected SDK version. Raising it does not install a newer test runtime, so choose a compatible `IOS_TEST_DESTINATION` in the workflow if you raise it beyond the current simulator OS. For iPad-only apps, select an installed iPad simulator in `IOS_TEST_DESTINATION`. App and test targets must share the minimum. Use the project-level setting, not target overrides. A build against a newer SDK does not establish runtime coverage on the declared minimum.

The iOS 17.0 deployment target is backed by a passing smoke test on an iOS 17.0.1 simulator (Xcode 16.2) in the weekly compatibility matrix; required checks still run on iOS 27.0. Watch, native Mac, TV and Vision Pro targets will be optional. They are not generated yet.

## Local Mac development

On a Mac with Xcode, generate the project with:

```sh
bash scripts/generate-project.sh
```

The generated project is checked in for convenience, but make changes in `project.yml` and regenerate after editing it. Open `StarterApp/StarterApp.xcodeproj` and select the `StarterApp` scheme.

With Xcode 27.0 and the iOS 27.0 simulator installed, run the same UI suite as CI:

```sh
bash scripts/test-ios.sh
```

The script prints its report directory under `build/test-results/`. Set `IOS_TEST_DESTINATION` to use another installed simulator, and `IOS_TEST_OUTPUT_DIR` to choose the reports directory. A failed build or test still exits nonzero even though `tee` captures the output. The script also fails a run that succeeds with no verified passing tests. Each test may run for 300 seconds. In the workflow, simulator startup has a five-minute step limit, build and test a 20-minute step limit, and the job a 30-minute limit overall. Change these limits deliberately as the app grows. Routine CI skips verbose sysdiagnose collection after failures so reports are not delayed. For a dedicated diagnostic run, set `IOS_TEST_DIAGNOSTICS=on-failure`.

## Run on your iPhone from a Mac

With an iPhone connected over USB or Wi-Fi (Developer Mode on, computer trusted), build a Debug app, install it and launch it without a commit, upload or TestFlight:

```sh
IOS_CONFIGURATION=starter-app-demo IOS_DEVELOPMENT_TEAM=<your 10-character team ID> bash scripts/run-on-device.sh
```

The script regenerates the project and picks the single connected, paired iPhone or iPad (set `IOS_DEVICE` when several are paired). It builds with Xcode automatic signing for the given team, installs with `devicectl`, launches the app, and prints the exact relaunch command. `IOS_DEVICE_CONSOLE=1` streams the app's console. `IOS_RUN_ON_DEVICE_DRY_RUN=1` prints every command without running it; an agent uses this to preview the run. From an SSH session, unlock the login keychain first. If automatic signing then picks a certificate from another keychain, point `IOS_SIGNING_KEYCHAIN` at the keychain holding the working identity; the script narrows the search list for the build and restores it afterwards (details in the script header). Expect an account-side change the first time you use a team: Xcode may create or refresh a development profile for that team and device. The default `com.example.StarterApp` identifier may not be provisionable under your team because bundle identifiers are global, so use the demo configuration or your own identifier. Logs and build products go to the gitignored `build/run-on-device/`.

To run the unit and UI tests on the phone instead, use `bash scripts/test-on-device.sh` with the same environment. It leaves the Debug app (shown as "Starter Dev", from `DEV_DISPLAY_NAME`) installed and uninstalls the UI test runner afterwards, even when a test fails. Keep the phone unlocked while it runs: a locked phone fails before the first test with "Timed out while enabling automation mode".

## Read failure reports

To check the whole failure-reporting path, run **iOS** manually with **verify_failure_reporting** selected. The run injects a failure after the welcome-screen assertion in the runner's temporary checkout, so one test fails and the run should go red. Check the summary for the test name and assertion failure, and download the artifact for the same details and complete logs. Normal push and PR runs never enable the probe. It does not upload an app or change committed source.

Every test artifact contains `summary.md` and `failures.json` with the same facts: a stage (`passed`, `tests_failed`, `build_failed`, `setup_failed` or `unverified`), each failed test with its file, line and message, compiler errors with file, line and column, and the test-produced screenshots under `attachments/` (the smoke test always attaches `welcome-screen`). Agents read `failures.json`; people read `summary.md`, which is also the job summary. If the run fails before the test command starts, test artifacts may not exist yet, so inspect the failed setup step in the Actions logs. `.xcresult` is mostly useful with Xcode. The Markdown, JSON and text logs can be read on Windows.

The iOS and compatibility artifacts retain the complete exported `attachments/` directory, including screenshots, recordings and failure text such as spindumps. After a failed test command, they also export the bundle's existing diagnostic `.log` files under `diagnostics/`, including XCTest session and testmanagerd logs. Exporting these logs does not turn on expensive diagnostics collection. Do not judge a file's type by an attachment's suggested name: an unfinished `Screen Recording` can be a short text error placeholder. Use controlled sample data in recorded UI tests, as with screenshots. If xcresult omits a failed XCTest's source location, the report recovers it from `xcodebuild.log`, but only when the test identity and failure message match one unambiguous location. The report keeps existing locations and the run's failure status.

For an intermittent terminate/relaunch failure, run **UI lifecycle diagnostics** with an app commit or tag and either `starter` or `pocket-notes`:

```bash
gh workflow run ui-lifecycle-diagnostics.yml --ref main --field app_ref=main --field configuration=pocket-notes --field attempts=1
```

This manual probe builds once on Xcode 27.0, then runs only the onboarding persistence UI test on a freshly erased CI simulator, once by default or up to 3, 5 or 10 times. It stops at the first failure and stays red. Start with one attempt. The build has an eight-minute limit, the test step twelve minutes, and simulator reset operations have their own deadlines, so a slow batch may stop before it reaches its maximum attempt count. Its `ui-lifecycle-<configuration>` artifact records separate app and tooling commits, phase markers, per-attempt results, exported attachments and a host process timeline containing timestamps, load, and app PIDs/state/CPU without command arguments. Lightweight evidence uploads first. Complete result bundles upload separately as `ui-lifecycle-bundles-<configuration>`. Heavy native diagnostics are off by default; after inspecting the lightweight evidence, select `collect_diagnostics=true` for a dedicated follow-up. Use a fixed app SHA to compare unchanged sources. A missing process means something only if the timeline first saw that app running, and a Home Screen recording alone cannot show that the process exited. Passing repetitions show only that the failure did not reproduce in that batch. They do not establish a fix.

Download the manual probe's evidence with `gh run download RUN_ID --name ui-lifecycle-pocket-notes --dir build/lifecycle-review`, replacing `RUN_ID` with the run number (and the artifact's configuration when needed). Start with `context.json`, each attempt's `phase.txt` and `failures.json`, and `process-timeline.log`. A simulator-reset timeout with no test counts is a setup failure, not an application test result.

## Review CI evidence from any machine

With GitHub CLI authenticated and the repository checked out, review a pull request's hosted checks and sanitized artifacts together:

```powershell
python scripts/review_ci.py --pr 123
```

Or review one run, or the newest run on your branch, the same way:

```powershell
python scripts/review_ci.py --run 38974328806
python scripts/review_ci.py --latest --workflow iOS --no-download
```

`--run` shows the workflow, event, head, each job's conclusion and elapsed time, and the recognized artifacts; for the compatibility matrix it prints the verified runtimes and every lane's status, device, toolchain and counts. `--latest` picks the newest run for the checkout branch (`--branch` to override, `--workflow` to filter) and says which run it chose. Replace `123` with the pull request number. The command shows check conclusions and elapsed time, labels skipped jobs, downloads recognized test and preflight artifacts to a temporary directory, and reports test counts, simulator runtime, compiled app identity, symbol UUIDs, and artifact links. For merged pull requests it also finds workflows for the exact merge commit. It compares the current checkout commit with the PR head and prints `MATCH` or `MISMATCH`; use `--require-checkout-head` to fail when they differ, or `--no-download` to list checks and links only. A TestFlight preflight symbol match verifies the unsigned archive app/dSYM. Exported-IPA matching is reported only when a delivery artifact contains that check. The command reads only selected sanitized fields and never prints raw logs or account diagnostic contents.

## Deliver to TestFlight in one command

When a change is on `main` with a green smoke run, one command proposes the build, dispatches **TestFlight delivery** with `perform_upload`, waits for the `apple-credentials` gate, and reports each stage:

```powershell
python scripts/deliver_testflight.py --configuration starter-app-demo --dry-run
python scripts/deliver_testflight.py --configuration starter-app-demo
```

The proposal names the `main` head, the newest iOS push run for it and any delivery already in flight (a second dispatch is refused while one is running). The `apple-credentials` environment allows deployments from `main` and has no required reviewer in this repository's setup. `--approve` is still available for template users who add that optional protection. If no deployment is pending, the command continues without trying to approve. The final report lists release-plan, delivery-validation, upload-report and processing-report statuses from the sanitized artifact and ends with one line: processed by Apple (`VALID`), upload accepted but still processing, or the exact failing job and step, with a warning when the upload was accepted before a later step failed. `--run <id>` resumes a run after a timeout (exit code 3). See [the delivery guide](testflight-delivery.md).

## Apple account setup and diagnostics

Follow [the Windows-first Apple setup guide](apple-setup.md) for membership, API access, choosing a key, secure credential entry, and agent-assisted setup. Start without credentials:

```powershell
python scripts/apple-doctor.py
```

The **Apple diagnostics** workflow tests the portable commands on Windows, Linux and macOS. A manual run lets you choose `starter`, `pocket-notes` or `starter-app-demo` and exports that manifest's current Xcode configuration. For your own app, edit `project.yml` and choose `starter`. Optional account reads use the same run's export and a separate `apple-credentials` environment on `main`. The job summary shows which account checks were skipped, failed or completed. A green diagnostic does not mean signing is ready. Follow [TestFlight delivery](testflight-delivery.md) for workflow details, including the **TestFlight groups** workflow that creates an auto-distributing internal group through the pinned CLI.

The CLI integration downloads pinned, checksum-verified `asc` 5.14.0 release binaries when requested. No source build, Go installation, cloud Mac account or Apple secret is needed for the ordinary diagnostic checks.

## Test on older iOS versions

See [the diagnostics plan](device-diagnostics.md) for the design boundary and [the tester feedback guide](tester-feedback.md) for the verified loop: a tester submits TestFlight feedback, Windows reads it with the fixed `scripts/read-testflight-feedback.py` command or the App Store Connect browser, and actionable items become sanitized GitHub issues. TestFlight preflight verifies the archive's app and dSYM UUIDs. Keeping symbols in a private repository is optional and off for this public template. The manual **iOS runtime inventory** workflow reports a hosted image's actual Xcode, SDK and simulator runtimes without building anything.

Required pull-request checks test iOS 27.0 only. The manual and weekly **iOS compatibility matrix** workflow inventories each hosted macOS image, pairs every available iOS runtime with a Swift 6-capable Xcode on that image, runs the same smoke test on each pairing, and publishes one coverage report naming only the runtimes whose lane passed. Hosted inventory on 2026-10-16 found iOS 17.0.1 through 27.0 across the `macos-14`, `macos-15` and `xcode-27` images, and the first `main` dispatch ([run 38974328806](https://github.com/asavs/ios-app-starter/actions/runs/38974328806)) passed on iOS 17.0.1, 18.1, 26.0.1 and 27.0. Dispatch it with:

```powershell
gh workflow run ios-compatibility.yml --ref main --field configuration=starter --field selection=one-per-major
```

Use `selection=all` for every available runtime or `minimum` for the lowest one. Download **compatibility-report** for the table, or an individual **ios-compat-starter-ios-17-0-1** style artifact for that lane's logs. Each test job inventories its own runner and plans the requested runtime again there before it resolves an exact Xcode version, build and SDK. Reports keep the discovery plan and record the toolchain that ran, so jobs do not need identical builds while a hosted-image update is rolling out. Compatibility is claimed only for runtimes whose lane passed. A passing simulator lane verifies the smoke test on that runtime and toolchain; it says nothing about behavior on a physical device.

## Recommended repository settings

After creating a repository from this template, preview and apply the settings the pull-request loop relies on:

```powershell
python scripts/configure-github-repo.py --repo <owner>/<repository>
python scripts/configure-github-repo.py --repo <owner>/<repository> --apply
```

The dry run shows the current and intended values. `--apply` turns on auto-merge and head-branch deletion, enables secret scanning with push protection, restricts actions to GitHub-owned and verified creators, requires approval for every fork contributor's workflows, adds a default-branch ruleset that requires a pull request with passing `ios-gate` and `portable (...)` checks, and configures `apple-credentials` for exactly `main` with no required reviewer. Template users can add a reviewer with `--require-reviewer` (and then `--apply`) or in **Settings → Environments → `apple-credentials` → Required reviewers**. The ruleset blocks direct pushes to `main` for everyone, including the owner.

## Faster manual iteration

The **iOS** manual workflow offers `configuration=starter`, `pocket-notes`, or `starter-app-demo` for one app, with `all` as the default. Pull requests test `starter` only; pushes to `main` test all three configurations, since the examples are overlays of the same code. For example, from PowerShell:

```powershell
gh workflow run ios.yml --ref main --field configuration=starter-app-demo --field verify_failure_reporting=false
```

Use `verify_failure_reporting=true` only for the controlled check that is expected to go red. Artifact names still identify the selected app. A new commit on a PR cancels that PR's obsolete iOS run, and a newer push to `main` cancels an older iOS push run. Manual runs are independent. This lane stays unsigned and credential-free.

The workflow uploads `ios-test-results-<configuration>` for each configuration it runs, so a single-app dispatch produces one matching test artifact and `all` produces all three.

## Tool-download caching

Actions caches the public, pinned XcodeGen archive and `asc` release downloads under `build/tool-downloads/`, plus Xcode's cloned Swift package sources under `build/swiftpm-cache/` for the app, module and compatibility lanes. Tool cache keys separate operating system, architecture, version and the scripts containing the pinned digests. Every tool download rechecks SHA-256, and a missing or invalid cache downloads and verifies the pinned asset again. Swift package cache keys include the operating system, architecture, Xcode version, package manifests and resolved pins. After a manifest change an older entry may be restored, and SwiftPM still resolves and validates the requested revisions. DerivedData and test and build products are never cached. A miss continues with a normal dependency fetch.

The scripts also reuse verified downloads within a job or local checkout. Project generation requires Python 3, curl and unzip alongside the existing Mac tools. Override `IOS_XCODEGEN_CACHE_DIR` or the CLI installer's `--cache-dir` for an isolated download cache; set `IOS_SPM_CACHE_DIR` to choose an isolated Xcode package-clone directory. The account job restores public tool downloads but does not save caches. Credentials, profiles, compiler output, signed archives and test reports are outside these cache paths. Existing Actions cache entries cannot be changed, so corruption that comes back after each restore may mean deleting the affected entry. The current root package has no remote dependencies. Swift package caching is in place for packages added later and does not speed up CI today.

## Reference tools

For setup troubleshooting and agent handoff, see [the experience journal](setup-experience.md) and [agent instructions](../AGENTS.md). The journal records observed problems, fixes, test evidence and remaining gaps. Update it as development goes on.

`App-Store-Connect-CLI/` is a separately cloned reference checkout, excluded from this repository. After an audit, the starter uses a pinned release binary of it for optional account diagnostics. Unsigned app builds do not depend on it.
