# Master plan

Agreed 2026-10-16. The ordered list of what the repository does next, and why each step sits where it does. The roadmap's milestone table follows this order; the [coordination board](archive/mac-windows-coordination.md) tracks the current task; the [setup journal](setup-experience.md) records what happened.

## The organizing test

The repository is an iOS starter app. Someone building an app should find onboarding, sign-in, database design and UX elements already scaffolded and prunable, spend their time on what makes the app different, and never handle builds, signing or delivery. The owner builds apps from the template and backpropagates the essential pieces into it as modules: onboarding, authentication, database design, UX elements, and later chat, AI and the iMessage bridge.

Builds on GitHub's runners, development from Windows, AI-automated setup, the iMessage bridge and AI model support serve that scaffold. Milestones 1–7 are the delivery plumbing. Optional Apple platforms belong because GitHub-hosted runners can test them, but they wait until the module library exists.

The test for the plumbing: a fresh agent on a fresh Mac or Windows machine takes a fresh clone to a template app on a phone, asking the human only for the steps Apple and GitHub reserve for humans. Every commit should make that run shorter or more reliable, or make the agents' later loop (reading logs and bug reports, building, getting the build onto the phone) easier.

## Order of work

### 1. Put the multiagent board on a diet

The board lets two agents on two machines hand work to each other without re-reading everything. It had become costly: acceptance entries duplicated across two documents, a stale "current task" section, untracked open pull requests.

- The status table at the top of the coordination document is the board: one line per side per task, with what was done, the run or artifact link, and what remains.
- Split the setup journal into `docs/journal/`, one file per milestone, newest first. Keep the entry format from `AGENTS.md`; cut text that duplicates the board.
- Windows tests onboarding at step 7 and at milestone boundaries. In between, the Mac side does not wait for cross-machine acceptance of documentation changes.
- Every "done" claim links a run or an artifact, without the surrounding paragraphs.
- A handoff is complete when the other side starts without asking a question.

### 2. Clear the board this week

- Merge #27 (Windows inventory record) and #30 (status reconciliation). Close #19 and #21 as superseded.
- Merge #28, dispatch the Xcode 16.4 / iOS 18.5 probe once from `main`, record the result under issue #29.
- Decide the minimum OS in one roadmap line. **Done 2026-10-16:** iOS 17.0 kept; the `macos-14` image provides iOS 17.0.1–18.2 runtimes, and the compatibility matrix verified 17.0.1, 18.1, 26.0.1 and 27.0 on its first dispatch. Issue #29 closed; milestone 7 complete.
- Triage open issues: #1 and #7 to the runbook (step 6); #2, #3, #4 and #17 to the guided setup command (step 6); #25 to the first module round (step 5); #6 closed as observed and explained.
- Repository settings, free for public repositories: a ruleset on `main` requiring a pull request and passing checks; secret scanning and push protection; allowed actions limited to GitHub-owned and verified creators; fork workflow approval for all outside collaborators.

### 3. Reorder the roadmap to match the goal

Done with this document. Milestones after 7 are renumbered; the roadmap has the mapping. The roadmap's "Current status" is the only place state lives.

### 4. Make the iteration loop comfortable for agents

What slows the next build is reading what went wrong and getting the fix to the phone. The consolidated review command, the single-app lane, superseded-run cancellation and verified tool-download caching already exist; this step finishes the loop.

