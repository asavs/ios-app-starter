# Builds, tests and delivery on GitHub

How the starter builds, tests, signs and ships an app on GitHub-hosted Macs, and how to read the results from any machine. The [README](../README.md) covers what the app contains and how to start one. Everything here works from Windows; a Mac only speeds up the inner loop.

## The pull-request loop

Open a pull request. The **iOS** workflow generates the project, builds the app and runs its UI tests on an iPhone simulator. Its `ios-gate` check and the three `portable (...)` checks must pass before merging to `main`. Documentation-only pull requests pass the gate without a simulator run; drafts wait until marked ready for review. Enable auto-merge (`gh pr merge <number> --auto --merge`) and move on. Pushes to `main` test all three configurations. Signing and TestFlight preflights run on pull requests or manual dispatch, not again on push.

Each run's test summary is in GitHub's **Actions** tab. For full logs, JSON counts and the `.xcresult` bundle, download the **ios-test-results-starter** artifact (**ios-test-results-pocket-notes** / **ios-test-results-starter-app-demo** for the examples). Artifacts are kept for 14 days.

The workflow is unsigned, needs no Apple credentials and produces no installable build. Installable builds come from the manual [TestFlight delivery workflow](testflight-delivery.md).

## What the checks verify

XcodeGen validates the manifest and its references. `scripts/check-configuration.py` then inspects the generated project, shared scheme and Xcode-resolved Debug/Release settings, with errors that name missing or invalid identifiers, blank names, bad or inconsistent deployment minimums, missing tests, and unsupported platforms or capabilities. Capability and account signing setup is still pending, so the check rejects entitlement files and enabled account capabilities. Do not enable Mac compatibility flags or add Watch, Mac, TV or Vision Pro targets yet.

CI runs the starter and two [XcodeGen override examples](../examples/pocket-notes.yml) independently; the examples inherit the manifest and override the display name and three bundle identifiers. The [Starter App demo](../examples/starter-app-demo.yml) uses the separately registered demo identity, while the reusable `project.yml` default stays `com.example.StarterApp`. Each configuration builds and tests the app, then checks the compiled `Info.plist` against the validated name, identifier, deployment minimum and device families. Artifacts include `configuration.json` and `built-app.json`, which hold only those public settings.

The simulator is set in the job-level `IOS_TEST_DESTINATION`, with a five-minute limit on booting it. The UI suite runs without parallel workers and covers the welcome screen, onboarding, theme and settings when enabled.

On a Mac, run generation followed by `python3 scripts/check-configuration.py`. `python3 scripts/tests/check-configurations.py` repeats the integration probes in temporary projects; it downloads Xcode and XcodeGen dependencies but needs no Apple credentials.

## Configuration rules

Edit the marked settings in `project.yml`, commit and push. Actions regenerates the project before checking or building, so Windows users don't need XcodeGen.

Bundle identifiers must be distinct reverse-DNS names of letters, numbers, hyphens and periods. The `com.example` identifiers are fine for unsigned checks; choose your own before signing. Keep the project name, target names, Swift module/product names and the `StarterApp` scheme as they are; the displayed name is independent of them.

The deployment minimum can be 17.0 up to the SDK version. App and test targets must share it, set at project level rather than per target. Raising it does not install a newer test runtime, so if you raise it past the current simulator OS, pick a compatible `IOS_TEST_DESTINATION`; for iPad-only apps, pick an installed iPad simulator. Building against a newer SDK says nothing about runtime behavior on the minimum.

The iOS 17.0 minimum is backed by a passing smoke test on an iOS 17.0.1 simulator (Xcode 16.2) in the weekly compatibility matrix; required checks run on iOS 27.0.

## Local Mac development

On a Mac with Xcode, generate the project with:

```sh
bash scripts/generate-project.sh
```

The generated project is checked in for convenience, but change `project.yml` and regenerate. Open `StarterApp/StarterApp.xcodeproj` and select the `StarterApp` scheme.

With Xcode 27.0 and the iOS 27.0 simulator installed, run the same UI suite as CI:

```sh
bash scripts/test-ios.sh
```

