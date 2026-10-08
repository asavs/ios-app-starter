# iOS App Starter

A native Apple app starter built around **Windows → GitHub Actions → TestFlight → iPhone**. Users do not need a separately managed Mac. GitHub-hosted macOS runners perform the Xcode work.

The starter has a generated iPhone/iPad app and a passing remote build gate. Configuration validation, a renamed-app example, and portable success/failure reports have also been verified on GitHub. Signing, TestFlight delivery, and optional platforms are planned in [the roadmap](roadmap.md); they are not implemented yet.

## Develop from Windows

1. On GitHub, choose **Use this template → Create a new repository**. Enable Actions in your new repository if needed. This is a public GitHub template.
2. Edit Swift files under `StarterApp/StarterApp` using your preferred Windows editor or GitHub's browser editor.
3. Edit `project.yml` for project settings. It is the source of truth for the generated Xcode project.
4. Push to `main` or open a pull request. The **iOS** workflow generates the project, builds the app, and tests the welcome screen on an iPhone simulator.
5. Open the workflow run in GitHub's **Actions** tab. Read its test summary and download the **ios-test-results-starter** artifact (or **ios-test-results-pocket-notes** / **ios-test-results-starter-app-demo** for the examples) for full logs, JSON counts, and the `.xcresult` bundle. Artifacts are retained for 14 days. You can also select **iOS → Run workflow** to run it manually.

This first workflow is unsigned and needs no Apple credentials. It does not yet produce a build you can install on your iPhone. Signed TestFlight delivery is milestone 6.

## Current defaults

| Setting | Value |
|---|---|
| GitHub runner | `xcode-27` public preview |
| Xcode | 27.0, explicitly selected and verified |
| SDK | Bundled iOS 27.0 SDK |
| Simulator smoke test | iPhone 17, iOS 27.0 |
| Minimum OS | iOS/iPadOS 17.0, including test targets |
| Devices | iPhone and iPad |
| Project generator | XcodeGen 2.46.0, downloaded with SHA-256 verification |

The iOS 17 deployment target is configured but minimum-OS runtime coverage is not yet established. Watch, native Mac, TV, and Vision Pro targets will be optional; they are not generated yet.

The default bundle identifier is `com.example.StarterApp`; replace it before distribution.

## Configure your app from Windows

Edit the marked settings in `project.yml`, commit, and push. Actions regenerates the project before checking or building it; Windows users do not need XcodeGen installed locally. The checked-in project is convenient for Mac users.

| What to change | Location in `project.yml` | Example |
|---|---|---|
| Name shown on the Home Screen | `targets.StarterApp.settings.base.INFOPLIST_KEY_CFBundleDisplayName` | `"Pocket Notes"` |
| App identifier | `targets.StarterApp.settings.base.PRODUCT_BUNDLE_IDENTIFIER` | `org.example.pocketnotes` |
| Unit-test identifier | Same setting under `StarterAppTests` | `org.example.pocketnotes.tests` |
| UI-test identifier | Same setting under `StarterAppUITests` | `org.example.pocketnotes.uitests` |
| Minimum iOS/iPadOS | `options.deploymentTarget.iOS` | `"17.0"` |
| Supported devices | `targets.StarterApp.settings.base.TARGETED_DEVICE_FAMILY` | `"1,2"` for both, `"1"` for iPhone, `"2"` for iPad |

Choose distinct reverse-DNS bundle identifiers containing letters, numbers, hyphens, and periods. The `com.example` identifiers are usable for unsigned template checks; choose your own before signing/distribution. Keep project name, target names, Swift module/product names, and the `StarterApp` scheme stable. The displayed app name is independent of those internal names.

The initial supported deployment minimum is 17.0 or newer, up to the selected SDK version. Raising it does not install a newer test runtime: choose a compatible `IOS_TEST_DESTINATION` in the workflow if you raise it beyond the current simulator OS. For iPad-only apps, select an installed iPad simulator in `IOS_TEST_DESTINATION`. App and test targets must share the minimum; use the project-level setting instead of target overrides. A build against a newer SDK does not establish runtime coverage on the declared minimum.

The workflow selects its simulator in job-level `IOS_TEST_DESTINATION` and explicitly waits for it to boot, with a five-minute startup step limit. The single smoke test runs without parallel test workers.

