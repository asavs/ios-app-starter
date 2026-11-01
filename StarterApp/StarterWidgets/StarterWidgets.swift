import SessionActivity
import SwiftUI
import WidgetKit

/// The app's widget extension: it draws the session's Live Activity (the SessionActivity module's
/// views) and nothing else yet. The `StarterWidgets` target in project.yml goes with the module:
/// remove both together, or add the app's own widgets here.
@main
struct StarterWidgets: WidgetBundle {
    var body: some Widget {
        SessionActivityWidget()
    }
}
