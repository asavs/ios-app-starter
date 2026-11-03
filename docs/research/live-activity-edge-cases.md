# Live Activity edge cases: what the tests pin down, what they found, what stays by design

Written 2026-11-02 after the Live Activity (SessionActivity module, `StarterWidgets`) reached the phone and the first look at it was "it doesn't really work". Companion to [live-activities.md](live-activities.md), the research the module was built from. Board task ios-r7k and its follow-up.

## How to run

```sh
# Module level, on the Mac host (no simulator):
swift test --filter 'SessionActivityTests|SessionTimerTests|SessionClockTests'

# App level, on the iPhone 17 / iOS 27.0 simulator (the `test` action; `test-without-building` hung after passing in this repository):
bash scripts/generate-project.sh
xcodebuild -project StarterApp/StarterApp.xcodeproj -scheme StarterApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -derivedDataPath build/dd-edge \
  -only-testing:StarterAppTests \
  -only-testing:StarterAppUITests/TimerUITests/testTimerLiveActivity \
  -only-testing:StarterAppUITests/TimerUITests/testLiveActivitySettingMidSession \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS=$PWD/scripts/simulator-tests.entitlements test
```

## What is tested

**Module (`Modules/SessionActivity/Tests/SessionActivityTests.swift`, 23 tests).** The controller against a recording host: start, update and end in sequence; every phase boundary, pause, resume and skip as one update carrying the right phase, range and remaining time; finish as an end with a final state and the 15-minute dismissal; reset as an immediate end; the setting off mid-session (immediate end) then on again (a new start, count back to one); the system's Live Activities permission denied then granted; a refused start not retried on ticks but retried on the next real change with the current state; rapid pause and resume kept in order even when the first update is slow; a second session ending the previous session's card at once; `endOthers(than:)` on launch keeping only the stored session; the state mapping at exact boundaries (paused at zero, the last instant, the end); encoded size under 4 KB with long titles; and the design's limit, a phase that ends without a change only goes stale (below).

**SessionTimer (`Modules/SessionTimer/Tests`, 28 tests, 2 new).** A finished session is stored as not running; reset, loading a plan and loading a stored paused position stop the refresh loop.

**App (`StarterApp/StarterAppTests/LiveActivityEdgeCaseTests.swift`, 15 tests).** The Timer screen's model, the stored `SessionRecord` and the Live Activity together, with the screen's `onChange(of: snapshot)` played by the test: every change reaches the record and the activity with the right phase; reset ends at once and clears the record; "Start again" is a new session whose start replaces the finished card; the setting off and on (at once, same session, the screen untouched); the setting with no session; a session started with the setting off gets its activity from where it is now when the setting turns on; a fresh model adopts the stored session (identifier, plan, times, position), shows Done for one that ended while the app was away, and starts fresh from an unreadable record; `reattach` updates a stored running session's activity, ends a finished one's with its final state, and ends activities whose session is gone; the activity's button pauses and resumes the record and the screen on show follows at once; the screen follows the record when the app returns; the button ignores another session and a finished one; and the battery rule, 150 ticks inside a phase reach neither ActivityKit nor the defaults store.

**UI (`StarterAppUITests/TimerUITests`).** Unchanged: `testTimerLiveActivity` (start, island screenshot, pause keeps it, reset ends it) and `testLiveActivitySettingMidSession` (the toggle off and on mid-session), both reading the app's activity count. Nothing new at this level: everything above is covered below the UI.

## Bugs found and fixed

1. **The screen started over beside the activity after a relaunch.** `TimerSession` made a new session identifier at init and never read the stored record, so after the system killed the app in the background (or the app was opened from the island) the launch brought the activity up to date while the screen showed a fresh session at 0:00 with Start. A tap on Start made a second session and left the first's activity to the system's limit. Fix: `TimerSession.adoptStoredSession()` (StarterApp/StarterApp/Timer/TimerSession.swift), called from init: the record's plan, times, identifier and clock position become the screen's. Test: `aFreshModelAdoptsTheStoredSession`.

2. **The island's pause button did nothing on the screen while the app was in the foreground.** The island is visible, and its button works, with the app open; the intent changed the record and the activity, but the screen only re-read the record on a scene phase change, which never came. Fix: `StarterSessionActivity.recordChanged`, set by the model's convenience init to `restoreFromRecord()`, called after the intent saves (StarterApp/StarterApp/Timer/StarterSessionActivity.swift). Test: `theButtonPausesAndResumesAndTheScreenOnShowFollows`.

