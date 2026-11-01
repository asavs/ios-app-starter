import Foundation

/// The app's own links, `<scheme>://<tab>`, such as `starterapp://settings`. The scheme is
/// `APP_URL_SCHEME` in project.yml, registered in the Info.plist's `CFBundleURLTypes`.
///
/// Anything else is ignored: another scheme, a user or port, a path, query or fragment. A link is
/// untrusted input from any app or web page, so it only ever selects a tab; an app that adds routes
/// inside a tab, or actions, validates each one here before acting on it.
enum DeepLink {
    /// The schemes this app registers, lowercased.
    static let registeredSchemes: Set<String> = {
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        return Set(types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }.map { $0.lowercased() })
    }()

    /// The app's own link to a tab, `<scheme>://<tab>`, for a Live Activity or a widget to open;
    /// nil when the app registers no scheme.
    static func link(to tab: String, schemes: Set<String> = registeredSchemes) -> URL? {
        guard let scheme = schemes.sorted().first else { return nil }
        return URL(string: "\(scheme)://\(tab)")
    }

    /// The tab a link names, or `nil` when the URL is not one of the app's own tab links.
    /// The caller still checks that the tab exists, as `TabSelection.select(rawValue:)` does.
    static func tab(in url: URL, schemes: Set<String> = registeredSchemes) -> String? {
        guard let scheme = url.scheme?.lowercased(), schemes.contains(scheme),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.user == nil, components.password == nil, components.port == nil,
              components.path.isEmpty || components.path == "/",
              components.query == nil, components.fragment == nil,
              let tab = components.host, !tab.isEmpty
        else { return nil }
        return tab
    }
}
