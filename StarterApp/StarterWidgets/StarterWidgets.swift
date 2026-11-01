import SwiftUI
import WidgetKit
#if canImport(SessionActivity)
import SessionActivity
#endif

/// The app's widget extension: it draws the session's Live Activity (the SessionActivity module's
/// views) and nothing else yet. The `StarterWidgets` target in project.yml goes with the module:
/// remove both together, or add the app's own widgets here. Without the module (the no-modules
/// example) the bundle is empty and the app doesn't embed it.
@main
struct StarterWidgets: WidgetBundle {
    var body: some Widget {
#if canImport(SessionActivity)
        SessionActivityWidget()
#else
        NoWidgets()
#endif
    }
}

#if !canImport(SessionActivity)
/// A bundle needs one widget; this one configures nothing.
struct NoWidgets: Widget {
    var body: some WidgetConfiguration {
        EmptyWidgetConfiguration()
    }
}
#endif
