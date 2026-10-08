# iOS App Starter

A native Apple app starter built around **Windows → GitHub Actions → TestFlight → iPhone**. Users do not need a separately managed Mac. GitHub-hosted macOS runners perform the Xcode work.

The current milestone is a minimal iPhone/iPad app and a remote build gate. Signing, TestFlight delivery, configuration tooling, and optional platforms are planned in [the roadmap](roadmap.md); they are not implemented yet.

## Develop from Windows

1. Put this starter in your own GitHub repository with Actions enabled.
2. Edit Swift files under `StarterApp/StarterApp` using your preferred Windows editor or GitHub's browser editor.
3. Edit `project.yml` for project settings. It is the source of truth for the generated Xcode project.
4. Push to `main` or open a pull request. The **iOS** workflow generates the project, builds the app, and tests the welcome screen on an iPhone simulator.
5. Check the workflow result in GitHub's **Actions** tab. You can also select **iOS → Run workflow** to run it manually.

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
xcodebuild \
  -project StarterApp/StarterApp.xcodeproj \
  -scheme StarterApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:StarterAppUITests/StarterAppUITests/testWelcomeScreen \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Reference tools

`App-Store-Connect-CLI/` is a separately cloned reference checkout, excluded from this repository. It will be assessed for Apple setup and release tooling in milestone 4. Current builds do not depend on it.
