The starter currently has **one iOS app target**. It’s set to iOS 17 and supports iPhone and iPad. It does **not** have a native Mac app or Apple Watch app target.

For a modular template, I’d make iPhone and iPad the default, with Mac, Watch, TV, and Vision Pro targets as optional modules. A Watch companion is a separate target with its own build and tests; enabling every platform by default would make the simplest app harder to build and maintain.

## SDK, deployment target, and test OS

These settings answer different questions:

| Setting                             | Meaning                                                                                                  |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------- |
| **Xcode and SDK**                   | Which compiler and platform APIs build the app. Our Mac has Xcode 26.6, which supplies the iOS 26.5 SDK. |
| **Deployment target**               | The oldest OS version the app claims to support. Ours is iOS 17.                                         |
| **Test destination**                | Which actual simulator OS runs the tests. The workflow currently selects iOS 26.2.                       |
| **Test target’s deployment target** | The oldest OS that can run the test bundle. It’s usually set to match the app’s minimum.                 |

So **building with the latest SDK does not mean requiring the latest iOS**. We can compile against a newer SDK, set iOS 17 as the minimum, and run the same tests on iOS 17, 18, and 26. Apple’s build settings distinguish the SDK from the deployment target. [Apple build settings documentation](https://developer.apple.com/documentation/xcode/build-settings-reference)

Testing **17, 18, 26, and 27** is a sensible goal: 17 is our minimum, 18 checks the previous release generation, 26 is current, and 27 checks current/new behavior. They don’t all need to block every commit:

- **Required:** iOS 17 and current stable iOS.
- **Useful compatibility check:** iOS 18, if we can provide that simulator runtime in CI.
- **Forward-compatibility check:** iOS 27 on a separate lane, initially allowed to fail while Xcode and runner support settle.

There’s a practical CI constraint: GitHub’s standard macOS 26 runner currently includes Xcode 26.6 and iOS 26 simulators, but its listed simulator runtimes don’t include iOS 17 or 18. The Xcode 27 runner has iOS 27 simulators, but GitHub still labels that runner image preview. So we’d need to install/provision the older runtimes for those CI lanes. [GitHub macOS 26 runner image](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md), [Xcode 27 runner image](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md)

## Is the latest SDK a disadvantage?

Using the latest **stable** SDK is usually beneficial: it exposes current APIs and keeps us ahead of Apple’s submission requirements. As of April 28, 2026, App Store submissions must use Xcode 26 or later and an iOS 26 SDK; App Store Connect also currently accepts Xcode 27.1 RC builds. [Apple’s upcoming requirements](https://developer.apple.com/news/upcoming-requirements/?id=02212025a), [App Store Connect release notes](https://developer.apple.com/help/app-store-connect/release-notes/)

The tradeoff is the required toolchain. People with older Macs may not be able to run the newest Xcode. For example, Xcode 27 requires Apple silicon and macOS 26.6 or later. A newer SDK can also bring compiler and API changes that uncover issues. [Xcode 27 release notes](https://developer.apple.com/documentation/Xcode-Release-Notes/xcode-27-release-notes)

The main thing to avoid is a **floating “latest” build environment** that changes without a deliberate update. Pin a known Xcode version, upgrade it on purpose, and keep the app’s deployment target separate. Since our Mac is already on Xcode 26.6, I’d make that the stable build-and-test toolchain; test 27 separately when we’re ready. Our current workflow is still pinned to Xcode 26.2, so it doesn’t yet match the Mac.
