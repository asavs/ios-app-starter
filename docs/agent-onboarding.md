# Agent onboarding runbook

Follow this document in order to take a repository created from this template to the app running on the owner's iPhone through TestFlight. It assumes the default user: Windows, GitHub and an iPhone, with all Xcode work on GitHub-hosted macOS runners. A Mac works too; where a Mac changes a step, the step says so.

Every command below exists on `main`. The file that implements it is named next to it. Where a step is still manual or a tool is not built yet, the step says so and names the master plan item or issue that will change it. Do not invent a replacement command.

Related references, read when a step points at them: [Apple setup](apple-setup.md), [TestFlight delivery](testflight-delivery.md), [tester feedback](tester-feedback.md), the [human-step ledger](human-steps.md), and the [setup journal](setup-experience.md).

## 0. Consent before anything else

> **Placeholder.** A consent-once checklist is planned (master plan step 6, "Consent once, not per step"). It will list the permission categories from the [human-step ledger](human-steps.md#permission-categories-consent-granted-once-at-setup) so the owner grants them once at the start, and the guided setup command will read the same record.

Until it exists, open the session by presenting the six categories in that table (`github-settings`, `apple-read`, `apple-provisioning`, `apple-testflight`, `apple-browser`, `device-install`). Ask which ones the owner grants for this repository and this Apple team. Record the answer in the conversation and do not ask about a granted category again. When a step needs an ungranted category, stop and use the request wording in [section 3](#3-permission-script).

## 1. Human-only prerequisites

These are the steps Apple and GitHub reserve for a person. Ask for each one by the name in the first column, only when the stage that needs it is next. Do not ask for all of them up front. Verify each one with the command in the last column instead of taking it on trust.

| Ask the owner for | Needed before | Why only a human can do it | How the agent verifies it |
| --- | --- | --- | --- |
| "Sign the GitHub CLI in with `gh auth login`." | Stage A | Device-code login belongs to the account owner. | `gh auth status` |
| "Grant this agent harness permission to run `gh pr merge` and `gh pr close`." | Stage A | Local harness permission, set once. | The first `gh pr merge --auto` succeeds. |
| "Enroll in the Apple Developer Program (individual or organization) and complete payment." | Stage B | Identity verification and payment. | Stage D account diagnostics read the team. A failed read is *unknown*, not proof of no membership. Never suggest a second enrollment. |
| "Accept any outstanding agreements in App Store Connect as Account Holder." | Stage D | Legal acceptance. | An agreement error from a later read or upload names it. Diagnostics do not prove that agreements are complete ([apple-setup.md](apple-setup.md#human-prerequisites)). |
| "Request App Store Connect API access, then create a **team** API key with the role we agreed and download the `.p8` once to a folder outside this checkout." | Stage C | A portal form and a single file download. A browser agent can drive the form with `apple-browser` consent; the download stays in the owner's custody. | The key ID and issuer ID shown on the page (both non-secret), then Stage C's metadata check. |
| "Create the App Store Connect app record: name, bundle ID, SKU and primary language as listed here." | Stage E | The public API is believed not to create apps (unverified, see issue #4). Browser-agent path with `apple-browser` consent. | `apple-doctor` account reads report the app `present` (Stage D). |
| "Add the `apple-credentials` environment with yourself as required reviewer and only `main` allowed to deploy." | Stage C | Today this is done in the GitHub UI. Planned as a scripted step in `configure-github-repo.py` (master plan step 6). | `bootstrap-apple-credentials.py` refuses to run unless the environment matches the declared policy. |
| "Turn on Developer Mode on the phone and trust this computer." | Mac inner loop only | Physical device prompts. | `run-on-device.sh` lists the device. |
| "Open TestFlight on the iPhone, sign in with the Apple ID that is an App Store Connect user, and install build *X (Y)*." | Stage H | Physical device action. | The owner reports the version and build they see. Ask for the device OS too. |
| "Type the two-factor code from your trusted device." | Any browser-agent step | A second factor. | The browser step proceeds. |

Never ask for, or accept, passwords, two-factor codes typed into chat, private-key contents, signing passwords, payment details or agreement decisions. If the owner pastes one, stop and tell them to rotate it.

## 2. Agent-runnable stages

Each stage ends at a check you can read without opening the Actions UI. For any workflow run, `python scripts/review_ci.py --run <id>` (or `--latest`, `--pr <n>`) reports jobs, the named failure and the artifacts ([scripts/review_ci.py](../scripts/review_ci.py)). Do not poll CI from a model loop. Block in the shell with `gh run watch <id>` or `gh pr checks <n> --watch` (see AGENTS.md, "Do not wait on CI").

> **Placeholder.** `scripts/setup.py` will wrap Stages A–G as a resumable state machine that stops before each account-affecting step and prints the next human action (master plan step 6; subsumes issues #2, #3, #4 and #17). Until then, run the stages by hand.

### Stage A: repository, no Apple account

1. `gh auth status`. If it fails, ask for `gh auth login`.
2. Preview the recommended repository settings, then apply them with `github-settings` consent ([scripts/configure-github-repo.py](../scripts/configure-github-repo.py)):

   ```powershell
   python scripts/configure-github-repo.py --repo <owner>/<repo>
   python scripts/configure-github-repo.py --repo <owner>/<repo> --apply
   ```

   This enables auto-merge, secret scanning and push protection, restricts actions, and adds the `main` ruleset requiring `ios-gate` and `portable (...)`. After this, direct pushes to `main` are blocked for everyone.
3. Set the app identity in `project.yml`: `INFOPLIST_KEY_CFBundleDisplayName`, and `PRODUCT_BUNDLE_IDENTIFIER` for the app and both test targets (README, "Customize the app"). Choose a reverse-DNS identifier the owner controls. `com.example.*` is fine for unsigned checks but cannot be signed. Leave `starter-app-demo` alone; it is the template's own registered app.
4. Commit on a branch, open a pull request and enable auto-merge: `gh pr merge <n> --auto --merge`. The pull-request lane builds and tests `starter` on the simulator with no secrets ([.github/workflows/ios.yml](../.github/workflows/ios.yml)).
5. When a result is needed: `python scripts/review_ci.py --pr <n>`. A red run names the file, line, message and failing test. The `ios-test-results-starter` artifact includes a screenshot of the welcome screen.

### Stage B: credential-free Apple readiness

1. `python scripts/apple-doctor.py` writes `build/apple-diagnostics/report.md` and `report.json` ([scripts/apple-doctor.py](../scripts/apple-doctor.py)). A zero exit status means the report was written, not that the app is ready to sign.
2. Get findings for the current commit's project from the hosted Mac:

   ```powershell
   gh workflow run apple-diagnostics.yml --ref main --field configuration=starter --field account=false
   ```

   Download `apple-project-diagnostics` and `apple-configuration` ([.github/workflows/apple-diagnostics.yml](../.github/workflows/apple-diagnostics.yml)). Only use an export from the same commit as the `project.yml` you are reasoning about.
3. Read the `placeholder` finding: it remains until step A3 is done.

### Stage C: credentials into GitHub

Present the concrete plan first (team, key type `team`, role, environment policy; see [section 3](#3-permission-script)). Needs `github-settings`.

1. The `apple-credentials` environment must exist with exactly one deployment-branch rule for `main` and a required reviewer. Creating it is a human step today (table above).
2. Add `DEVELOPMENT_TEAM: <10-character team ID>` under `settings.base` in `project.yml`, the way [examples/starter-app-demo.yml](../examples/starter-app-demo.yml) does. Signing reads the team from the exported configuration and fails without it ([scripts/signing_configuration.py](../scripts/signing_configuration.py)).
3. Transfer the key over stdin. The script checks the environment policy and existing secret names, never reads values back, and refuses to replace unless `--replace-existing` is given ([scripts/bootstrap-apple-credentials.py](../scripts/bootstrap-apple-credentials.py)):

   ```powershell
   python scripts/bootstrap-apple-credentials.py --repo <owner>/<repo> --key-type team --approval-policy solo-owner --key-id <KEY_ID> --issuer-id <ISSUER_ID> --private-key-file <path outside the checkout>\AuthKey_<KEY_ID>.p8
   ```

   Use `--approval-policy independent` when a second person reviews; organization repositories always do. The path is the only reference to the key. Do not open, print or copy the file.
4. Set the environment variable `ASC_KEY_TYPE=team` (non-secret) under the same environment ([apple-setup.md](apple-setup.md#optional-authenticated-reads)).

> **Placeholder.** A full write-up of the no-echo bootstrap (issue #7) and the record of which role the stored key holds (issue #1, role only, never the secret) are planned under master plan step 6.

### Stage D: authenticated read-only diagnostics

Needs `apple-read`. Dispatch from `main`, then approve the environment gate (see "Approving an environment gate" below):

```powershell
gh workflow run apple-diagnostics.yml --ref main --field configuration=starter --field account=true
```

Statuses are defined in [apple-setup.md](apple-setup.md#interpret-the-report). `inaccessible` and `not_verified` are unknown and must not lead to creating anything. `missing` on the app record means you need the human app-record step from section 1. On Windows, the same reads can run locally with `python scripts/install-asc.py` and then `python scripts/apple-doctor.py --account --asc build\tools\asc.exe --configuration <export>\configuration.json` ([scripts/install-asc.py](../scripts/install-asc.py)). Prefer the hosted run so the key never touches the workstation.

### Stage E: signed archive validation

Needs `apple-provisioning`. Xcode automatic signing may create or refresh the distribution certificate and profile for the named team. Say so before dispatching.

```powershell
gh workflow run signing-validation.yml --ref main --field configuration=starter --field perform_signing=true
```

Approve the gate, then `python scripts/review_ci.py --latest --branch main --workflow "Signed archive validation"`. The report checks identity, signature, entitlements, profile and certificate match, and expiry ([.github/workflows/signing-validation.yml](../.github/workflows/signing-validation.yml)). Nothing is uploaded.

### Stage F: TestFlight group with automatic distribution

Needs `apple-testflight` for apply, `apple-read` for plan. Plan first, then apply ([.github/workflows/testflight-groups.yml](../.github/workflows/testflight-groups.yml), [scripts/testflight-groups.py](../scripts/testflight-groups.py)):

```powershell
gh workflow run testflight-groups.yml --ref main --field configuration=starter --field group_name=dev-auto --field tester_role=ACCOUNT_HOLDER --field apply=false
gh workflow run testflight-groups.yml --ref main --field configuration=starter --field group_name=dev-auto --field tester_role=ACCOUNT_HOLDER --field apply=true
```

Apply creates the group with `--internal --access-all-builds` and adds each user holding the role. Nothing is deleted. A same-named group without all-builds access stops the run for manual review, because the setting cannot be changed after creation.

### Stage G: deliver to TestFlight

Needs `apple-provisioning` and `apple-testflight`, plus the owner's explicit approval of this upload. One command dispatches, waits, approves the gate when `--approve` is given, and reports each stage ([scripts/deliver_testflight.py](../scripts/deliver_testflight.py)):

```powershell
python scripts/deliver_testflight.py --configuration starter --dry-run
python scripts/deliver_testflight.py --configuration starter --approve
```

Exit codes: 0 processed or accepted; 1 failed at a named step; 2 setup problem; 3 still running after `--wait-minutes` (resume with `--run <id>`). `upload_accepted` means the uploader returned success, not that the build is installable. Once processing reports `VALID` and the build is in the Stage F group, it reaches the phone. The build number comes from the run number and attempt, so gaps are expected ([testflight-delivery.md](testflight-delivery.md#reviewed-configuration-and-numbering)). The manifest declares `ITSAppUsesNonExemptEncryption = NO`, so there is no per-build compliance question until the app adds networking or cryptography.

### Stage H: on the phone

Ask the owner to install that exact version and build from TestFlight and describe what they see. Record the version, build, run link, device OS and the observed result in the journal. A phone result covers that phone's OS only.

### The loop after first install

- **What happened on my last run:** `python scripts/review_ci.py --latest` ([scripts/review_ci.py](../scripts/review_ci.py)).
- **Mac with a phone attached:** `IOS_CONFIGURATION=starter IOS_DEVELOPMENT_TEAM=<team> bash scripts/run-on-device.sh`. Preview it first with `IOS_RUN_ON_DEVICE_DRY_RUN=1`. Needs `device-install` and `apple-provisioning` ([scripts/run-on-device.sh](../scripts/run-on-device.sh)).
- **Next build to the phone from any OS:** Stage G again from `main`.
- **Tester feedback:** with `apple-read` consent, `python scripts/install-asc.py`, then `python scripts/read-testflight-feedback.py --account --asc build/tools/asc.exe --app-id <app-id> --private-report <path outside checkout>` ([scripts/read-testflight-feedback.py](../scripts/read-testflight-feedback.py)). Comments go only to the private report. Triage them with [tester-feedback.md](tester-feedback.md), and sanitize before filing an issue with that guide's issue template. Automatic generation of a sanitized issue draft is planned (master plan step 4). An ad hoc install channel that skips TestFlight is under evaluation in the same step.

### Approving an environment gate

Every job in `apple-credentials` waits for a reviewer. Approve only a run whose workflow and effect the owner authorized. To approve from the shell, read the environment ID from `gh api repos/<owner>/<repo>/actions/runs/<id>/pending_deployments`, then:

```powershell
gh api -X POST repos/<owner>/<repo>/actions/runs/<id>/pending_deployments -F "environment_ids[]=<environment id>" -f state=approved -f comment="<what was authorized>"
```

`deliver_testflight.py` prints this exact command for its own run when `--approve` is omitted. With the solo-owner policy, this is the owner approving their own run, not an independent review.

## 3. Permission script

Say the "before" line, wait for an answer that names the action, and only then act. A general "go ahead" from earlier in the session does not cover a new category. "Approved" for diagnostics does not cover signing, and signing does not cover upload ([apple-setup.md](apple-setup.md#collect-the-approval-gates-together)). Collect related approvals into one request where you can.

| Action | Category | Say before acting | Approval looks like |
| --- | --- | --- | --- |
| Apply repository settings | `github-settings` | "This changes these settings on `<owner>/<repo>`: \<dry-run diff\>. Direct pushes to `main` will be blocked for you too. Apply?" | "Apply the repo settings." |
| Transfer the API key | `github-settings` | "I'll send the `.p8` at \<path\> to `apple-credentials` secrets on `<owner>/<repo>` over stdin, as a **team** key with role \<role\>, approval policy \<policy\>. I won't open or print the file." | "Transfer the key." |
| Authenticated diagnostics | `apple-read` | "I'll run read-only App Store Connect checks for \<bundle ID\> on team \<team\> and approve that one environment gate." | "Run the account diagnostics." |
| Signed archive | `apple-provisioning` | "Xcode may create a distribution certificate and create or refresh the App Store profile for \<bundle ID\> on team \<team\>. Nothing is uploaded." | "Sign it." |
| Create the TestFlight group | `apple-testflight` | "The plan run says: \<plan summary\>. Apply will create internal group \<name\> with access to all builds and add \<n\> users holding \<role\>. Nothing is deleted." | "Create the group." |
| Upload a build | `apple-testflight` | "I'll upload \<configuration\> at `main` \<sha\>, build \<proposed number\>, to internal TestFlight, approving the gate as you." | "Upload it." / "Deliver." |
| Device install (Mac) | `device-install` | "I'll build Debug for \<device\> and let Xcode register it and refresh the development profile on team \<team\>." | "Run it on the phone." |
| Browser step | `apple-browser` | "I'll open \<page\> in your signed-in browser to \<create the app record / create the key\> with these values: \<…\>. You will need to type any two-factor code yourself." | "Go ahead in the browser." |

The agent never does any of the following, even with consent:

- Revoke or replace a key, certificate or profile. Lost or compromised keys are the owner's deliberate action.
- Create a broader key or raise a key's role to make a check pass.
- Create a second app record, bundle ID, group or enrollment because a read came back `missing`, `inaccessible` or empty. Check team and permissions first.
- Change repository visibility.
- Accept agreements, answer export compliance for an app with real cryptography, or submit for review or publication.
- Echo, log, upload or paste secret values, or dump the process environment while diagnosing.
- Invite testers outside the agreed role.

## 4. Failure table

Mined from [the journal](setup-experience.md). Check here before diagnosing from scratch.

| Symptom | Cause | What to do | Source |
| --- | --- | --- | --- |
| Local authenticated read returns `not_verified`; sanitized output shows Windows `Access is denied`. | Confirmed: the `.p8` path is outside the agent's command sandbox. | Grant the fixed reader narrow access to that one existing key path. Never copy the key into the checkout or a command line. Prefer the hosted run. | [milestone 7](journal/milestone-7-diagnostics.md), 2026-10-13 feedback reader |
| `git fetch`, `gh run view` or `gh run download` fail with a write or network permission error. | Confirmed: the local sandbox, not CI or the repository. | Repeat the same read-only command with Git or network access allowed. | [milestone 5](journal/milestone-5-signing.md), [milestone 6](journal/milestone-6-testflight.md), 2026-10-09/10 |
| `gh auth status` says the token is invalid, so the bootstrap stops before transfer. | Confirmed: local GitHub CLI login, not an Apple key problem. | Ask the owner for `gh auth login`, re-check `gh auth status`, rerun the bootstrap. | [milestone 5](journal/milestone-5-signing.md), 2026-10-09 credential-transfer friction |
| A new App Store Connect tab redirects to login with `authResult=FAILED`. | Observed; cause not established. The already signed-in tab stayed valid. | Use the existing signed-in tab, or have the owner sign in and type the two-factor code. Do not automate the login dialog. | [milestone 7](journal/milestone-7-diagnostics.md), 2026-10-13; [milestone 6](journal/milestone-6-testflight.md), 2026-10-10 |
| Build shows **Missing Compliance**. | Confirmed: no export-compliance answer for the build. | Fixed in the template by `ITSAppUsesNonExemptEncryption = NO` (PR #41). If an app removes it, the owner answers in App Store Connect. | [milestone 6](journal/milestone-6-testflight.md), 2026-10-11; [milestone 8](journal/milestone-8-iteration-loop.md), 2026-10-16 |
| Build is Ready to Test but shows **Groups (0)** and is missing from the phone's TestFlight app. | Confirmed: not assigned to any group or tester. | Stage F: plan, then apply, the `testflight-groups.yml` workflow. | [milestone 6](journal/milestone-6-testflight.md), 2026-10-11 |
| Later builds need manual assignment to the group. | Confirmed: the group was created with automatic distribution off, and that cannot be changed afterwards. | Create a new group with `--access-all-builds` (Stage F) and retire the old group by hand. | [milestone 6](journal/milestone-6-testflight.md), 2026-10-11; [milestone 8](journal/milestone-8-iteration-loop.md), 2026-10-16 |
| Build numbers skip (run 10 produced `1.9.1`). | Confirmed: base + run number + attempt; CI and preflight runs consume run numbers. | Expected. Gaps are not missing uploads. | [milestone 6](journal/milestone-6-testflight.md), 2026-10-11 |
| The simulator step times out though the assertion passed. | Confirmed for the observed runs: budgets too tight for cold hosted builds. | Already raised (20-minute step, 300 s per test, simulator boot wait). Do not downgrade failures to warnings; review with `review_ci.py`. | [milestone 6](journal/milestone-6-testflight.md), 2026-10-11 |
| Jobs sit queued, cancelled runs show in progress, or skipped jobs look green. | Queue cause unknown (issue #6). Skipped and cancelled are not passes. | Read job states and test counts in the artifact, not the check color. `ios-gate` fails on missing or cancelled lanes. | [milestone 8](journal/milestone-8-iteration-loop.md), 2026-10-16 pull-request gate |
| `review_ci.py --latest` reports a run that has not finished, or prints `MISMATCH`. | Confirmed: `--latest` picks by creation time; the checkout differs from the reviewed head. | Review a specific run with `--run <id>`; use `--require-checkout-head` after checking out the head. | [milestone 8](journal/milestone-8-iteration-loop.md), 2026-10-16 `review_ci.py` modes |
| `upload_accepted`, but the build is not installable, or the upload timed out. | Confirmed: upload, processing and installation are separate states. | Check App Store Connect before retrying. For `PROCESSING`, resume with `deliver_testflight.py --run <id>`. | [milestone 6](journal/milestone-6-testflight.md), 2026-10-10; [milestone 8](journal/milestone-8-iteration-loop.md), 2026-10-17 |
| An account job waits indefinitely after dispatch. | Confirmed: the `apple-credentials` reviewer gate is pending. | Approve only an authorized run ("Approving an environment gate" above). | [milestone 5](journal/milestone-5-signing.md), 2026-10-09 |
| The app record name is rejected as taken. | Confirmed: record names are global across developers. | Propose another record name for approval. The Home Screen name and the bundle ID are unaffected. The SKU cannot be changed later. | [milestones 1–4](journal/milestone-1-4-foundation.md), Starter App demo identity |
| A dispatch fails with zero jobs and `Unrecognized named-value: 'runner'`. | Confirmed: `runner.*` used in a job-level `env`. | Move it to step-level `env`. | [milestone 7](journal/milestone-7-diagnostics.md), 2026-10-16 probe rejected |
| PowerShell prints replacement characters in diagnostic output. | Confirmed: Windows default stream encoding. | `$env:PYTHONUTF8='1'` and `[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()`. | [milestone 5](journal/milestone-5-signing.md), 2026-10-09 PR #8 |
| Diagnostics pass but membership and agreements stay "unverified". | Confirmed: the API diagnostics cannot check them. | Ask the Account Holder to confirm both in App Store Connect before the first upload. | [milestone 5](journal/milestone-5-signing.md), 2026-10-10 |

## 5. Not built yet

| Gap | Today | Tracked by |
| --- | --- | --- |
| Consent recorded once and read by tools | Ask in conversation (section 0) | Master plan step 6 |
| Guided resumable setup | Run stages A–G by hand | Master plan step 6, `scripts/setup.py`; issues #2, #3, #4, #17 |
| `apple-credentials` environment created by script | GitHub UI | Master plan step 6, `configure-github-repo.py` |
| No-echo bootstrap write-up; stored key role record | Stage C notes | Issues #7 and #1 |
| Feedback to sanitized issue draft | Manual triage with the issue template | Master plan step 4 |
| Ad hoc install without TestFlight | TestFlight only (Windows), `run-on-device` (Mac) | Master plan step 4, evaluation pending |
| App record creation through the API | Human or browser agent | Issue #4 (verify whether the API permits it) |