Reports go to a directory under `build/test-results/`, which the script prints; `IOS_TEST_OUTPUT_DIR` changes it and `IOS_TEST_DESTINATION` picks another installed simulator. The script exits nonzero on a failed build or test even though `tee` captures the output, and also when a run succeeds with no verified passing tests. Each test may run for 300 seconds. In the workflow, build and test have a 20-minute step limit and the job 30 minutes; raise these deliberately as the app grows. CI skips sysdiagnose collection after failures to keep reports quick; set `IOS_TEST_DIAGNOSTICS=on-failure` for a dedicated diagnostic run.

## Run on your iPhone from a Mac

With an iPhone connected over USB or Wi-Fi (Developer Mode on, computer trusted), build, install and launch a Debug app with no commit, upload or TestFlight:

```sh
IOS_DEVELOPMENT_TEAM=<your 10-character team ID> bash scripts/run-on-device.sh
```

The script regenerates the project, picks the single paired iPhone or iPad (set `IOS_DEVICE` when several are paired), builds with Xcode automatic signing for the team, installs with `devicectl`, launches the app and prints the relaunch command. `IOS_DEVICE_CONSOLE=1` streams the app's console; `IOS_RUN_ON_DEVICE_DRY_RUN=1` prints every command without running it, which is how an agent previews the run.

The first run with a team changes the account: Xcode may create or refresh a development profile for that team and device. Bundle identifiers are global, so the default `com.example.StarterApp` may not be provisionable under your team; set your own identifier in `project.yml` first. From an SSH session, unlock the login keychain first; if automatic signing then picks a certificate from another keychain, point `IOS_SIGNING_KEYCHAIN` at the one holding the working identity (the script header has details). Logs and build products go to the gitignored `build/run-on-device/`.

To run the unit and UI tests on the phone, use `bash scripts/test-on-device.sh` with the same environment. It leaves the Debug app ("Starter Dev", from `DEV_DISPLAY_NAME`) installed and removes the UI test runner afterwards, even when a test fails. Keep the phone unlocked: a locked phone fails before the first test with "Timed out while enabling automation mode".

## Read failure reports

Every test artifact contains `summary.md` (for people, and also the job summary) and `failures.json` (for agents) with the same facts: a stage (`passed`, `tests_failed`, `build_failed`, `setup_failed` or `unverified`), each failed test with file, line and message, compiler errors with file, line and column, and test screenshots under `attachments/` (the smoke test always attaches `welcome-screen`). If a run fails before testing starts there may be no test artifacts; read the failed setup step in the Actions log. The Markdown, JSON and text logs are readable on Windows; `.xcresult` is mostly useful in Xcode.

The iOS and compatibility artifacts keep the whole exported `attachments/` directory, including recordings and failure text such as spindumps. After a failed test command they also export the bundle's existing diagnostic `.log` files, including XCTest session and testmanagerd logs, under `diagnostics/`; this does not turn on expensive collection. Don't trust an attachment's suggested name for its type: an unfinished `Screen Recording` can be a short text error. Use controlled sample data in recorded UI tests. When xcresult omits a failed test's source location, the report recovers it from `xcodebuild.log`, but only if the test and message match exactly one location.

To check the reporting path end to end, run **iOS** manually with **verify_failure_reporting** selected. It injects a failure after the welcome-screen assertion in the runner's temporary checkout, so one test fails and the run goes red; the summary and artifact should both show the test name and assertion. Push and PR runs never enable it, and it uploads nothing and changes no committed source.

For an intermittent terminate/relaunch failure, run **UI lifecycle diagnostics** with an app commit or tag and either `starter` or `pocket-notes`:

```bash
gh workflow run ui-lifecycle-diagnostics.yml --ref main --field app_ref=main --field configuration=pocket-notes --field attempts=1
```

