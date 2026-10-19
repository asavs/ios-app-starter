# Agent onboarding runbook

Follow this document in order to take a repository created from this template to the app running on the owner's iPhone through TestFlight. It assumes the default user: Windows, GitHub and an iPhone, with all Xcode work on GitHub-hosted macOS runners. A Mac works too; where a Mac changes a step, the step says so.

Every command below exists on `main`. The file that implements it is named next to it. Where a step is still manual or a tool is not built yet, the step says so and names the master plan item or issue that will change it. Do not invent a replacement command.

Related references, read when a step points at them: [Apple setup](apple-setup.md), [TestFlight delivery](testflight-delivery.md), [tester feedback](tester-feedback.md), the [human-step ledger](human-steps.md), and the [setup journal](setup-experience.md).

## 0. Consent before anything else

Before running setup steps, ask which categories the owner grants for this repository and, where relevant, the named Apple team. Read the definitions in the [human-step ledger](human-steps.md#permission-categories-consent-granted-once-at-setup); this checklist summarizes their scope:

| Category | Grant? | Scope |
| --- | --- | --- |
| `github-settings` | Yes / No | Read or change repository settings, rulesets, environments and secret metadata, including the reviewed credential transfer in Stage C. |
| `apple-read` | Yes / No | Read App Store Connect records and reports for the named team; this does not authorize writes. |
| `apple-provisioning` | Yes / No | Let Xcode create or refresh signing certificates and profiles for the named team during signing or delivery. |
| `apple-testflight` | Yes / No | Create or modify beta groups, assign builds, or set build attributes for the named app. |
| `apple-browser` | Yes / No | Let the agent use the owner's already signed-in browser for the named App Store Connect or developer-portal task. The owner enters any second-factor code. |
| `device-install` | Yes / No | Install and launch a development build on the owner's registered device. |

Record each answer for this setup with `python scripts/setup.py` or explicitly in the setup conversation. A `No` or unanswered category is not granted. If a later step needs one, stop before acting and ask: “May I use `<category>` for `<specific task and target>`?” Continue only after the owner grants it. Do not ask again about a category already granted for this setup. Category consent does not replace the concrete change preview and action approval in [section 3](#3-permission-script), a GitHub environment gate, or a human-only decision. The setup command saves the checklist locally in the ignored `build/setup-state.json`; other tools do not read it as authorization.

## 1. Human-only prerequisites

These are the steps Apple and GitHub reserve for a person. Ask for each one by the name in the first column, only when the stage that needs it is next. Do not ask for all of them up front. Verify each one with the command in the last column instead of taking it on trust.

| Ask the owner for | Needed before | Why only a human can do it | How the agent verifies it |
| --- | --- | --- | --- |
| "Sign the GitHub CLI in with `gh auth login`." | Stage A | Device-code login belongs to the account owner. | `gh auth status` |
| "Grant this agent harness permission to run `gh pr merge` and `gh pr close`." | Stage A | Local harness permission, set once. | The first `gh pr merge --auto` succeeds. |
| "Enroll in the Apple Developer Program (individual or organization) and complete payment." | Stage C (Stages A and B need no Apple account) | Identity verification and payment. | Stage D account diagnostics read the team. A failed read is *unknown*, not proof of no membership. Never suggest a second enrollment. |
| "Accept any outstanding agreements in App Store Connect as Account Holder." | Stage D | Legal acceptance. | An agreement error from a later read or upload names it. Diagnostics do not prove that agreements are complete ([apple-setup.md](apple-setup.md#human-prerequisites)). |
| "Request App Store Connect API access, then create a **team** API key with role \<the role you chose in Stage C step 1\> and download the `.p8` once to a folder outside this checkout." | Stage C, after the role decision | A portal form and a single file download. A browser agent can drive the form with `apple-browser` consent; the download stays in the owner's custody. | The key ID and issuer ID shown on the page (both non-secret), then Stage C's metadata check. |
| "Create the App Store Connect app record with these values: team \<team\>, platform iOS, bundle ID \<from `project.yml`\>, name \<record name\>, primary language \<language\>, SKU \<SKU\>. The SKU cannot be changed later." | Stage E, when Stage D reports the app record `missing` | The public API is believed not to create apps (unverified, see issue #4). Browser-agent path with `apple-browser` consent. | Stage D account reads report the app `present`. |
| "Add the `apple-credentials` environment with yourself as required reviewer and only `main` allowed to deploy." | Stage C | Today this is done in the GitHub UI. Planned as a scripted step in `configure-github-repo.py` (master plan step 6). | `bootstrap-apple-credentials.py` refuses to run unless the environment matches the declared policy. |
| "Turn on Developer Mode on the phone and trust this computer." | Mac inner loop only | Physical device prompts. | `run-on-device.sh` lists the device. |
| "Open TestFlight on the iPhone, sign in with the Apple ID that is an App Store Connect user, and install build *X (Y)*." | Stage H | Physical device action. | The owner reports the version and build they see. Ask for the device OS too. |
| "Type the two-factor code from your trusted device." | Any browser-agent step | A second factor. | The browser step proceeds. |

Never ask for, or accept, passwords, two-factor codes typed into chat, private-key contents, signing passwords, payment details or agreement decisions. If the owner pastes one, stop and tell them to rotate it.

## 2. Agent-runnable stages

Each stage ends at a check you can read without opening the Actions UI. For any workflow run, `python scripts/review_ci.py --run <id>` (or `--latest`, `--pr <n>`) reports jobs and the named failure ([scripts/review_ci.py](../scripts/review_ci.py)). It downloads only the iOS test, compatibility and delivery artifacts. For the Apple diagnostics artifacts, use [Reading Apple diagnostics artifacts](#reading-apple-diagnostics-artifacts). Do not poll CI from a model loop. Block in the shell with `gh run watch <id>` or `gh pr checks <n> --watch` (see AGENTS.md, "Do not wait on CI").

`python scripts/setup.py` records the setup's consent choices and completed stage checkpoints in the ignored `build/setup-state.json`. It resumes at the first unfinished stage, stops when consent is declined, and never stores credential values. Run `python scripts/setup.py --status` to inspect progress, `--grant <category>` or `--decline <category>` to update one consent choice, and `--complete <stage>` only after that stage's runbook checks pass. Use `--reset` to remove the checkpoint. The script guides and records progress; follow the stage instructions below to perform and verify the work.

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

   Read `apple-project-diagnostics` and `apple-configuration` as shown in [Reading Apple diagnostics artifacts](#reading-apple-diagnostics-artifacts) ([.github/workflows/apple-diagnostics.yml](../.github/workflows/apple-diagnostics.yml)). Only use an export from the same commit as the `project.yml` you are reasoning about.
3. Read the `placeholder` finding: it remains until step A3 is done.

### Stage C: credentials into GitHub

Needs `github-settings`. The owner must be enrolled (section 1) before an API key can exist.

1. **Stop for the role decision.** Present [Choose access for the operation](apple-setup.md#choose-access-for-the-operation) and get an explicit choice of key type and role before the key is created or transferred. In short: use a **team** key, because individual keys cannot reach the provisioning endpoints that signing needs. **Developer** is the proposed role for read-only diagnostics. **App Manager** (with Certificates, Identifiers & Profiles access) is the candidate for automatic signing, but Apple's documents disagree: the certificate and profile guides name Account Holder or Admin. That discrepancy has not been settled by a live run. Do not default to Admin, and do not broaden an existing key. Reuse an existing key when it already fits. If a later stage is denied access, stop and present a revised plan.
2. Present the concrete plan: team, key type, the chosen role, environment policy ([section 3](#3-permission-script)). Only then ask for the key (section 1).
3. The `apple-credentials` environment must exist with exactly one deployment-branch rule for `main` and a required reviewer. Creating it is a human step today (table above).
4. Add `DEVELOPMENT_TEAM: <10-character team ID>` under `settings.base` in `project.yml`, the way [examples/starter-app-demo.yml](../examples/starter-app-demo.yml) does. Signing reads the team from the exported configuration and fails without it ([scripts/signing_configuration.py](../scripts/signing_configuration.py)).
5. After the owner approves the concrete transfer plan in section 3, transfer the existing key with the narrow bootstrap command ([scripts/bootstrap-apple-credentials.py](../scripts/bootstrap-apple-credentials.py)):

   ```powershell
   python scripts/bootstrap-apple-credentials.py --repo <owner>/<repo> --key-type team --approval-policy solo-owner --key-id <KEY_ID> --issuer-id <ISSUER_ID> --private-key-file <path outside the checkout>\AuthKey_<KEY_ID>.p8
   ```

   Use `--approval-policy independent` when a second person reviews; organization repositories always do. `solo-owner` is limited to a personal repository where the authenticated owner is the sole required reviewer and self-review is enabled. The script verifies that policy and the exact `main` deployment rule; it does not create or change environment protection. It checks for existing credential secret **names** and stops if any are present unless `--replace-existing` is explicitly supplied.

   Keep the `.p8` in its existing secure location outside this checkout. The path is the only key-file reference passed to the command. Do not put key contents in arguments, shell variables, chat or files in the repository, and do not open, print, copy or upload the file. The script validates the PEM markers and size, reads the file locally, then sends it to `gh secret set` through standard input. The key contents are not included in process arguments, stdout, stderr, logs or artifacts. GitHub CLI output is captured; failures are reduced to a generic operation and exit code rather than forwarding upstream text.

   For a team key, the script stores `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_PRIVATE_KEY`; for an individual key it stores `ASC_KEY_ID` and `ASC_PRIVATE_KEY`. It confirms only that the expected secret names exist, never reads secret values back, and writes the non-secret `ASC_KEY_TYPE` environment variable matching `--key-type`. A successful message confirms names only; it does not prove that the key authenticates or has sufficient role access.

   Secret writes happen sequentially. If the command stops partway through, do not rerun with `--replace-existing` blindly: inspect only the environment's secret names, determine which writes completed, then get approval for the specific repair. The script does not roll back a partial write. Never revoke or replace an existing Apple key or signing asset as recovery.
   Do not set `ASC_KEY_TYPE` to a different value manually; authenticated reads use this variable ([apple-setup.md](apple-setup.md#optional-authenticated-reads)).

> **Role record.** The no-echo bootstrap does not verify or record the key's role; it confirms secret names only. Complete issue #1 by confirming the role separately and recording the role alone. Never record the private key.

### Stage D: authenticated read-only diagnostics

Needs `apple-read`. Dispatch from `main`, then approve the environment gate (see "Approving an environment gate" below):

```powershell
gh workflow run apple-diagnostics.yml --ref main --field configuration=starter --field account=true
```

Read `apple-credentials-diagnostics` as shown in [Reading Apple diagnostics artifacts](#reading-apple-diagnostics-artifacts). Statuses are defined in [apple-setup.md](apple-setup.md#interpret-the-report). `inaccessible` and `not_verified` are unknown and must not lead to creating anything.

If the app record is `missing`, create it before Stage E. Collect and confirm every value with the owner first, following [App identity and Apple's defaults](apple-setup.md#app-identity-and-apples-defaults): team, platform, bundle ID, record name, primary language and SKU. Check for an existing matching record and reuse it. The SKU cannot be changed after creation. A rejected name means proposing another name for approval, not changing the bundle ID. Then ask for the app-record step in section 1, and rerun Stage D until it reports `present`. On Windows, the same reads can run locally with `python scripts/install-asc.py` and then `python scripts/apple-doctor.py --account --asc build\tools\asc.exe --configuration <export>\configuration.json` ([scripts/install-asc.py](../scripts/install-asc.py)). Prefer the hosted run so the key never touches the workstation.

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

### Reading Apple diagnostics artifacts

`review_ci.py` does not download these artifacts. From PowerShell, right after dispatching **Apple diagnostics**:

```powershell
$run = gh run list --workflow apple-diagnostics.yml --branch main --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId'
gh run watch $run --exit-status
gh run view $run --json headSha --jq .headSha
git rev-parse origin/main
gh run download $run --name apple-project-diagnostics --dir build/review/$run/project
gh run download $run --name apple-configuration --dir build/review/$run/configuration
Get-Content build/review/$run/project/report.md
```

For a Stage D run (`account=true`, gate approved), also read the account report. This artifact does not exist for a Stage B run, so skip these lines there:

```powershell
gh run download $run --name apple-credentials-diagnostics --dir build/review/$run/account
Get-Content build/review/$run/account/report.md
```

The two SHAs must match before you trust the configuration findings. Otherwise the export describes a different `project.yml`; dispatch again. `build/` is gitignored. Each artifact holds `report.md` and `report.json`, and `apple-configuration` holds `configuration.json` ([.github/workflows/apple-diagnostics.yml](../.github/workflows/apple-diagnostics.yml)).

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
| Consent choices and stage progress survive interruptions | `python scripts/setup.py` stores consent booleans and completed stages in ignored `build/setup-state.json`; individual tools still require their own action approval | Implemented for guided setup checkpoints; broader consent integration is not built |
| Guided resumable setup | `python scripts/setup.py`; stage actions remain in this runbook | Master plan step 6, `scripts/setup.py`; issues #2, #3, #4, #17 |
| `apple-credentials` environment created by script | GitHub UI | Master plan step 6, `configure-github-repo.py` |
| Stored key role record | Stage C notes; role must be confirmed separately from secret-name checks | Issue #1 |
| Feedback to sanitized issue draft | Manual triage with the issue template | Master plan step 4 |
| Ad hoc install without TestFlight | TestFlight only (Windows), `run-on-device` (Mac) | Master plan step 4, evaluation pending |
| App record creation through the API | Human or browser agent | Issue #4 (verify whether the API permits it) |
