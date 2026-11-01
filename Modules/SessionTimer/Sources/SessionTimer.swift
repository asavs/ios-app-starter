import Foundation
import Observation

/// Runs a `SessionClock` for SwiftUI: `snapshot` refreshes while the session runs, and stops
/// refreshing when it pauses or finishes. Own one in a view's `@State` or in a view model.
///
/// Refreshing only reads the clock, so a late or skipped refresh (the app in the background, for
/// example) never loses time: the next snapshot is correct. It does not run code in the
/// background; schedule anything that must happen while the app is suspended separately.
@MainActor @Observable
public final class SessionTimer {
    public private(set) var snapshot: SessionSnapshot
    public var plan: SessionPlan { clock.plan }

    private var clock: SessionClock
    private let refreshInterval: Duration
    private let now: () -> SessionClock.Instant
    @ObservationIgnored private var refresher: Task<Void, Never>?

    /// - Parameters:
    ///   - refreshInterval: How often a running snapshot refreshes; it doesn't affect accuracy.
    ///   - now: The current instant; tests pass a controlled one.
    public init(plan: SessionPlan, refreshInterval: Duration = .milliseconds(100),
                now: @escaping () -> SessionClock.Instant = { .now }) {
        let clock = SessionClock(plan: plan)
        self.clock = clock
        self.refreshInterval = refreshInterval
        self.now = now
        snapshot = clock.snapshot(at: now())
    }

    public func start() {
        clock.start(at: now())
        refresh()
    }

    public func pause() {
        clock.pause(at: now())
        refresh()
    }

    public func skipToNextPhase() {
        clock.skipToNextPhase(at: now())
        refresh()
    }

    public func reset() {
        clock.reset()
        refresh()
    }

    /// Replace the plan and reset to its start.
    public func load(_ plan: SessionPlan) {
        clock = SessionClock(plan: plan)
        refresh()
    }

    /// Replace the plan and restore a stored position in it, such as one an App Intent changed
    /// while the app was in the background. `date` is the wall-clock time matching `now()`.
    public func load(_ plan: SessionPlan, state: SessionClockState, date: Date = .now) {
        clock = SessionClock(plan: plan, state: state, at: now(), date: date)
        refresh()
    }

    /// The position to store, as dates. `date` is the wall-clock time matching `now()`.
    public func state(date: Date = .now) -> SessionClockState {
        clock.state(at: now(), date: date)
    }

    /// Read the clock now. The refresh loop calls this while running; tests call it directly.
    func refresh() {
        snapshot = clock.snapshot(at: now())
        if snapshot.status == .running {
            if refresher == nil { startRefreshing() }
        } else {
            refresher?.cancel()
            refresher = nil
        }
    }

    var isRefreshing: Bool { refresher != nil }

    private func startRefreshing() {
        let interval = refreshInterval
        // Weak, because the timer owns this task: a strong capture would be a cycle.
        refresher = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval, tolerance: interval / 4)
                guard let self, !Task.isCancelled else { return }
                self.refresh()
            }
        }
    }
}
