import Foundation

/// The version an app shows in its settings, read from the bundle's Info.plist.
public enum AppInfo {
    /// `"1.0 (42)"` from `CFBundleShortVersionString` and `CFBundleVersion`; `nil` when the bundle has neither.
    public static func version(in bundle: Bundle = .main) -> String? {
        format(version: bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
               build: bundle.infoDictionary?["CFBundleVersion"] as? String)
    }

    static func format(version: String?, build: String?) -> String? {
        switch (version?.nonEmpty, build?.nonEmpty) {
        case (let version?, let build?) where version != build: "\(version) (\(build))"
        case (let version?, _): version
        case (nil, let build?): build
        case (nil, nil): nil
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
