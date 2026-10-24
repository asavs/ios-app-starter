/// The version of the module library an app was built against.
///
/// `modules` is the source of truth for the repository's semantic-version tags: `scripts/tag-modules.py`
/// refuses to tag a version that differs from this constant. Apps that depend on a tagged version can
/// show or log it, which is how a backpropagation round-trip is observable on a phone.
public enum TemplateVersion {
    /// Semantic version of the module library, equal to the git tag that ships it.
    public static let modules = "0.2.0"
}
