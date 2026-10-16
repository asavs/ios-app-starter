# Master plan

Agreed 2026-10-16. This is the ordered list of everything the repository should do next, and why each step is in its position. The roadmap's milestone table follows this order; the [coordination board](mac-windows-coordination.md) tracks the current task; the [setup journal](setup-experience.md) records what actually happened.

## The organizing test

A fresh agent on a fresh machine, Mac or Windows, takes a fresh clone to a template app on a phone, asking the human only for the steps Apple and GitHub force on humans. Every commit should make that run shorter, more reliable, or more useful to the agents who iterate afterwards: reading logs and bug reports, compiling the next build, and getting it onto the phone.

The repository is a template for building many apps. The valuable part is the module library: onboarding, authentication, database design, UX elements, chat and AI features, and the iMessage bridge. Milestones 1–7 are the delivery plumbing that makes any app from the template shippable from anywhere. The owner builds apps from the template, then backpropagates the quintessential pieces into the template as modules. Optional Apple platforms matter because they are testable in GitHub-hosted runners, but they are not needed until the module library exists.

## Order of work

### 1. Put the multiagent board on a diet

The coordination records had become a tax: multi-paragraph acceptance entries duplicated between two documents, a stale "current task" section, and open pull requests nobody tracked. The board exists so two agents on two machines can hand work to each other without re-reading everything.

- The status table at the top of the coordination document is the board. Each task gets one bullet per side: what was done, the run or artifact link, what remains. Not a page.
- Split the setup journal into `docs/journal/` by milestone, one file each, newest entries first. Keep the entry format from `AGENTS.md`; cut text that duplicates the board.
- Windows acts as onboarding tester at step 7 and at milestone boundaries. Between those, the Mac side moves without waiting for cross-machine acceptance of documentation changes.
- Every "done" claim links a run or an artifact. Keep that discipline, drop the paragraphs around it.
- A handoff is complete when the other side can start without asking a question. Measure by whether it did.

### 2. Clear the board this week

- Merge #27 (Windows inventory record) and #30 (status reconciliation). Close #19 and #21 as superseded.
- Merge #28, dispatch the Xcode 16.4 / iOS 18.5 probe once from `main`, record the result under issue #29.
- Decide the minimum OS in one roadmap line. **Done 2026-10-16:** iOS 17.0 kept; the `macos-14` image provides iOS 17.0.1–18.2 runtimes and the compatibility matrix verified 17.0.1, 18.1, 26.0.1 and 27.0 on its first dispatch. Issue #29 closed; milestone 7 complete.
- Triage the open issues into this plan: #1 and #7 to the runbook (step 6), #2, #3, #4 and #17 to the guided setup command (step 6), #25 to the first module round (step 5), #6 closed as observed and explained.
- Repository settings, all free for public repositories: a ruleset on `main` requiring a pull request and passing checks; secret scanning and push protection on; allowed actions restricted to GitHub-owned and verified creators; fork workflow approval for all outside collaborators.

### 3. Reorder the roadmap to match the goal

Done in the same change as this document. Milestones after 7 are renumbered; the mapping is in the roadmap. "Current status" in the roadmap is the single place state lives.

### 4. Make the iteration loop comfortable for agents

The owner already has an app on a phone. What slows the next build is reading what went wrong and getting the fix back to the phone. The consolidated review command, the targeted single-app lane, superseded-run cancellation, and verified tool-download caching already exist; this step finishes the loop.

