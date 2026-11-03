import Foundation
#if canImport(SessionTimer) && canImport(SessionActivity)
import SessionActivity
import SessionTimer

/// The app's one Live Activity controller, and what the activity's pause button does.
///
/// Shared, not per screen: the system performs `ToggleSessionIntent` in the app's process, in the
/// background and possibly without any scene, so the handler works on the stored `SessionRecord`
/// and updates the activity itself. `StarterAppApp` installs it at launch.
@MainActor
final class StarterSessionActivity {
    static let shared = StarterSessionActivity(defaults: StarterDefaults.store)

    let controller: SessionActivityController
    /// Called after the activity's button changed the stored record in this process, so a Timer
    /// screen on show follows it: the island is visible, and its button works, while the app is
    /// in the foreground, when no scene phase change would make the screen look again.
    var recordChanged: (@MainActor () -> Void)?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, host: any SessionActivityHost = ActivityKitHost()) {
        self.defaults = defaults
        controller = SessionActivityController(host: host) {
            SessionActivityPreferences(defaults: defaults).isEnabled
        }
    }

    /// Point the activity's intents here. Call once, as early as the app launches.
    func installIntents() {
        SessionActivityIntents.toggle = { [weak self] id in await self?.toggle(id) }
    }

    /// The attributes for a session: the plan's name, its identity, and the link back to the tab.
    static func attributes(for plan: TimerPlan, sessionID: UUID) -> SessionActivityAttributes {
        SessionActivityAttributes(planTitle: String(localized: plan.title), sessionID: sessionID,
                                  link: DeepLink.link(to: StarterTab.timer.rawValue))
    }

    /// Pause a running session or resume a paused one, from its stored record.
    func toggle(_ id: UUID) async {
        guard var record = SessionRecord.load(from: defaults), record.id == id, let plan = record.sessionPlan else { return }
        let now = ContinuousClock.now
        let date = Date.now
        var clock = SessionClock(plan: plan, state: record.clock, at: now, date: date)
        if clock.snapshot(at: now).status == .running { clock.pause(at: now) } else { clock.start(at: now) }
        record.clock = clock.state(at: now, date: date)
        record.save(to: defaults)
        controller.sessionChanged(clock.snapshot(at: now), plan: plan,
                                  attributes: Self.attributes(for: record.plan, sessionID: record.id))
        recordChanged?()
        await controller.drain()
    }

    /// The Live Activity setting changed in Settings: show the running session's activity when it's
    /// now on, remove it when it's off. Re-sending the stored session does both, since the controller
    /// reads the setting on every change; a tick inside a phase never reaches it, so without this a
    /// setting turned on mid-phase would show nothing until the next pause or phase.
    func settingChanged() {
        reattach()
    }

    /// On launch: bring an activity from an earlier process up to date with the stored session, and
    /// end every other one, the stored session's included when it is gone (a reset, or Erase Local
    /// Data) or doesn't parse. An activity nobody ends stays until the system's limit.
    func reattach() {
        let record = SessionRecord.load(from: defaults)
        controller.endOthers(than: record?.id)
        guard let record, let plan = record.sessionPlan else {
            if let record { controller.end(sessionID: record.id, state: nil) }
            return
        }
        let now = ContinuousClock.now
        let clock = SessionClock(plan: plan, state: record.clock, at: now, date: .now)
        controller.sessionChanged(clock.snapshot(at: now), plan: plan,
                                  attributes: Self.attributes(for: record.plan, sessionID: record.id))
    }
}
#endif
