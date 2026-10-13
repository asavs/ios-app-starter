# Tester feedback loop

Use TestFlight for submission and the pinned CLI for repeatable agent review. Use the App Store Connect browser for visual inspection or API gaps. This starter needs no feedback SDK, backend or custom portal. This guide implements the agreed milestone 7 instructions; a controlled real submission and review are still pending.

## Prepare the test

Use an existing accessible TestFlight build; this exercise needs no new upload or tester invitation. Record the version/build actually installed, rather than assuming the latest CI build is on the phone. Confirm the device model and iOS version.

Draft app-level Beta App Description and build-specific What to Test before entering them in App Store Connect. Preview the selected app/build and text with the owner; saving metadata and notifying/inviting testers are separate actions. Use an owner-chosen monitored feedback email, not a placeholder address. See [Apple's test information guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/).

Sample beta description:

> A minimal native iPhone and iPad app demonstrating development from Windows, GitHub-hosted builds, and TestFlight delivery.

Sample What to Test for the existing demo:

> Open the app and check that “Hello, world!” and “Built on GitHub Actions.” are visible. Tell us if either is missing or difficult to read. Include what you expected, what happened, steps to repeat it, and your TestFlight version/build, device model and iOS version. Use sample data in screenshots.

For future builds, replace these checks with the actual changed behavior and a focused question. A welcome-screen check is not evidence for features the app does not have.

## Send feedback from the iPhone

1. In TestFlight, select the installed app and note its version/build.
2. Open the beta, perform the requested check, and use TestFlight's Send Beta Feedback route. TestFlight also supports feedback from a screenshot taken in the beta app. Follow the controls shown by the installed TestFlight/iOS version.
3. For this acceptance exercise, submit a non-sensitive comment such as `Feedback loop check: both captions are visible.` Add the installed version/build and device OS. A screenshot is optional; crop unrelated personal information before sending.
4. Tell the Windows reviewer when it was submitted and which build was used. Do not deliberately crash the app or invent a defect.

TestFlight sends feedback to Apple and the app developer. Feedback can include comments, screenshots and crash context; see [Apple's TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).

## Windows review and triage

Prefer the fixed read command below using the pinned installer and existing securely supplied credential fields documented in apple-setup.md. Do not log in again, broaden access or paste secrets into commands. Authenticated feedback reads require explicit owner opt-in for the selected app; this guide does not itself perform them.

```powershell
python scripts/install-asc.py
python scripts/read-testflight-feedback.py --app-id <existing-app-id>
python scripts/read-testflight-feedback.py --account --asc build/tools/asc.exe --app-id <existing-app-id> --private-report "$env:TEMP\starter-feedback.json"
```

The first read command is offline; the second retrieves paginated feedback and requests each item's related build. Use a new report filename and an existing controlled local directory. Console output contains only status/count/scope. Comments are saved only to the explicitly requested private report outside the checkout; email, screenshots/URLs and raw upstream output are excluded. Comments can still contain personal data: inspect privately and sanitize before publication. Windows file ACLs remain the user's responsibility. `--build-id` accepts Apple's resource ID, not `1.9.1`; without it the scope is all accessible feedback for the app. No result proves installed-build identity unless its build association is verified. Denied/unknown/skipped reads are not empty-success results. The command performs no metadata edits, deletes, invitations or notifications.


Open the intended app in App Store Connect → TestFlight → Feedback. Inspect the submission for the selected version/build and distinguish screenshot/comment feedback from crash feedback. If it is not visible, record the time checked, filters and access outcome; an empty page does not establish that submission failed. Use [Apple's feedback guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-tester-feedback/).

Classify each report as a reproducible defect, usability suggestion, question, duplicate, or acceptance observation. Ask for missing reproduction information when useful. Create a GitHub issue only for actionable work; a successful feedback-path observation belongs in the setup journal. Review and sanitize before publication, retaining raw screenshots/crash data in controlled account/local storage.

Use this issue body when appropriate:

```text
Summary:
Expected behavior:
Observed behavior:
Steps to reproduce:
App version/build:
Device model / iOS:
Reproduced by reviewer: yes / no / unknown
Impact and priority:
Related issue or suspected duplicate:
Acceptance / targeted retest:
```

Do not include tester names, email addresses, device identifiers, access tokens, raw crash reports or private screenshots in public issues. Include the build's commit/run link only when its association is verified; CI builds and installed TestFlight builds are different evidence.

## Fix and close the loop

Assign the issue to the side best suited to the change: Mac for native implementation/reusable Xcode tooling, Windows for substantial Windows workflow defects. Implement a focused fix, verify with relevant existing checks, and request the specific retest in the next authorized build's What to Test notes. You approve delivery/account effects as required and perform iPhone acceptance. Record the retested version/build and result before closing the issue. A new build or passing CI alone does not prove the tester's defect resolved.

A no-defect acceptance submission can complete collection/review verification without manufacturing a fix. The repair/retest route remains documented until real actionable feedback exercises it. Add CLI automation, independent symbols or performance collection only if the review exposes a concrete need.

## Windows handoff and development experience record

Read this guide from the pushed revision. With the owner, verify one controlled submission is visible for the exact installed build. Commit a sanitized journal entry with outcome, version/build, device OS, retrieval route, limitations and the next action; add a reviewed issue only if actionable.

Alongside this task, track the whole development round:

- Start/end of edit, push, queue, execution, evidence availability, artifact download/review and owner handoffs.
- PR head/merge SHA and run links; report durations separately from total wall-clock wait.
- Commands attempted, authentication/browser friction, redundant reruns and repeated downloads.
- Confirmed cause, suspected cause and remaining unknowns; propose a concrete improvement backed by the observation.

The reporting and targeted-lane features passed functional acceptance. The owner reports approximately an hour per round; acceptable end-to-end development speed has not been established. Track that investigation in parallel without blocking this feedback exercise or claiming individual 7–8 minute runs explain the full wait.
