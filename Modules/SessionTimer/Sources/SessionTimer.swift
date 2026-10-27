import Foundation
import Observation

/// Runs a `SessionClock` for SwiftUI: `snapshot` refreshes while the session runs, and stops
/// refreshing when it pauses or finishes. Own one in a view's `@State`.
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
    @ObservationIgnored private var refresher: Task<Void, Never>?

    /// `refreshInterval` sets how often a running snapshot refreshes; it doesn't affect accuracy.
    public init(plan: SessionPlan, refreshInterval: Duration = .milliseconds(100)) {
        let clock = SessionClock(plan: plan)
        self.clock = clock
        self.refreshInterval = refreshInterval
        snapshot = clock.snapshot(at: .now)
    }

    public func start() {
        clock.start(at: .now)
        refresh()
    }

    public func pause() {
        clock.pause(at: .now)
        refresh()
    }

    public func skipToNextPhase() {
        clock.skipToNextPhase(at: .now)
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

    private func refresh() {
        snapshot = clock.snapshot(at: .now)
        if snapshot.status == .running {
            if refresher == nil { startRefreshing() }
        } else {
            refresher?.cancel()
            refresher = nil
        }
    }

    private func startRefreshing() {
        let interval = refreshInterval
        refresher = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval, tolerance: interval / 4)
                guard let self, !Task.isCancelled else { return }
                self.refresh()
            }
        }
    }
}
