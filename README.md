# iOS App Starter

[![Status: in development](https://img.shields.io/badge/status-in%20development-orange)](roadmap.md)
[![iOS and iPadOS 17+](https://img.shields.io/badge/iOS%20%7C%20iPadOS-17%2B-blue?logo=apple)](#current-defaults)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](#current-defaults)
[![Xcode 27](https://img.shields.io/badge/Xcode-27-147EFB?logo=xcode&logoColor=white)](#current-defaults)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A starting point for a native iPhone and iPad app. Onboarding, theming, settings and secure storage are already built, tested and accessible, and each one is a module you keep or delete. You start on the part that makes your app different.

Building, testing, signing and shipping to TestFlight are handled for you on GitHub's Macs, so you can work from a Mac, from Windows, or with an AI agent doing the setup.

## What you get

A SwiftUI app for iPhone and iPad, iOS 17 and later, that already has:

| Module | What it gives you |
| --- | --- |
| **Onboarding** | A first-launch flow built from steps you pick: a welcome sheet, tour cards, a question with fixed answers, a permission primer, or your own view. Shown once per version, skippable, and followed by TipKit tips that wait until it's done. |
| **Theme** | Colors, spacing, corner radii and text styles in one place, plus buttons, cards and an empty state that follow dark mode and Dynamic Type. Change the accent once at the root. |
| **Settings** | A settings screen with an appearance picker, app info, and a row for secrets stored in the Keychain. |
| **TemplateVersion** | The module version the app was built against, shown on the welcome screen. |

Also included:

- **Translations.** Every piece of text is in a string catalog, the app's and each module's, ready for more languages.
- **Accessibility.** VoiceOver labels, Dynamic Type up to the largest sizes, and 44-point touch targets, with a UI test at the largest text size.
- **Tests.** Unit tests per module and UI tests that walk each feature and attach screenshots.
- **A placeholder icon** you can personalize with one command, in Apple's Icon Composer format.

Planned next, as real apps ask for them: sign-in (Sign in with Apple), a database layer on SwiftData with a schema guide, chat and AI with cloud or on-device models, an iMessage bridge, and Watch, Mac, TV and Vision Pro targets. See the [roadmap](roadmap.md).

## Start your app

1. On GitHub, choose **Use this template → Create a new repository**.
2. Name the app in [`project.yml`](project.yml), the single source of truth for the Xcode project:

   | What | Setting in `project.yml` | Example |
   |---|---|---|
   | Home Screen name | `targets.StarterApp.settings.base.INFOPLIST_KEY_CFBundleDisplayName` | `"Pocket Notes"` |
   | Name of development builds | `targets.StarterApp.settings.base.DEV_DISPLAY_NAME` | `"Notes Dev"` |
   | App identifier | `targets.StarterApp.settings.base.PRODUCT_BUNDLE_IDENTIFIER` | `org.example.pocketnotes` |
   | Test identifiers | The same setting under `StarterAppTests` and `StarterAppUITests` | `org.example.pocketnotes.tests` |
   | Minimum iOS | `options.deploymentTarget.iOS` | `"17.0"` |
   | Devices | `targets.StarterApp.settings.base.TARGETED_DEVICE_FAMILY` | `"1,2"` both, `"1"` iPhone, `"2"` iPad |

   Keep the internal names (`StarterApp` targets and scheme) as they are; the Home Screen name is separate from them. [`examples/pocket-notes.yml`](examples/pocket-notes.yml) shows a renamed app.
3. Give it its own icon: `python scripts/personalize-icon.py` ([icon guide](docs/app-icon.md)).
4. Keep only the modules you want. Each is one product line under `targets.StarterApp.dependencies` in `project.yml`; delete the line and the app still builds, because the template only uses a module when it's present. [`examples/no-modules.yml`](examples/no-modules.yml) is the app with none of them.
5. Build your screens in `StarterApp/StarterApp/`. `StarterAppApp.swift` sets up the theme and the onboarding steps; `ContentView.swift` is the welcome screen to replace.

How modules work, how to change one and how to move an app to a tagged version: [docs/modules.md](docs/modules.md).

## Run it

**On a Mac with Xcode 27:** `bash scripts/generate-project.sh`, then open `StarterApp/StarterApp.xcodeproj` and run the `StarterApp` scheme. `bash scripts/test-ios.sh` runs the same UI tests as CI. With your iPhone connected:

```sh
IOS_DEVELOPMENT_TEAM=<your team ID> bash scripts/run-on-device.sh
```

That builds, installs and launches a development build on the phone in about a minute, with no upload. Use your own app identifier, or `IOS_CONFIGURATION=starter-app-demo`; details in [docs/ci.md](docs/ci.md#run-on-your-iphone-from-a-mac).

**From Windows, or anywhere without Xcode:** edit, push and open a pull request. GitHub builds the app on a Mac, runs the tests on a simulator and posts the results with screenshots. Nothing to install.

**On your phone through TestFlight:** once Apple setup is done, one command builds, signs and uploads from `main`:

```sh
python scripts/deliver_testflight.py --configuration starter-app-demo
```

Apple setup takes an Apple Developer membership and an App Store Connect API key; [docs/apple-setup.md](docs/apple-setup.md) walks through it, and [docs/testflight-delivery.md](docs/testflight-delivery.md) covers delivery.

## What's handled for you

- **Builds and tests on GitHub's Macs.** Every pull request builds the app and runs its UI tests on an iPhone simulator; a merge needs them green. Reports name the failing test, file and line, so you or an agent can fix it without opening Xcode. [docs/ci.md](docs/ci.md)
- **No Mac required.** Xcode work runs on GitHub, so Windows works for everything except the optional live iMessage bridge.
- **Signing and TestFlight.** Credentials live in GitHub Secrets; pull requests never see them. [docs/testflight-delivery.md](docs/testflight-delivery.md)
- **Older iOS versions.** A weekly run tests the app on every iOS version GitHub's Macs offer, back to iOS 17. [docs/ci.md](docs/ci.md#test-on-older-ios-versions)
- **Tester feedback.** TestFlight feedback can be read from the command line and turned into issues. [docs/tester-feedback.md](docs/tester-feedback.md)
- **Setup by an AI agent.** An agent can take a fresh copy of this repository to the app on your phone, asking you only for what Apple and GitHub require a person to do. [docs/agent-onboarding.md](docs/agent-onboarding.md)

## Current defaults

| Setting | Value |
|---|---|
| Xcode | 27.0 on GitHub's `xcode-27` runner, with the iOS 27.0 SDK |
| Minimum OS | iOS and iPadOS 17.0 |
| Devices | iPhone and iPad |
| Simulator for required checks | iPhone 17, iOS 27.0 |
| Project generator | XcodeGen 2.46.0 |

The default identifier, `com.example.StarterApp`, works for builds and tests; choose your own before signing.

## Working on the starter itself

Read [AGENTS.md](AGENTS.md) first. The [roadmap](roadmap.md) holds the agreed decisions and what's next, and the [setup journal](docs/setup-experience.md) records what went wrong along the way and how it was fixed.

## License

MIT; see [LICENSE](LICENSE). The placeholder icon is Apple's Icon Composer demo under Apple's own terms (`third_party/apple-icon-composer-demo/`); replace it before shipping.
