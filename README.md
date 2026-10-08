# iOS App Starter

A native Apple app starter built around **Windows → GitHub Actions → TestFlight → iPhone**. Users do not need a separately managed Mac. GitHub-hosted macOS runners perform the Xcode work.

The starter has a generated iPhone/iPad app and a passing remote build gate. Portable success/failure reports and artifact uploads have also been verified on GitHub. Signing, TestFlight delivery, configuration tooling, and optional platforms are planned in [the roadmap](roadmap.md); they are not implemented yet.

## Develop from Windows

1. On GitHub, choose **Use this template → Create a new repository**. Enable Actions in your new repository if needed. This is a public GitHub template.
2. Edit Swift files under `StarterApp/StarterApp` using your preferred Windows editor or GitHub's browser editor.
3. Edit `project.yml` for project settings. It is the source of truth for the generated Xcode project.
4. Push to `main` or open a pull request. The **iOS** workflow generates the project, builds the app, and tests the welcome screen on an iPhone simulator.
5. Open the workflow run in GitHub's **Actions** tab. Read its test summary and download the **ios-test-results** artifact for full logs, JSON counts, and the `.xcresult` bundle. Artifacts are retained for 14 days. You can also select **iOS → Run workflow** to run it manually.

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

The script prints its report directory under `build/test-results/`. Set `IOS_TEST_DESTINATION` to use another installed simulator, and `IOS_TEST_OUTPUT_DIR` to choose the reports directory. A nonzero build or test result remains a nonzero command exit even though output is captured through `tee`. A successful command with no verified passing tests is also rejected. Individual tests have a 120-second execution allowance; simulator startup and cleanup are bounded separately by the workflow job limit. Routine CI skips verbose sysdiagnose collection after failures to avoid delaying reports. Set `IOS_TEST_DIAGNOSTICS=on-failure` for a dedicated diagnostic run if needed.

## Check failure reports

To check the complete failure-reporting path, manually run **iOS** with **verify_failure_reporting** selected. This injects an explicit failure after the welcome-screen assertion in the runner's temporary checkout, deliberately produces a failed test, and should make that run red. Inspect the summary for the test name and assertion failure; download the artifact to see the same details and complete logs. Normal push and PR runs never enable the probe. It does not upload an app or change committed source.

If failure happens before the test command starts, inspect the failed setup step in the Actions logs; test artifacts may not exist yet. `.xcresult` is primarily useful with Xcode, while Markdown, JSON, and text logs can be read on Windows.

## Reference tools

For setup troubleshooting and agent handoff, see [the experience journal](docs/setup-experience.md) and [agent instructions](AGENTS.md). The journal records observed problems, fixes, test evidence, and remaining gaps; update it as development proceeds.

`App-Store-Connect-CLI/` is a separately cloned reference checkout, excluded from this repository. It will be assessed for Apple setup and release tooling in milestone 4. Current builds do not depend on it.