It builds once on Xcode 27.0, then runs only the onboarding persistence UI test on a freshly erased simulator, once by default or 3, 5 or 10 times, stopping red at the first failure. Start with one attempt; the build (eight minutes), test step (twelve minutes) and simulator resets have time limits, so a slow batch may stop early. Use a fixed app SHA to compare unchanged sources. The `ui-lifecycle-<configuration>` artifact uploads first, with app and tooling commits, phase markers, per-attempt results, attachments and a host process timeline (timestamps, load, app PIDs/state/CPU, no command arguments); full result bundles follow as `ui-lifecycle-bundles-<configuration>`. Heavy native diagnostics are off; select `collect_diagnostics=true` for a follow-up after reading the lightweight evidence.

Download the evidence with `gh run download RUN_ID --name ui-lifecycle-pocket-notes --dir build/lifecycle-review`, replacing `RUN_ID` with the run number (and the configuration when needed). Start with `context.json`, each attempt's `phase.txt` and `failures.json`, and `process-timeline.log`. When reading it:

- A missing process matters only if the timeline first saw the app running; a Home Screen recording alone can't show the process exited.
- A simulator-reset timeout with no test counts is a setup failure, not a test result.
- Passing repetitions mean the failure didn't reproduce in that batch, not that it is fixed.

## Review CI evidence from any machine

With GitHub CLI authenticated and the repository checked out, review a pull request's checks and sanitized artifacts together (replace `123` with the PR number):

```powershell
python scripts/review_ci.py --pr 123
```

Or review one run, or the newest run on your branch:

```powershell
python scripts/review_ci.py --run 38974328806
python scripts/review_ci.py --latest --workflow iOS --no-download
```

`--run` shows the workflow, event and head. The command shows each check's conclusion and elapsed time, labels skipped jobs, downloads recognized test and preflight artifacts to a temporary directory, and reports test counts, simulator runtime, compiled app identity, symbol UUIDs and artifact links. For the compatibility matrix it prints the verified runtimes and each lane's status, device, toolchain and counts. `--latest` picks the newest run on the checkout branch (`--branch` to override, `--workflow` to filter) and says which it chose. For merged PRs it also finds workflows for the merge commit. It prints `MATCH` or `MISMATCH` for the checkout commit against the PR head; `--require-checkout-head` fails on a mismatch, and `--no-download` lists checks and links only. A TestFlight preflight symbol match covers the unsigned archive's app and dSYM; exported-IPA matching appears only when a delivery artifact contains it. It reads only selected sanitized fields and never prints raw logs or account diagnostics.

## Deliver to TestFlight in one command

Once a change is on `main` with a green smoke run, one command proposes the build, dispatches **TestFlight delivery** with `perform_upload`, waits for the `apple-credentials` gate and reports each stage:

```powershell
python scripts/deliver_testflight.py --configuration starter --dry-run
python scripts/deliver_testflight.py --configuration starter
```

The proposal names the `main` head, its newest iOS push run and any delivery in flight; a second dispatch is refused while one runs. `apple-credentials` allows deployments from `main` with no required reviewer by default; `--approve` is for template users who add one, and without a pending deployment the command just continues. The report lists release-plan, delivery-validation, upload-report and processing-report statuses and ends with one line: processed by Apple (`VALID`), accepted and still processing, or the failing job and step, with a warning if the upload was accepted before a later step failed. `--run <id>` resumes after a timeout (exit code 3). See [the delivery guide](testflight-delivery.md).

## Apple account setup and diagnostics

[The Apple setup guide](apple-setup.md) covers membership, API access, choosing a key, entering credentials securely and agent-assisted setup. Start without credentials:

```powershell
python scripts/apple-doctor.py
```

The **Apple diagnostics** workflow tests these commands on Windows, Linux and macOS. A manual run exports the current Xcode configuration for `starter`, `pocket-notes` or `starter-app-demo`; for your own app, choose `starter`. Optional account reads use that run's export and the `apple-credentials` environment on `main`, and the job summary shows which checks were skipped, failed or completed. A green diagnostic does not mean signing is ready. It downloads pinned, checksum-verified `asc` 5.14.0 binaries when needed, so no source build, Go, cloud Mac or Apple secret is required for the ordinary checks. [TestFlight delivery](testflight-delivery.md) covers the rest, including the **TestFlight groups** workflow that creates an auto-distributing internal group.

## Test on older iOS versions

