/// What a change to the list of tabs did to their order.
enum TabOrder {
    /// Whether tabs on both lists changed places. Tabs only coming or going isn't a reorder.
    static func isReorder<ID: Hashable>(from old: [ID], to new: [ID]) -> Bool {
        let kept = Set(old).intersection(new)
        return old.filter(kept.contains) != new.filter(kept.contains)
    }
}
