/// When the shell builds a new tab view: after a reorder, and when More comes or goes. See `TabShell.body`.
struct TabViewIdentity: Hashable {
    let reorders: Int
    let overflows: Bool
}