- **Done 2026-10-16 (PR #38).** Structured failure output: `xcodebuild` and test failures parsed into short, Windows-readable JSON and Markdown naming file, line, message and failing test, with the controlled screenshot attachment the roadmap calls for. Nonzero exit status kept.
- **Done 2026-10-16 (PR #36).** `scripts/review_ci.py` takes a run ID or "latest on this branch", not only a PR number.
- Feedback to issue draft: the fixed TestFlight feedback reader produces a sanitized issue body in the documented format for the agent to review before filing.
- **Done 2026-10-19:** cold misses, warm restores and three-app simulator lane timings recorded in the [milestone 8 journal](journal/milestone-8-iteration-loop.md), with [run evidence](https://github.com/asavs/ios-app-starter/actions/runs/39323984923). Keep the verified public-download caches; the measurements do not establish an end-to-end speedup or justify compiler-output caching. Revisit Swift dependency caching when the root package gains an external dependency. Keep signed outputs and credentials out of caches.
- **Done 2026-10-17 (`scripts/deliver_testflight.py`).** One command proposes the next build, dispatches delivery, waits for preflight and completion, and reports Apple's processing state or the failing job and step. This repository's `apple-credentials` environment is restricted to `main` with no required reviewer; `--approve` serves template users who add that gate. The command does not claim "Ready to Test"; `VALID` plus the automatic-distribution group puts the build on the phone.
- **Testing cadence:** [When to test where](testflight-delivery.md#when-to-test-where) defines the PR, `main`, owner-device and external-tester stages, and when a visible change merits a device build.
- **Non-blocking delivery:** `scripts/deliver_testflight.py --no-wait` dispatches a candidate run and returns its ID, URL and resume command; it never approves an optional reviewer gate.
- Acceptance: an agent goes from a red run to a named failure in one command, and from a fix on `main` to a build on the phone in one authorized dispatch, without opening the Actions UI.

Seeing a change on a phone should not require TestFlight. Added 2026-10-16:

- **`run-on-device` for Macs. Done 2026-10-16 (PR #37); real device run pending a team.** Using `devicectl` (Xcode 15+), a script builds a debug app, installs it on a USB or Wi-Fi iPhone, launches it and tails the device log, about a minute after the build with no commit or upload. Agents can run it too. With a Mac this is the inner loop; someone with a Mac is never forced onto the Windows path.
- **Screenshots in the pull-request summary. Done 2026-10-16 (PR #38): PNG in the artifact and listed in the summary.** The smoke UI test's screenshots make a change visible about eight minutes after a push, with no Apple involvement. Attachments stay controlled: test-generated, sample data only.
- **Ad hoc dev-build channel. Decision (2026-10-19): proceed as an optional Windows-to-owner-device fast lane, after the hosting choice is settled.** An Ad Hoc build with an over-the-air manifest skips App Store Connect processing, but needs registered device IDs, an Ad Hoc profile kept current as devices change, HTTPS hosting for the IPA and manifest, and Developer Mode on the device. Apple allows 100 registered devices per product family per membership year; disabling a device does not free a slot. TestFlight stays for builds shared with other testers and for its feedback flow. Choose hosting by the generated app's own visibility and sensitivity: a public template does not authorize publishing a user's app binary publicly. Require explicit approval before any public release upload. The hosting task settles release location and access policy before implementation. The signed-build workflow keeps the delivery workflow's credential scope and approval boundary.
- **Automatic distribution on the TestFlight `dev` group.** The group was created with automatic distribution off, so each build needs manual assignment. Turn it on for the owner-only internal group (or recreate the group, since the setting is fixed at creation) so an approved upload reaches the phone with no extra click. TestFlight, about twenty to thirty minutes including Apple processing, is the tier for when someone else should try a build.

The resulting development loop:

1. **Push to a branch, open a pull request, enable auto-merge.** Required checks, all under about ten minutes: portable script tests and manifest validation; one simulator smoke lane on the release toolchain (Xcode 27 / iOS 27) for the `starter` configuration; the unsigned signing and TestFlight preflights only when workflows, the manifest or export options change. Draft pull requests skip the simulator; documentation-only changes skip it through a path filter that still reports the required check as passed. Superseded runs are cancelled, so a simulator run per push is affordable.
2. **On `main`:** the full three-app matrix and preflights, the exact-merge evidence Windows reviews. The example configurations, overlays of the same code, run here instead of on pull requests.
3. **Nightly and weekly, never required:** the compatibility matrix across every hosted runtime, the examples, the deliberate-failure report probe, and later a broad UI suite. The pull-request UI suite stays a small smoke set so the gate stays under ten minutes as modules grow.
4. **On the phone when wanted:** a Mac uses `run-on-device`; Windows uses screenshots, then the ad hoc channel, then one TestFlight dispatch from `main` when a human or tester should step through it. The `apple-credentials` environment's main-only deployment rule is the gate; template users can add a required reviewer for per-run approval. Simulator and automated UI tests have passed before any device step.
5. **Back from the phone:** TestFlight feedback through the fixed reader becomes a sanitized issue draft.

Commit freely: GitHub acts on pushes, extra commits cost nothing, and a scratch branch that is amended, force-pushed and squash-merged leaves no trace in history.

Nobody waits on CI, including a small model. Auto-merge merges when required checks pass; `gh pr checks <n> --watch` or a background shell loop blocks for free when a result is needed in-session; the review command reads outcomes afterwards. Auto-merge needs the `main` ruleset with required checks, so that setting comes first.

### 5. Module boundaries and app essentials, round one

An app created with "Use this template" never receives later template changes, so backpropagation needs versioned packages that generated apps depend on.

- Mechanism first: modules live in this repository as tagged Swift packages; apps depend on tagged versions, and the template app depends on them by path. Backpropagation is a pull request here plus a version bump in each app.
- First round, what onboarding needs: `AppIcon` pipeline from the existing SVG script and generator; `Onboarding` screens; `Theme` and shared UX elements; `Settings` with Keychain-backed secure storage. Resolve #25 here by giving the template a real mark.
- Each package has its own tests and CI lane. A required lane proves the basic app builds with every module disabled.
- Enablement lives in `project.yml`, the existing source of truth. No second configuration format.
- Ship each round to the owner's phone through the existing delivery workflow; the demo app is the first consumer.

### 6. Agent onboarding runbook and guided setup

- One ordered document, `docs/agent-onboarding.md`, routed from a "Start here" section at the top of `AGENTS.md`.
- Human-only prerequisites the agent asks for by name: Apple Developer Program enrollment and payment; agreement acceptance; App Store Connect API key creation and the one-time `.p8` download; App Store Connect app record creation (verify whether the API permits this; it is believed not to); `gh auth login`; export compliance answers; accepting the TestFlight install on the phone. A template user may optionally configure a required reviewer on `apple-credentials`.
- Agent-runnable steps with the exact existing commands: credential-free doctor, credential bootstrap over stdin, diagnostics, signing and delivery dispatch, CI review, feedback read.
- The permission script: what the agent says before each account-affecting action, what approval looks like, and what it never does (revoke, broaden keys, create duplicate records, change visibility).
- Consent once, not per step: the runbook opens with a checklist of permission categories from [the human-step ledger](human-steps.md) (`github-settings`, `apple-read`, `apple-provisioning`, `apple-testflight`, `apple-browser`, `device-install`). Granted categories are never asked about again; ungranted ones stop with a clear request. The guided setup command reads the same consent.
- Automate the ledger: rows whose path is API/CLI or Config become scripted steps; Browser agent rows become computer-use tasks in the user's signed-in browser, asking only for second-factor codes. Human rows are the only prompts left: enrollment and payment, agreements, `gh auth login`, Developer Mode and trusting the computer, and the first TestFlight invitation.
- A failure table mined from the journal: Windows sandbox blocking the key path, App Store Connect login redirect, simulator timeouts, build number gaps, tester group default, queued runs misread as passes.
- `scripts/setup.py`: a resumable state machine over the existing scripts. Each stage stops before anything account-affecting, prints the exact next human action, and records where it stopped. Subsumes #2, #3, #4 and #17. Behaves the same from PowerShell and Terminal, with portable tests on all three OS runners.
- Resolves #1 by recording the stored key's role (not secret) and #7 by documenting the existing no-echo bootstrap.

### 7. Prove it with a second app

- Create a repository from the template, point an agent at it with only the runbook, time it, and count every human prompt.
- Windows does this run; it found most of the friction the first time.
- Deliverable: a first-run report in the journal listing each prompt and stall, then one commit per stall removed.
- This is app number two, which starts the backpropagation loop.

### 8. One backpropagation round-trip before anything depends on it

- Build something small in app two with the modules. Improve a module because of it. Tag. Bump both apps. Record how long the loop took.
- Rule: an app may not carry a copy of module code for more than one release.
- Second module round when a real app asks for it: `Auth` with Sign in with Apple first, since it needs no backend, then `Persistence` on SwiftData with a schema design guide.

### 9. AI and chat

- `Chat` UI package with no provider dependency, testable with a mock.
- Provider adapters as separate packages, Claude first, with explicit failure behavior and provider switching.
- Backend-owned keys. Nothing shippable in an app bundle, log, or persisted conversation. The non-AI template still builds with none of this.

### 10. iMessage bridge

- Channel contract package: identity mapping, authentication, message IDs, deduplication, retries, delivery state, outbound-echo handling.
- Simulated bridge tested entirely on GitHub Actions.
- Live bridge last, the one feature needing a persistent Mac; CI validates the artifact and a separately enabled live check passes.
- Decide on a cloud computer here, not earlier: nothing before the live bridge needs a machine beyond hosted runners and the user's devices, and the browser agent runs where the user's signed-in browser is. Criteria and candidates are in [the ledger](human-steps.md).

### 11. Optional Apple platforms

- Watch first (companion and standalone), then native Mac with Catalyst assessed, TV, Vision Pro. Each builds and tests independently on GitHub-hosted runners, which is why they belong in the template.
- Device acceptance kept distinct from simulator checks. Signing and distribution documented per platform.

### 12. App Store publication and additional build options

- Metadata, review submission and publication as distinct reviewable actions. Self-hosted builds optional. Ordinary pull-request CI stays on hosted runners; untrusted code never targets a runner holding a Messages session.

## Standing rules

- Nothing enters the template until at least one real app has needed it.
- A step a human had to repeat twice becomes a script or runbook entry the same week.
- A step described as "only you can do this" gets a row in [the human-step ledger](human-steps.md) the same day, with its automation path.
- A failure that cost more than an hour gets a journal entry with the fix, same day.
- Required CI stays under fifteen minutes, or the slow part moves to a manual lane.
- Compatibility claims name the OS versions actually executed. Configuration is not evidence.