3. **The controller decided with stale answers.** It asked the host "is there an activity?" when a change was queued, while earlier calls were still running. The setting off then on again queued an end and then an *update* (the end hadn't run yet), so the activity never came back; "Start again" after a finish could start before the queued end. Fix: every ActivityKit call now runs through the one queue and decides when it runs (Modules/SessionActivity/Sources/SessionActivityController.swift). Tests: `turningTheSettingOffThenOnStartsAgain`, `aNewSessionEndsTheOldSessionsActivityAtOnce`.

4. **Activities of other sessions were never ended.** Lookups were by session identifier only, so a finished session's card stayed beside a new session's island for its 15 minutes, and an activity whose record was gone (Erase Local Data, a reset in a process that never ran the end, a UI-test launch that wiped the suite) stayed until the system removed it. Fix: `SessionActivityHost.sessionIDs`, `SessionActivityController.endOthers(than:)`, called before a new session's activity starts and by `StarterSessionActivity.reattach()` on launch with the stored session's identifier (nil when there is none). Tests: `endingOthersOnLaunchKeepsOnlyTheStoredSession`, `reattachEndsActivitiesWhoseSessionIsGone`, `startingAgainAfterFinishingIsANewSessionAndReplacesTheOldCard`.

5. **A finished session was stored as running.** A run that reached the end kept its start instant, so `SessionClockState.isRunning` read true for a finished session: the screen reloaded the record on every return to the foreground and the finished record disagreed with the screen. Fix: `SessionClock.state(at:date:)` stores a finished session as its full duration, not running (Modules/SessionTimer/Sources/SessionClock.swift). Test: `aFinishedSessionIsStoredAsNotRunning`.

## Design limitations, recorded not fixed

*Update, later on 2026-11-02 (task ios-d2o):* the state now carries the schedule after the current phase (`upcoming`, at most eight phases) and `shown(at:isStale:)` turns the one stale re-render into the next phase, counting down to its own end, or into the finished session once `sessionEnd` has passed. The island moves one phase on its own; a second boundary without the app still ends in "Phase over", and past the eight carried phases so does the first. The routes that remove the limit altogether are in board task ios-0ik.

**A phase that ends while the app is suspended is not followed by the next one.** The activity holds one phase range the system counts down and a stale date at the phase's end; when the phase ends with nothing running in the app, the view shows 0:00 and "Phase over. Open the app for the next one." until the app next runs (foreground, or an intent from the button). `aPhaseThatEndsWithoutAChangeOnlyGoesStale` pins this. With the template's 20 s work / 10 s rest intervals on the phone this is the first thing a person sees: the island counts the current phase down and then stalls. The session end ("Ends at 3:42 PM") stays right throughout, since it is one date.

What it would take to change, from [live-activities.md](live-activities.md) (lines 11, 35, 90 and the "Scheduled Live Activities" paragraph):

- *Background execution.* Keep the app running to publish each phase: a background audio session (the DTS recommendation for timers whose app is suspended is scheduled local notifications, with a silent audio session as the common workaround; see background-audio.md). Costs battery and an audio-session entitlement story.
- *Push updates.* ActivityKit push tokens and a server sending each phase at its time; the budgeted, documented route, and the only one for an app that is suspended. Needs the Push Notifications capability and a server.
- *The full schedule in the state.* Encoding every remaining phase's date range would let the widget view pick the current phase from the date when the system re-renders it, but Live Activity views render on content updates and stale dates, not on a timeline, so the view would still show the old phase until a render. Not a fix on its own; it would pair with a local notification at each boundary to prompt a glance.

Recommendation: keep the current behaviour for the template (it is honest about the limit and uses no background mode), say so in the Timer's Settings footer, and let an app that needs phase-accurate islands choose push or background audio from the research.

**Other things left as they are.** A finished session's card lasts 15 minutes from when the app learns it finished, not from the finish, so one that ended while the app was dead shows "Done" for 15 minutes after the next launch. The activity's "start" is refused in the background by ActivityKit; the controller leaves the timer as it is and tries again on the next real change (tested).

## Performance and battery

Inspected, with a test where one was cheap:

- **Tick cadence.** `SessionTimer` refreshes its snapshot every 100 ms (tolerance 25 ms) while a session runs and stops the loop on pause, finish, reset and plan load (`refreshesOnlyWhileRunning`, `resetAndLoadingAPlanStopRefreshing`). A refresh reads the clock; it adds nothing up. The loop is a `Task.sleep` on the main actor, so it stops with the process when iOS suspends the backgrounded app; until then (seconds) it runs at the same cadence. Not changed: it is the screen's redraw, needed only in the foreground with the screen on.
- **What reaches the activity.** `TimerSession.sessionChanged` returns before the record save and the controller call unless the status or the phase changed. `ticksWithinAPhaseReachNeitherActivityKitNorTheRecord` plays 150 ticks (15 s of a 20 s phase) and checks zero host events, zero host lookups and zero defaults writes, then one update and one save at the boundary. So ActivityKit hears start, pause, resume, skip, each phase change, finish, reset and the setting; nothing else.
- **ActivityKit lookups.** The controller reads `host.activityCount` (which enumerates `Activity.activities`) once after each queued call, and `hasActivity`/`sessionIDs` once per start or end, never per tick. The UI-test readout shows the controller's cached count, no lookup.
- **Record saves.** One per change, none per tick (same test). The `SessionRecord` is a few hundred bytes of JSON in `UserDefaults`.
- **Widget views.** No `TimelineView`, no timers: `Text(timerInterval:)`, `ProgressView(timerInterval:)` and `Text(_, style: .time)` let the system count; the view is re-rendered only on a content update, the stale date, or an end. The ring while paused is a static `ProgressView(value:)`.
- **Intents.** `ToggleSessionIntent` runs once per tap, loads the record, saves it, publishes one update.

Nothing polls. The one standing cost is the 10 Hz foreground redraw while a session runs, which the Timer screen needs for its ring.