- **Done 2026-10-16 (PR #38).** Structured failure output: parse `xcodebuild` and test failures into a short, Windows-readable JSON and Markdown block naming file, line, message, and the failing test, with the controlled screenshot attachment the roadmap already calls for. Keep nonzero exit status.
- **Done 2026-10-16 (PR #36).** One command that answers "what happened on my last run": extend `scripts/review_ci.py` to take a run ID or "latest on this branch", not only a PR number.
- Feedback to issue draft: the fixed TestFlight feedback reader produces a sanitized issue body in the documented format for the agent to review before filing.
- Build caching, measured before changed: record cold versus warm times for the current lanes; add Swift package dependency caching when packages arrive in step 5; keep signed outputs and credentials out of caches.
- Delivery convenience: a single command that proposes the next build, dispatches delivery, waits for the environment approval, and reports "Ready to Test" or the exact failing stage.
- Acceptance: an agent can go from a red run to a named failure in one command, and from a fix on `main` to a build on the phone in one approved dispatch, with every step readable without opening the Actions UI.

Seeing a change on a phone should not require TestFlight. Added 2026-10-16:

- **`run-on-device` for Macs. Done 2026-10-16 (PR #37), real device run pending a team.** Xcode 15+ ships `devicectl`; a script builds a debug app, installs it on a USB or Wi-Fi iPhone, launches it and tails the device log. No commit, no upload, about a minute after the build. Scriptable, so agents use it too. When a Mac is present this is the inner loop; the Windows path is never forced on someone who has one.
- **Screenshots in the pull-request summary. Done 2026-10-16 (PR #38): PNG in the artifact and listed in the summary.** The smoke UI test already runs; attach its screenshots to the run summary and artifact so a change is visible about eight minutes after a push with no Apple involvement. Keep attachments controlled (test-generated, sample data only).
- **Ad hoc dev-build channel.** A development-signed build with registered device IDs installs by tapping an `itms-services` link in Safari, skipping App Store Connect processing: on the phone roughly ten minutes after a push. Needs one-time device registration, a reviewed HTTPS hosting decision (GitHub Releases for a public repo; a private location otherwise), profile expiry handling, and the same credential boundaries as delivery. No TestFlight crash symbolication; retained dSYMs cover that. Evaluate before building; record the decision.
- **Automatic distribution on the TestFlight `dev` group.** The group was created with automatic distribution off, so every build needs a manual assignment. Turn it on for the owner-only internal group (or recreate the group, since the setting is fixed at creation) so an approved upload reaches the phone with no extra click. TestFlight remains the distribution tier, about twenty to thirty minutes including Apple processing, for when someone else should try a build.

The development loop this produces, and what is required where:

1. **Push to a branch, open a pull request, enable auto-merge.** Required checks, all under about ten minutes: portable script tests and manifest validation; one simulator smoke lane on the release toolchain (Xcode 27 / iOS 27) for the `starter` configuration; the unsigned signing and TestFlight preflights only when workflows, the manifest or export options change. Draft pull requests skip the simulator; documentation-only changes skip it through a path filter that still reports the required check as passed. Superseded runs are cancelled, so per-push simulator runs are not overkill.
2. **On `main`:** the full three-app matrix and preflights, the exact-merge evidence Windows reviews. The example configurations move here from pull requests; they are overlays of the same code.
3. **Nightly and weekly, never required:** the compatibility matrix across every hosted runtime, the examples, the deliberate-failure report probe, and later a broad UI suite. The pull-request UI suite stays a small smoke set so the gate stays under ten minutes as modules grow.
4. **On the phone when wanted:** a Mac uses `run-on-device`; Windows uses screenshots, then the ad hoc channel, then one approved TestFlight dispatch from `main` when a human or tester should step through it. Simulator and automated UI tests have passed by construction before any device step.
5. **Back from the phone:** TestFlight feedback through the fixed reader becomes a sanitized issue draft.

A scratch branch that is amended and force-pushed, then squash-merged, leaves no trace in history; the push is the unit GitHub understands, and the commit costs nothing.

Nobody waits on CI, not even a small model. Auto-merge lets GitHub merge when required checks pass; `gh pr checks <n> --watch` or a background shell loop blocks for free when a result is needed in-session; the review command reads outcomes afterwards. The `main` ruleset with required checks is what makes auto-merge possible, so it is the first setting to add.

### 5. Module boundaries and app essentials, round one

Templates copy once. An app created with "Use this template" never receives later template changes, so backpropagation needs versioned packages that generated apps depend on.

- Mechanism first: modules live in this repository as Swift packages, tagged, and apps depend on tagged versions. The template app depends on them by path during development. Backpropagation is a pull request here plus a version bump in each app.
- First round, what onboarding itself needs: `AppIcon` pipeline from the existing SVG script and generator; `Onboarding` screens; `Theme` and shared UX elements; `Settings` with Keychain-backed secure storage. Resolve #25 by giving the template a real mark here.
- Each package has its own tests and its own CI lane. A required lane proves the basic app builds with every module disabled.
- Enablement lives in `project.yml`, the existing source of truth. No second configuration format.
- Ship each round to the owner's phone through the existing delivery workflow; the demo app is the first consumer.

### 6. Agent onboarding runbook and guided setup

- One ordered document, `docs/agent-onboarding.md`, routed from a "Start here" section at the top of `AGENTS.md`.
- Human-only prerequisites the agent asks for by name: Apple Developer Program enrollment and payment; agreement acceptance; App Store Connect API key creation and the one-time `.p8` download; App Store Connect app record creation (verify whether the API permits this; it is believed not to); `gh auth login`; environment required-reviewer setup; export compliance answers; accepting the TestFlight install on the phone.
- Agent-runnable steps with the exact existing commands: credential-free doctor, credential bootstrap over stdin, diagnostics, signing and delivery dispatch, CI review, feedback read.
- The permission script: what the agent says before each account-affecting action, what approval looks like, and what it never does (revoke, broaden keys, create duplicate records, change visibility).
- Consent once, not per step: the runbook starts with a checklist of permission categories from [the human-step ledger](human-steps.md) (`github-settings`, `apple-read`, `apple-provisioning`, `apple-testflight`, `apple-browser`, `device-install`). Granted categories are never asked about again; ungranted ones stop with a clear request. The guided setup command reads the same consent.
- Automate the ledger: every row whose path is API/CLI or Config becomes a scripted step; rows marked Browser agent become computer-use tasks run in the user's signed-in browser, asking only for second-factor codes. Rows marked Human are the only prompts left: enrollment and payment, agreements, `gh auth login`, Developer Mode and trusting the computer, and the first TestFlight invitation.
- A failure table mined from the journal: Windows sandbox blocking the key path, App Store Connect login redirect, simulator timeouts, build number gaps, tester group default, queued runs misread as passes.
- `scripts/setup.py`: a resumable state machine over the existing scripts. Each stage stops before anything account-affecting, prints the exact next human action, and records where it stopped. Subsumes #2, #3, #4 and #17. Works identically from PowerShell and Terminal, with portable tests on all three OS runners.
- Resolves #1 by recording the stored key's role (not secret) and #7 by documenting the existing no-echo bootstrap.

### 7. Prove it with a second app

- Create a new repository from the template. Point an agent at it with nothing but the runbook. Time it. Count every human prompt.
- Windows does this run; it found most of the friction the first time.
- Deliverable: a first-run report in the journal listing each prompt and each stall, then one commit per stall removed.
- This is also app number two, which starts the backpropagation loop.

### 8. One backpropagation round-trip before anything depends on it

- Build something small in app two using the modules. Improve a module because of it. Tag. Bump both apps. Record how long the loop took.
- Rule: an app may not carry a copy of module code for more than one release.
- Second module round when a real app asks for it: `Auth` with Sign in with Apple first because it needs no backend, then `Persistence` on SwiftData with a schema design guide.

### 9. AI and chat

- `Chat` UI package with no provider dependency, testable with a mock.
- Provider adapters as separate packages, Claude first, with explicit failure behavior and provider switching.
- Backend-owned keys. Nothing shippable in an app bundle, log, or persisted conversation. The non-AI template still builds with none of this.

### 10. iMessage bridge

- Channel contract package: identity mapping, authentication, message IDs, deduplication, retries, delivery state, outbound-echo handling.
- Simulated bridge tested entirely on GitHub Actions.
- Live bridge last, the one feature needing a persistent Mac; CI validates the artifact and a separately enabled live check passes.
- Cloud computer decision happens here, not earlier: nothing before the live bridge needs a machine beyond hosted runners and the user's devices, and the browser agent runs where the user's signed-in browser is. Criteria and candidates are in [the ledger](human-steps.md).

### 11. Optional Apple platforms

- Watch first (companion and standalone), then native Mac with Catalyst assessed, TV, Vision Pro. Each builds and tests independently on GitHub-hosted runners; that cloud testability is the reason they belong in the template at all.
- Device acceptance distinguished from simulator checks. Signing and distribution documented per platform.

### 12. App Store publication and additional build options

- Metadata, review submission and publication as distinct reviewable actions. Self-hosted builds optional. Ordinary pull-request CI stays on hosted runners; untrusted code never targets a runner holding a Messages session.

## Standing rules

- Nothing enters the template that has not been needed by at least one real app.
- Any step a human had to repeat twice becomes a script or a runbook entry the same week.
- Any step described as "only you can do this" gets a row in [the human-step ledger](human-steps.md) the same day, with its automation path.
- Any failure that cost more than an hour gets a journal entry with the fix, same day.
- Required CI stays under fifteen minutes, or the slow part moves to a manual lane.
- Compatibility claims name the OS versions actually executed. Configuration is not evidence.