**What Actions checks:** XcodeGen validates the native manifest and its references. `scripts/check-configuration.py` then inspects the generated project, shared scheme, and Xcode-resolved Debug/Release settings. Errors explain missing/invalid identifiers, blank names, invalid or inconsistent deployment minimums, missing tests, and unsupported platforms/capabilities. Initial capability/account signing setup is pending; entitlement files and enabled account capabilities are rejected for this unsigned starter. Do not enable Mac compatibility flags or add Watch, Mac, TV, or Vision Pro targets yet.

CI runs the starter and two [native XcodeGen override examples](examples/pocket-notes.yml) independently. The [Starter App demo](examples/starter-app-demo.yml) validates the separately registered demo identity; the reusable `project.yml` default remains `com.example.StarterApp`. Each configuration builds and tests the welcome screen, then checks the compiled app's `Info.plist` against the validated name, identifier, deployment minimum, and device families. The examples inherit the manifest but override the display name and three bundle identifiers. Artifacts include `configuration.json` and `built-app.json`, with only the checked public app settings. Setup/preflight failures appear in the Actions step logs; test summaries exist only after testing starts.

On an optional Mac, run generation followed by `python3 scripts/check-configuration.py`. Integration probes can be repeated with `python3 scripts/tests/check-configurations.py`; they use temporary projects and require Xcode, XcodeGen downloads, and no Apple credentials.

## Optional local Mac development

Windows users do not run these commands locally. On a Mac with Xcode, generate the project with:

```sh
bash scripts/generate-project.sh
```

The generated project is checked in for convenience, but changes belong in `project.yml`; regenerate after editing it. Open `StarterApp/StarterApp.xcodeproj` and select the `StarterApp` scheme.

With Xcode 27.0 and the iOS 27.0 simulator installed, run the same smoke test as CI:

```sh
bash scripts/test-ios.sh
```

The script prints its report directory under `build/test-results/`. Set `IOS_TEST_DESTINATION` to use another installed simulator, and `IOS_TEST_OUTPUT_DIR` to choose the reports directory. A nonzero build or test result remains a nonzero command exit even though output is captured through `tee`. A successful command with no verified passing tests is also rejected. Individual tests have a 300-second execution allowance; simulator startup has a five-minute step limit, build/test has a ten-minute step limit, and the job has a 30-minute overall limit. Adjust these workflow limits deliberately as the app grows. Routine CI skips verbose sysdiagnose collection after failures to avoid delaying reports. Set `IOS_TEST_DIAGNOSTICS=on-failure` for a dedicated diagnostic run if needed.

## Check failure reports

To check the complete failure-reporting path, manually run **iOS** with **verify_failure_reporting** selected. This injects an explicit failure after the welcome-screen assertion in the runner's temporary checkout, deliberately produces a failed test, and should make that run red. Inspect the summary for the test name and assertion failure; download the artifact to see the same details and complete logs. Normal push and PR runs never enable the probe. It does not upload an app or change committed source.

If failure happens before the test command starts, inspect the failed setup step in the Actions logs; test artifacts may not exist yet. `.xcresult` is primarily useful with Xcode, while Markdown, JSON, and text logs can be read on Windows.

## Reference tools

For setup troubleshooting and agent handoff, see [the experience journal](docs/setup-experience.md) and [agent instructions](AGENTS.md). The journal records observed problems, fixes, test evidence, and remaining gaps; update it as development proceeds.

`App-Store-Connect-CLI/` is a separately cloned reference checkout, excluded from this repository. Milestone 4 audited it and integrates a pinned release binary for optional account diagnostics. Unsigned app builds do not depend on it.

## Apple account setup and diagnostics

Follow [the Windows-first Apple setup guide](docs/apple-setup.md) for membership, API access, choosing a key, secure credential entry, and agent-assisted setup. Start without credentials:

```powershell
python scripts/apple-doctor.py
```

The **Apple diagnostics** workflow tests the portable commands on Windows, Linux and macOS. A manual run also exports the current Xcode configuration; optional account reads use a separate `apple-credentials` environment on `main`. Reports explain what is missing, inaccessible or unverified. Signing and TestFlight delivery remain the next milestones.

The CLI integration downloads pinned, checksum-verified `asc` 5.14.0 release binaries when requested. No source build, Go installation, cloud Mac account or Apple secret is needed for the ordinary diagnostic checks.
