/// Accessibility identifiers for the parts of the shell that aren't a host's tab, for UI tests.
public enum TabShellIdentifiers {
    /// The More tab, shown in a compact bar with more than five tabs.
    public static let more = "tabs.more"
    /// The back button from a tab opened from More to More's list (`tabShellMoreButton()`).
    public static let moreBack = "tabs.more.back"

    /// A tab's row in More's list, by its raw value.
    public static func moreRow(_ rawValue: String) -> String { "tabs.moreRow.\(rawValue)" }
}