Required pull-request checks test iOS 27.0 only. The manual and weekly **iOS compatibility matrix** workflow inventories each hosted macOS image, pairs every available iOS runtime with a Swift 6-capable Xcode on that image, runs the smoke test on each pair, and publishes a coverage report naming only the runtimes that passed. On 2026-10-16 the `macos-14`, `macos-15` and `xcode-27` images offered iOS 17.0.1 through 27.0, and the first `main` dispatch ([run 38974328806](https://github.com/asavs/ios-app-starter/actions/runs/38974328806)) passed on iOS 17.0.1, 18.1, 26.0.1 and 27.0. Dispatch it with:

```powershell
gh workflow run ios-compatibility.yml --ref main --field configuration=starter --field selection=one-per-major
```

Use `selection=all` for every runtime or `minimum` for the lowest. Download **compatibility-report** for the table, or a lane artifact such as **ios-compat-starter-ios-17-0-1** for its logs. Each lane re-plans on its own runner and records the exact Xcode, build and SDK it used, so lanes can differ while a hosted-image update rolls out. A passing lane verifies the smoke test on that simulator runtime and toolchain, not on a physical device. The manual **iOS runtime inventory** workflow reports an image's Xcode, SDK and simulator runtimes without building.

For real devices, [the tester feedback guide](tester-feedback.md) describes the verified loop: a tester sends TestFlight feedback, Windows reads it with `scripts/read-testflight-feedback.py` or the App Store Connect website, and actionable items become sanitized GitHub issues. [The diagnostics plan](device-diagnostics.md) sets the design boundary. TestFlight preflight verifies the archive's app and dSYM UUIDs; keeping symbols in a private repository is optional and off for this public template.

## Recommended repository settings

After creating a repository from this template, preview and then apply the settings the pull-request loop relies on:

```powershell
python scripts/configure-github-repo.py --repo <owner>/<repository>
python scripts/configure-github-repo.py --repo <owner>/<repository> --apply
```

The dry run shows current and intended values. `--apply` turns on auto-merge and head-branch deletion, secret scanning with push protection, restricts actions to GitHub-owned and verified creators, requires approval for every fork contributor's workflows, adds a ruleset requiring a pull request with passing `ios-gate` and `portable (...)` checks on the default branch, and limits `apple-credentials` to `main` with no required reviewer. To add a reviewer, use `--require-reviewer` (then `--apply`) or **Settings → Environments → `apple-credentials` → Required reviewers**. The ruleset blocks direct pushes to `main` for everyone, including the owner.

## Faster manual iteration

A manual **iOS** run takes `configuration=starter`, `pocket-notes` or `starter-app-demo` for one app, or `all` (the default). Pull requests test `starter` only; pushes to `main` test all three. From PowerShell:

```powershell
gh workflow run ios.yml --ref main --field configuration=starter-app-demo --field verify_failure_reporting=false
```

Set `verify_failure_reporting=true` only for the controlled check that is meant to go red. Each configuration run uploads its own `ios-test-results-<configuration>` artifact. A new commit cancels the PR's older iOS run, and a newer push to `main` cancels the older push run; manual runs are independent. This lane stays unsigned and credential-free.

## Make a social preview card

A link to your repository on LinkedIn, X or Slack shows its social preview image. `scripts/social-preview.py` draws a 1280×640 card (rendered at 2560×1280) in light and dark: your app's icon (rendered from `StarterApp/StarterApp/AppIcon.icon`) beside the title, a tagline, up to four feature rows with drawn icons, one line of chips and up to three UI test screenshots.

Describe the card once in `.github/social-preview.json`:

```json
{
  "title": "Pocket Notes",
  "tagline": "Notes that sync to every device.",
  "features": [
    {"icon": "sparkle", "label": "Smart folders"},
    {"icon": "chat", "label": "Ask your notes", "soon": true}
  ],
  "chips": ["swiftui", "icloud", "widgets"],
  "screens": ["onboarding-welcome", "welcome-screen", "theme-dark"]
}
```

Every field is optional. Without a title or tagline the card uses the Home Screen name in `project.yml` and the repository description. A card shows feature rows or chips, not both: with `features` the chips are left off; without them it shows `chips`, or else the repository's first three topics (`"chips": []` hides them). Feature icons: `modules`, `chat`, `bridge`, `backend`, `lock`, `sparkle`, `globe`, `check`. `"soon": true` adds a SOON tag. The icons are drawn by the script, so the card contains no Apple symbol or emoji artwork.

`screens` names up to three UI test screenshots, front first; the names are the `attach(name:)` names in `StarterAppUITests` (the template's include `welcome-screen`, `onboarding-welcome`, `onboarding-choice`, `onboarding-tour`, `onboarding-permission`, `settings-screen`, `theme-light` and `theme-dark`). Without `screens` the card uses `onboarding-welcome`, `welcome-screen` and `settings-screen`. A name with no screenshot is skipped, and the script lists the names it found. To show a screen of your own, attach a screenshot of it in a UI test.

On a Mac with Xcode 26 or later, after `bash scripts/test-ios.sh`:

```sh
python3 scripts/social-preview.py
```

`--title`, `--tagline`, `--chip` and `--screen` override the config for one run. The cards land in `build/social-preview/`.

From Windows or anywhere else, run the **Social preview** workflow:

```sh
gh workflow run social-preview.yml --ref main
```

It reads the same config, reuses the screenshots from the newest passing iOS run on `main`, and attaches the cards to the run as the `social-preview` artifact for 7 days, with `app-icon.png` at README size; nothing is committed. Upload one under **Settings → General → Social preview**; GitHub has no API for that setting and takes files up to 1 MB, so the script writes a JPEG beside any larger PNG.

## Keep the README icon in sync

The README header shows `docs/images/icon.png`. To have it follow your app icon without a Mac, add `"readme_icon": "app"` to `.github/social-preview.json` and let workflows open pull requests:

```sh
python scripts/configure-github-repo.py --repo <owner>/<repository> --allow-workflow-prs
python scripts/configure-github-repo.py --repo <owner>/<repository> --allow-workflow-prs --apply
```

Then every change to `StarterApp/StarterApp/AppIcon.icon` on `main` runs the **README icon** workflow: it renders the icon at 512 px and, if `docs/images/icon.png` differs, opens a pull request with auto-merge. A pull request opened with the workflow token does not start other workflows, so the job starts the required iOS and portable checks on its branch itself. Run it by hand with `gh workflow run readme-icon.yml --ref main`. On a Mac, `python3 scripts/social-preview.py --readme-icon docs/images/icon.png` does the same render locally.

## Tool-download caching

Actions caches the pinned XcodeGen archive and `asc` downloads under `build/tool-downloads/`, and Xcode's cloned Swift package sources under `build/swiftpm-cache/` for the app, module and compatibility lanes. Tool cache keys cover operating system, architecture, version and the scripts holding the pinned digests; every download rechecks SHA-256, and a missing or invalid entry is downloaded and verified again. Swift package keys cover operating system, architecture, Xcode version, manifests and resolved pins; after a manifest change an older entry may be restored, and SwiftPM still resolves and validates the requested revisions. The root package has no remote dependencies yet, so this cache does not speed up CI today. DerivedData and build and test products are never cached, and a miss falls back to a normal fetch.

The scripts also reuse verified downloads within a job or checkout. Project generation needs Python 3, curl and unzip besides the Mac tools. For isolated caches, set `IOS_XCODEGEN_CACHE_DIR` or the CLI installer's `--cache-dir`, and `IOS_SPM_CACHE_DIR` for package clones. The account job restores tool downloads but saves no caches. Credentials, profiles, compiler output, signed archives and test reports are outside the cache paths. Actions cache entries can't be changed, so corruption that returns after each restore may mean deleting that entry.

## Reference tools

[The experience journal](setup-experience.md) records observed problems, fixes, test evidence and remaining gaps; update it as you go. [Agent instructions](../AGENTS.md) cover agent handoff.

`App-Store-Connect-CLI/` is a separately cloned reference checkout, excluded from this repository. After an audit, the starter uses a pinned release binary of it for optional account diagnostics; unsigned builds don't depend on it.
