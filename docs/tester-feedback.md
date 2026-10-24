# Collect and act on tester feedback

Ask testers to report what happened in your app through TestFlight. Read their comments with the pinned CLI, or in App Store Connect when you need to see a submission or the API does not cover something. Turn actionable reports into issues, then ask for a focused retest. The starter needs no feedback SDK, backend or custom portal. The [diagnostics journal](journal/milestone-7-diagnostics.md) records a real submission and review.

## Prepare the test

Use a TestFlight build you can already access. This exercise needs no new upload or tester invitation. Record the version and build actually installed on the phone; do not assume it is the latest CI build. Confirm the device model and iOS version.

Draft the app-level Beta App Description and the build-specific What to Test before entering them in App Store Connect. Go over the selected app, build and text with the owner first. Saving metadata, notifying testers and inviting testers are separate actions. Use a monitored feedback email the owner chose, not a placeholder address. See [Apple's test information guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/).

Sample beta description:

> A starter app for iPhone and iPad with a welcome tour, appearance settings and reusable interface elements.

Sample What to Test for a build with the demo's greeting and build caption:

> Open the app and check that “Hello, world!” and “Built on GitHub Actions.” are visible. Tell us if either is missing or difficult to read. Include what you expected, what happened, steps to repeat it, and your TestFlight version/build, device model and iOS version. Use sample data in screenshots.

For later builds, replace these checks with the behavior that actually changed and a focused question. A welcome-screen check is no evidence for features the app does not have.

## Send feedback from the iPhone

1. In TestFlight, select the installed app and note its version and build.
2. Open the beta, do the requested check, and use TestFlight's Send Beta Feedback route. TestFlight also accepts feedback from a screenshot taken in the beta app. Follow the controls your installed TestFlight and iOS versions show.
3. For this acceptance exercise, submit a non-sensitive comment such as `Feedback loop check: both captions are visible.` Add the installed version, build and device OS. A screenshot is optional; crop unrelated personal information before sending.
4. Tell the reviewer when it was submitted and which build was used. Do not deliberately crash the app or invent a defect.

TestFlight sends feedback to Apple and the app developer. It can include comments, screenshots and crash context; see [Apple's TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).

## Windows review and triage

Use the fixed read command below. It relies on the pinned installer and the credential fields already supplied securely, as documented in apple-setup.md. Do not log in again, broaden access or paste secrets into commands. Authenticated feedback reads need the owner's explicit opt-in for the selected app; this guide does not perform them itself.

```powershell
python scripts/install-asc.py
python scripts/read-testflight-feedback.py --app-id <existing-app-id>
python scripts/read-testflight-feedback.py --account --asc build/tools/asc.exe --app-id <existing-app-id> --private-report "$env:TEMP\starter-feedback.json" --issue-draft "$env:TEMP\starter-feedback-issues.txt"
```

The first read command runs offline. The authenticated command fetches feedback page by page and requests each item's related build. Write to new output filenames in an existing local directory you control. The console shows only status, count and scope. Comments go only to the requested private report outside the checkout. Email addresses, screenshots, URLs and raw upstream output are left out.

`--issue-draft` writes one body per feedback item from the template below. It redacts common emails, links, credential patterns, UUIDs and phone-like numbers, omits tester identities, and marks the version and build as unverified. Before filing, confirm the build association and review the body privately for other identifying or sensitive details. The draft is not sent to GitHub. Windows file ACLs are the user's responsibility.

`--build-id` accepts Apple's resource ID, not `1.9.1`. Without it, the command reads all accessible feedback for the app. A result proves which build was installed only when its build association is verified. A denied, unknown or skipped read is not a successful empty result. The command performs no metadata edits, deletes, invitations or notifications.

To review in the browser, open the intended app in App Store Connect → TestFlight → Feedback. Find the submission for the selected version and build, and tell screenshot or comment feedback apart from crash feedback. If it is not visible, record when you checked, the filters and whether you had access. An empty page does not show that the submission failed. Use [Apple's feedback guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-tester-feedback/).

Classify each report as a reproducible defect, usability suggestion, question, duplicate, or acceptance observation. Ask for missing reproduction steps when they would help. Create a GitHub issue only for actionable work; a note that the feedback path worked belongs in the setup journal. Review and sanitize before publishing, and keep raw screenshots and crash data in controlled account or local storage.

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

Do not include tester names, email addresses, device identifiers, access tokens, raw crash reports or private screenshots in public issues. Include the build's commit or run link only when its association is verified. CI builds and installed TestFlight builds are different evidence.

## Fix and close the loop

Assign the issue to someone with the tools to investigate it: a Mac for native implementation or reusable Xcode tooling, Windows for substantial Windows workflow defects. Make a focused fix and run the relevant existing checks. Ask for a specific retest in the What to Test notes of the next authorized build. The owner approves delivery and account effects as required and checks the result on the iPhone. Record the retested version, build and result before closing the issue. A new build or passing CI alone does not prove the tester's defect is fixed.

An acceptance submission with no defect can complete the collection and review check without a made-up fix. The repair and retest route stays documented until real actionable feedback exercises it. Add CLI automation, independent symbols or performance collection only if the review shows a concrete need.

## Record the review and time spent

Use the guide from the revision being tested. With the owner, check that a controlled submission is visible for the exact installed build. Commit a sanitized journal entry with the outcome, version and build, device OS, how the feedback was retrieved, limitations and next action. Add a reviewed issue only if there is actionable work.

Alongside this task, track the whole development round:

- Start and end times of editing, push, queue, execution, evidence availability, artifact download and review, and owner handoffs.
- PR head and merge SHAs and run links. Report each duration separately from the total wall-clock wait.
- Commands tried, authentication or browser friction, redundant reruns and repeated downloads.
- Confirmed cause, suspected cause and remaining unknowns. Propose a concrete improvement backed by what you observed.

Earlier checks verified reporting and the single-app test workflow, but not that overall speed is acceptable: the owner reported about an hour per development round. Track the full elapsed time. Do not hold up feedback review for it, and do not treat individual 7 to 8 minute runs as the whole wait.
