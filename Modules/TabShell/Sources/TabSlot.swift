/// What the native tab view selects: one of the host's tabs, or the shell's own More tab, which
/// holds the tabs a compact bar has no room for.
enum TabSlot<ID: Hashable>: Hashable {
    case tab(ID)
    case more
}
