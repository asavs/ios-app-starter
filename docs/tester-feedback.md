# Collect and act on tester feedback

Testers report through TestFlight. You read their comments with the pinned CLI, or in App Store Connect when you need to see a submission the API does not cover. Actionable reports become issues, followed by a focused retest. No feedback SDK, backend or portal is needed. The [diagnostics journal](journal/milestone-7-diagnostics.md) records a real submission and review.

## Prepare the test

Use a TestFlight build you can already access; no new upload or invitation is needed. Record the version and build actually installed on the phone, not the latest CI build, plus the device model and iOS version.

Draft the app-level Beta App Description and the build's What to Test, and review the app, build and text with the owner before entering them in App Store Connect. Saving metadata, notifying testers and inviting testers are separate actions. Use a monitored feedback email the owner chose, not a placeholder. See [Apple's test information guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/).

Sample beta description:

> A starter app for iPhone and iPad with a welcome tour, appearance settings and reusable interface elements.

Sample What to Test for a build with the demo's greeting and build caption:

> Open the app and check that “Hello, world!” and “Replace this screen in ContentView.swift.” are visible. Tell us if either is missing or difficult to read. Include what you expected, what happened, steps to repeat it, and your TestFlight version/build, device model and iOS version. Use sample data in screenshots.

For later builds, ask about the behavior that actually changed. A welcome-screen check says nothing about other features.

## Send feedback from the iPhone

1. In TestFlight, select the installed app and note its version and build.
2. Open the beta, do the requested check, and use Send Beta Feedback, or take a screenshot in the beta app. The exact controls depend on your TestFlight and iOS versions.
3. For this acceptance exercise, submit a non-sensitive comment such as `Feedback loop check: both captions are visible.` with the version, build and device OS. A screenshot is optional; crop out unrelated personal information.
4. Tell the reviewer when you submitted and from which build. Do not deliberately crash the app or invent a defect.

Feedback goes to Apple and the developer and can include comments, screenshots and crash context; see [Apple's TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).

## Windows review and triage

Use the fixed commands below. They rely on the pinned installer and the credentials already supplied securely as described in apple-setup.md. Do not log in again, broaden access or paste secrets into commands. Authenticated reads need the owner's explicit opt-in for the selected app.

```powershell
python scripts/install-asc.py
python scripts/read-testflight-feedback.py --app-id <existing-app-id>
python scripts/read-testflight-feedback.py --account --asc build/tools/asc.exe --app-id <existing-app-id> --private-report "$env:TEMP\starter-feedback.json" --issue-draft "$env:TEMP\starter-feedback-issues.txt"
```

The first read runs offline. The authenticated read fetches feedback page by page with each item's build. Write to new filenames in an existing local directory you control. The console shows only status, count and scope; comments go only to the private report outside the checkout, without email addresses, screenshots, URLs or raw upstream output.

`--issue-draft` writes one body per item from the template below. It redacts common emails, links, credential patterns, UUIDs and phone-like numbers, omits tester identities, and marks version and build as unverified. Before filing, confirm the build association and review the body privately for other sensitive details. Nothing is sent to GitHub. Windows file ACLs are your responsibility.

`--build-id` takes Apple's resource ID, not `1.9.1`; without it, the command reads all accessible feedback for the app. A result proves which build was installed only when its build association is verified. A denied, unknown or skipped read is not an empty result. The command never edits metadata, deletes, invites or notifies.

In the browser, open the app in App Store Connect → TestFlight → Feedback, find the submission for the selected version and build, and tell screenshot or comment feedback apart from crash feedback. If it is not there, record when you checked, the filters and whether you had access; an empty page does not mean the submission failed. See [Apple's feedback guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-tester-feedback/).

Classify each report as a reproducible defect, usability suggestion, question, duplicate or acceptance observation, and ask for missing reproduction steps where they would help. File a GitHub issue only for actionable work; a note that the feedback path worked goes in the setup journal. Sanitize before publishing, and keep raw screenshots and crash data in the account or local storage you control.

Issue body:

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

Do not put tester names, email addresses, device identifiers, access tokens, raw crash reports or private screenshots in public issues. Link the build's commit or run only when the association is verified; a CI build and an installed TestFlight build are different evidence.

## Fix and close the loop

Assign the issue to someone with the right tools: a Mac for native implementation or Xcode tooling, Windows for Windows workflow defects. Make a focused fix, run the relevant checks, and ask for a specific retest in the next authorized build's What to Test. The owner approves delivery and account effects and checks the result on the iPhone. Record the retested version, build and result before closing. A new build or green CI alone does not prove the defect is fixed.

An acceptance submission with no defect completes the collection and review check without a made-up fix. Add CLI automation, independent symbols or performance collection only if a review shows a concrete need.

## Record the review and time spent

Use the guide from the revision under test. With the owner, confirm a controlled submission is visible for the exact installed build. Commit a sanitized journal entry with the outcome, version and build, device OS, how the feedback was retrieved, limitations and next action.

Also track the whole development round:

- Start and end times of editing, push, queue, execution, evidence availability, artifact download and review, and owner handoffs.
- PR head and merge SHAs and run links, with each duration reported separately from the total wall-clock wait.
- Commands tried, authentication or browser friction, redundant reruns and repeated downloads.
- Confirmed cause, suspected cause and unknowns, and a concrete improvement backed by what you observed.

The owner reported about an hour per round, so measure the full elapsed time, not just the 7 to 8 minute runs. Do not hold up feedback review for it.
