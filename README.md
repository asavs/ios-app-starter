# iOS App Starter

A clean, modular starting point for native iOS apps. The initial shell is a SwiftUI app with unit and UI test targets. It intentionally has no AI, backend, account, or product-specific dependencies yet.

## Requirements

- Xcode 26.2 or later
- iOS 17 or later for the app target

## Open and run

Open `StarterApp/StarterApp.xcodeproj` in Xcode, select the `StarterApp` scheme and an iOS simulator, then run.

To build and run the tests from Terminal:

```sh
xcodebuild \
  -project StarterApp/StarterApp.xcodeproj \
  -scheme StarterApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

The default bundle identifier is `com.example.StarterApp`; replace it before distributing an app.
