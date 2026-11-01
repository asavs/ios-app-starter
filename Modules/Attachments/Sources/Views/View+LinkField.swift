import SwiftUI

extension View {
    /// A text field for a web address: no capitalisation and the URL keyboard on iOS; the package
    /// also builds for the Mac host, which has neither modifier.
    @ViewBuilder func linkFieldStyle() -> some View {
#if os(iOS)
        textInputAutocapitalization(.never)
            .keyboardType(.URL)
#else
        self
#endif
    }
}
