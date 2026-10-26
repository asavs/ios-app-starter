# Agent onboarding runbook

Use this runbook to take an app created from the starter to the owner's iPhone through TestFlight. Follow the stages in order. Keep the app features the owner needs and remove the rest.

Everything works from Windows with GitHub and an iPhone: GitHub-hosted macOS runners do the Xcode builds, signing and uploads. Steps that differ on a Mac say so. The app can be built and tested before any Apple account exists.

Every command below exists on `main` and links to its implementation; manual steps and missing tools name their tracking issue or plan. Do not invent a replacement command.

References, when a step points there: [Apple setup](apple-setup.md), [TestFlight delivery](testflight-delivery.md), [tester feedback](tester-feedback.md), the [human-step ledger](human-steps.md), and the [setup journal](setup-experience.md).

## 0. Consent before anything else

Before any setup step, ask the owner which categories they grant for this repository and, where relevant, the named Apple team. Full definitions are in the [human-step ledger](human-steps.md#permission-categories-consent-granted-once-at-setup):

| Category | Grant? | Scope |
| --- | --- | --- |
| `github-settings` | Yes / No | Read or change repository settings, rulesets, environments and secret metadata, including the reviewed credential transfer in Stage C. |
| `github-browser` | Yes / No | Let the agent use the owner's already signed-in GitHub tab for a setting with no API: uploading the social preview image. |
| `apple-read` | Yes / No | Read App Store Connect records and reports for the named team; this does not authorize writes. |
| `apple-provisioning` | Yes / No | Let Xcode create or refresh signing certificates and profiles for the named team during signing or delivery. |
| `apple-testflight` | Yes / No | Create or modify beta groups, assign builds, or set build attributes for the named app. |
| `apple-browser` | Yes / No | Let the agent use the owner's already signed-in browser for the named App Store Connect or developer-portal task. The owner enters any second-factor code. |
| `device-install` | Yes / No | Install and launch a development build on the owner's registered device. |

Record each answer with `python scripts/setup.py` or state it in the conversation. A category answered `No`, or not answered, is not granted: if a later step needs it, stop before acting, ask "May I use `<category>` for `<specific task and target>`?", and continue only after the owner grants it. Do not ask again about a category already granted. Category consent replaces neither the approval of a concrete action in [section 3](#3-permission-script) nor a human-only decision. `setup.py` saves the checklist in the ignored `build/setup-state.json`; other tools do not treat that file as authorization.

## 1. Human-only prerequisites

Apple and GitHub reserve these steps for a person. Ask for each, in the first column's wording, only when the stage that needs it is next, not all up front. Verify each with the last column's method; do not take it on trust.

| Ask the owner for | Needed before | Why only a human can do it | How the agent verifies it |
| --- | --- | --- | --- |
| "Sign the GitHub CLI in with `gh auth login`." | Stage A | Device-code login belongs to the account owner. | `gh auth status` |
| "Grant this agent harness permission to run `gh pr merge` and `gh pr close`." | Stage A | Local harness permission, set once. | The first `gh pr merge --auto` succeeds. |
| "Enroll in the Apple Developer Program (individual or organization) and complete payment." | Stage C (Stages A and B need no Apple account) | Identity verification and payment. | Stage D account diagnostics read the team. A failed read is *unknown*, not proof of no membership. Never suggest a second enrollment. |
| "Accept any outstanding agreements in App Store Connect as Account Holder." | Stage D | Legal acceptance. | An agreement error from a later read or upload names it. Diagnostics do not prove that agreements are complete ([apple-setup.md](apple-setup.md#human-prerequisites)). |
| "Request App Store Connect API access, then create a **team** API key with role \<the role you chose in Stage C step 1\> and download the `.p8` once to a folder outside this checkout." | Stage C, after the role decision | A portal form and a one-time download. A browser agent can drive the form with `apple-browser` consent; the download stays with the owner. | The key ID and issuer ID shown on the page (both non-secret), then Stage C's metadata check. |
| "Create the App Store Connect app record with these values: team \<team\>, platform iOS, bundle ID \<from `project.yml`\>, name \<record name\>, primary language \<language\>, SKU \<SKU\>. The SKU cannot be changed later." | Stage E, when Stage D reports the app record `missing` | The public API is believed not to create apps (unverified, see issue #4). Browser-agent path with `apple-browser` consent. | Stage D account reads report the app `present`. |
| "Allow only `main` to deploy to the `apple-credentials` environment." | Stage C | Stage A's `configure-github-repo.py --apply` configures it. A required reviewer is optional, added in Settings → Environments → `apple-credentials`. | `bootstrap-apple-credentials.py` checks for the exact `main` rule and the selected optional reviewer policy. |
| "Turn on Developer Mode on the phone and trust this computer." | Mac inner loop only | Physical device prompts. | `run-on-device.sh` lists the device. |
| "Open TestFlight on the iPhone, sign in with the Apple ID that is an App Store Connect user, and install build *X (Y)*." | Stage H | Physical device action. | The owner reports the version and build they see. Ask for the device OS too. |
| "Type the two-factor code from your trusted device." | Any browser-agent step | A second factor. | The browser step proceeds. |

Never ask for, or accept, passwords, two-factor codes typed into chat, private-key contents, signing passwords, payment details or agreement decisions. If the owner pastes one, stop and tell them to rotate it.

## 2. Agent-runnable stages

Each stage ends with a check you can read without opening the Actions UI. `python scripts/review_ci.py --run <id>` (or `--latest`, `--pr <n>`) reports a run's jobs and the sanitized evidence it recognizes, downloading the iOS test, compatibility, signing-preflight and TestFlight artifacts ([scripts/review_ci.py](../scripts/review_ci.py)). Download the signed-archive report separately in Stage E, and Apple diagnostics as in [Reading Apple diagnostics artifacts](#reading-apple-diagnostics-artifacts). [The CI guide](ci.md#review-ci-evidence-from-any-machine) explains build and test evidence. Do not poll CI from a model loop; block in the shell with `gh run watch <id>` or `gh pr checks <n> --watch` (see AGENTS.md, "Do not wait on CI").

`python scripts/setup.py` resumes at the first unfinished stage, stops when consent is declined, and never stores credential values. `python scripts/setup.py --status` shows progress, `--grant <category>` or `--decline <category>` changes one consent choice, `--complete <stage>` records a stage only after its checks below pass, and `--reset` removes the checkpoint. The script only guides and records; do and verify each stage's work as written below.

### Stage A: repository, no Apple account

1. `gh auth status`. If it fails, ask for `gh auth login`.
2. Preview the recommended repository settings, then apply them with `github-settings` consent ([scripts/configure-github-repo.py](../scripts/configure-github-repo.py)):

   ```powershell
   python scripts/configure-github-repo.py --repo <owner>/<repo>
   python scripts/configure-github-repo.py --repo <owner>/<repo> --apply
   ```

   This turns on auto-merge, secret scanning and push protection, restricts actions, lets workflows open pull requests (used by the optional README icon sync; the default token stays read-only), and adds a `main` ruleset requiring `ios-gate` and `portable (...)`. After that, nobody can push directly to `main`.
3. Set the app identity in `project.yml`: `INFOPLIST_KEY_CFBundleDisplayName`, `DEV_DISPLAY_NAME` (the shorter name Debug builds show, such as "Notes Dev"), and `PRODUCT_BUNDLE_IDENTIFIER` for the app and both test targets (see the [README](../README.md)). Pick a reverse-DNS identifier the owner controls; `com.example.*` passes unsigned checks but cannot be signed. Leave `starter-app-demo` alone; it is the template's own registered app. Then give the app its own placeholder icon with `python scripts/personalize-icon.py` ([app icon](app-icon.md)) and commit `StarterApp/StarterApp/AppIcon.icon/icon.json` with the identity change.
4. Choose modules under `targets.StarterApp.dependencies` in `project.yml`. `TemplateVersion`, `Theme`, `Onboarding` and `Settings` start enabled; Onboarding and Settings need Theme. Keep only the products the app needs ([Modules](modules.md)). The first unsigned check can use the copied local library. Within the app's first release, switch to a tagged URL dependency following [Use the library from an app](modules.md#use-the-library-from-an-app), after checking that the chosen release contains every enabled product (the initial `0.1.0` tag contains only TemplateVersion).
5. Commit on a branch, open a pull request and enable auto-merge: `gh pr merge <n> --auto --merge`. The pull-request lane builds and tests `starter` on the simulator with no secrets ([.github/workflows/ios.yml](../.github/workflows/ios.yml)). Windows users edit the manifest; Actions regenerates the Xcode project before building.
6. When you need the result, run `python scripts/review_ci.py --pr <n>` and check the counts for the enabled features; the lane runs the app's UI suite, including the onboarding, theme and settings checks. The command summarizes counts only. To read individual failures, download the `ios-test-results-starter` artifact: it has test screenshots and a `failures.json` naming each failure and, when available, its source location.
7. Optional, after the first green run on `main`: make the social preview card with `python3 scripts/social-preview.py` on a Mac, or `gh workflow run social-preview.yml --ref main` and download the `social-preview` artifact ([CI guide](ci.md#make-a-social-preview-card)). GitHub has no API for the social preview setting, so with `github-browser` consent upload the light or dark JPEG in the owner's signed-in browser under Settings → General → Social preview; otherwise give the owner the file and those steps.

### Stage B: credential-free Apple readiness

1. `python scripts/apple-doctor.py` writes `build/apple-diagnostics/report.md` and `report.json` ([scripts/apple-doctor.py](../scripts/apple-doctor.py)). Exit status zero means the report was written, not that the app can be signed.
2. Get findings for the current commit's project from the hosted Mac:

   ```powershell
   gh workflow run apple-diagnostics.yml --ref main --field configuration=starter --field account=false
   ```

   Read `apple-project-diagnostics` and `apple-configuration` as in [Reading Apple diagnostics artifacts](#reading-apple-diagnostics-artifacts) ([.github/workflows/apple-diagnostics.yml](../.github/workflows/apple-diagnostics.yml)). Use only an export from the same commit as the `project.yml` you are working from.
3. The `placeholder` finding stays until step A3 is done.

### Stage C: credentials into GitHub

Needs `github-settings`. An API key can exist only after the owner enrolls (section 1).

1. **Stop for the role decision.** Present [Choose access for the operation](apple-setup.md#choose-access-for-the-operation) and get an explicit choice of key type and role before any key is created or transferred.
   - App-only diagnostics: start with an individual **Developer** key, the least privilege.
   - The full diagnostic also reads provisioning resources, which need a **team** key. Apple does not document the minimum role for each inventory read, so verify with existing authorized access and treat denials as unknown.
   - Hosted automatic signing passes a team key to Xcode with `-allowProvisioningUpdates`. Use **Admin** only when Xcode may create or refresh distribution assets; Apple's certificate and App Store profile guides require Account Holder or Admin for those writes, so Admin is the least-privileged documented role for this path.
   - If no provisioning writes are needed, prefer prepared signing assets and a path that reuses them.
   - Reuse an existing key that already fits. Never create or broaden one automatically.
2. Present the concrete plan: team, key type, chosen role and environment policy ([section 3](#3-permission-script)). Only then ask for the key (section 1).
3. The `apple-credentials` environment must have exactly one deployment-branch rule, for `main`. Stage A's `configure-github-repo.py --apply` creates it with no required reviewer; add reviewers with `--require-reviewer` or the GitHub environment settings.
4. Add `DEVELOPMENT_TEAM: <10-character team ID>` under `settings.base` in `project.yml`, the way [examples/starter-app-demo.yml](../examples/starter-app-demo.yml) does. Signing reads the team from the exported configuration and fails if it is missing ([scripts/signing_configuration.py](../scripts/signing_configuration.py)).
5. After the owner approves the concrete transfer plan in section 3, transfer the existing key with the narrow bootstrap command ([scripts/bootstrap-apple-credentials.py](../scripts/bootstrap-apple-credentials.py)):

   ```powershell
   python scripts/bootstrap-apple-credentials.py --repo <owner>/<repo> --key-type team --key-id <KEY_ID> --issuer-id <ISSUER_ID> --private-key-file <path outside the checkout>\AuthKey_<KEY_ID>.p8
   ```

   The default `--approval-policy none` checks that the environment has no required reviewers. Choose `independent` or `solo-owner` only if reviewers were configured, and `solo-owner` only for a personal repository whose authenticated owner is the sole required reviewer with self-review allowed. The script checks the selected policy and the exact `main` rule; it does not change environment protection. It stops if any credential secret **names** already exist, unless you explicitly pass `--replace-existing`.

   Leave the `.p8` in its secure location outside this checkout; the command takes only its path. Do not put key contents in arguments, shell variables, chat or repository files, and do not open, print, copy or upload the file. The script checks the PEM markers and size, reads the file locally and sends it to `gh secret set` on standard input, so the key never appears in process arguments, stdout, stderr, logs or artifacts. It reports a GitHub CLI failure only as an operation name and exit code, without forwarding upstream text.

   A team key stores `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_PRIVATE_KEY`; an individual key stores `ASC_KEY_ID` and `ASC_PRIVATE_KEY`. The script also writes the non-secret `ASC_KEY_TYPE` environment variable to match `--key-type`; do not change it by hand, because authenticated reads depend on it ([apple-setup.md](apple-setup.md#optional-authenticated-reads)). Success confirms only that the secret names exist. The script never reads values back, so it does not prove the key authenticates or that its role has enough access.

   Secrets are written one at a time, with no rollback. If the script stops partway, do not blindly rerun with `--replace-existing`: look only at the environment's secret names to see which writes finished, then get approval for that specific repair. Never revoke or replace an existing Apple key or signing asset to recover.

> **Role record.** The bootstrap cannot read the key or check its role, so template adopters must confirm their key's role in App Store Connect before transfer. Record only the role, never the key ID, issuer ID or private key. In this acceptance repository the stored team key's role is **Admin**, confirmed separately and used for the protected signing run ([milestone 5 journal](journal/milestone-5-signing.md)).

### Stage D: authenticated read-only diagnostics

Needs `apple-read`. Dispatch from `main`; the default setup needs no environment approval:

```powershell
gh workflow run apple-diagnostics.yml --ref main --field configuration=starter --field account=true
```

Read `apple-credentials-diagnostics` as in [Reading Apple diagnostics artifacts](#reading-apple-diagnostics-artifacts). Statuses are defined in [apple-setup.md](apple-setup.md#interpret-the-report). `inaccessible` and `not_verified` mean unknown; never create anything because of them.

If the app record is `missing`, create it before Stage E. Reuse a matching record if one exists. Otherwise collect and confirm every value with the owner, following [App identity and Apple's defaults](apple-setup.md#app-identity-and-apples-defaults): team, platform, bundle ID, record name, primary language and SKU. The SKU cannot be changed after creation. If Apple rejects the name, propose another for approval; do not change the bundle ID. Then ask for the app-record step in section 1 and rerun Stage D until it reports `present`.

On Windows the same reads can run locally with `python scripts/install-asc.py` and then `python scripts/apple-doctor.py --account --asc build\tools\asc.exe --configuration <export>\configuration.json` ([scripts/install-asc.py](../scripts/install-asc.py)), but prefer the hosted run so the key never touches the workstation.

### Stage E: signed archive validation

Needs `apple-provisioning`. Xcode automatic signing may create or refresh the distribution certificate and profile for the named team; say so before dispatching.

```powershell
gh workflow run signing-validation.yml --ref main --field configuration=starter --field perform_signing=true
```

If this repository has a required reviewer (the default has none), follow [Optional required-reviewer gate](#optional-required-reviewer-gate). Pick the authorized dispatch, check that its head SHA is the intended commit, then wait and read the results:

```powershell
$run = gh run list --workflow signing-validation.yml --branch main --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId'
gh run view $run --json headSha --jq .headSha
gh run watch $run --exit-status
python scripts/review_ci.py --run $run
gh run download $run --name signing-validation-starter --dir build/review/$run/signing
Get-Content build/review/$run/signing/signing-validation.json
```

If a newer dispatch exists, pass the intended run ID explicitly; for another configuration, change the artifact's `starter` suffix. `review_ci.py` reports job conclusions and the unsigned preflight but does not download `signing-validation-<configuration>`. Its JSON must report `status: passed` and `validatedArtifact: app-store-connect-export-from-archive`, with the intended bundle and team and unexpired profile and certificate dates. The validator checks identity, signature, entitlements, profile and certificate match, and expiry ([.github/workflows/signing-validation.yml](../.github/workflows/signing-validation.yml)). Without the report, signing is unverified. This stage uploads nothing to App Store Connect.

### Stage F: TestFlight group with automatic distribution

Plan needs `apple-read`; apply needs `apple-testflight`. Plan first, then apply ([.github/workflows/testflight-groups.yml](../.github/workflows/testflight-groups.yml), [scripts/testflight-groups.py](../scripts/testflight-groups.py)):

```powershell
gh workflow run testflight-groups.yml --ref main --field configuration=starter --field group_name=dev-auto --field tester_role=ACCOUNT_HOLDER --field apply=false
gh workflow run testflight-groups.yml --ref main --field configuration=starter --field group_name=dev-auto --field tester_role=ACCOUNT_HOLDER --field apply=true
```

Apply creates the group with `--internal --access-all-builds` and adds every user who holds the role. Nothing is deleted. If a group with the same name exists without all-builds access, the run stops for manual review, because that setting cannot be changed after creation.

### Stage G: deliver to TestFlight

Needs `apple-provisioning` and `apple-testflight`, plus the owner's explicit approval of this upload. One command dispatches the run, waits for preflight and completion, and reports each stage ([scripts/deliver_testflight.py](../scripts/deliver_testflight.py)):

```powershell
python scripts/deliver_testflight.py --configuration starter --dry-run
python scripts/deliver_testflight.py --configuration starter
```

Exit codes: 0 processed or accepted; 1 failed at a named step; 2 setup problem; 3 still running after `--wait-minutes` (resume with `--run <id>`). `upload_accepted` means the uploader returned success, not that the build is installable; it reaches the phone once processing reports `VALID` and it is in the Stage F group. Build numbers come from the run number and attempt, so expect gaps ([testflight-delivery.md](testflight-delivery.md#reviewed-configuration-and-numbering)). The manifest declares `ITSAppUsesNonExemptEncryption = NO`, so no per-build compliance question comes up until the app adds networking or cryptography.

### Stage H: on the phone

Ask the owner to install that exact version and build from TestFlight and describe what they see. Record the version, build, run link, device OS and result in the journal. A phone result covers that phone's OS only.

### The loop after first install

- **What happened on my last run:** `python scripts/review_ci.py --latest` ([scripts/review_ci.py](../scripts/review_ci.py)).
- **Mac with a phone attached:** `IOS_CONFIGURATION=starter IOS_DEVELOPMENT_TEAM=<team> bash scripts/run-on-device.sh`. Preview with `IOS_RUN_ON_DEVICE_DRY_RUN=1`. Works with Xcode 26 or 27 (only 27 shows the icon's refraction; see [app icon pitfalls](app-icon.md#pitfalls-we-hit)) and needs `device-install` and `apple-provisioning` ([scripts/run-on-device.sh](../scripts/run-on-device.sh)).
- **Next build to the phone from any OS:** Stage G again from `main`.
- **Tester feedback:** with `apple-read` consent, `python scripts/install-asc.py`, then `python scripts/read-testflight-feedback.py --account --asc build/tools/asc.exe --app-id <app-id> --private-report <path outside checkout>` ([scripts/read-testflight-feedback.py](../scripts/read-testflight-feedback.py)). Comments go only to the private report. Use [tester-feedback.md](tester-feedback.md) to review them and generate a sanitized issue draft, and review the draft privately before filing it.

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

For a Stage D run (`account=true`), also read the account report. A Stage B run has no such artifact, so skip these lines there:

```powershell
gh run download $run --name apple-credentials-diagnostics --dir build/review/$run/account
Get-Content build/review/$run/account/report.md
```

Trust the configuration findings only if the two SHAs match; otherwise the export describes a different `project.yml`, so dispatch again. `build/` is gitignored. Each artifact holds `report.md` and `report.json`, and `apple-configuration` holds `configuration.json` ([.github/workflows/apple-diagnostics.yml](../.github/workflows/apple-diagnostics.yml)).

### Optional required-reviewer gate

By default `apple-credentials` has no required reviewer, so its workflows run without an approval step. If required reviewers were added, approve a pending deployment only after the owner has authorized that workflow and its effect. Read the environment ID from `gh api repos/<owner>/<repo>/actions/runs/<id>/pending_deployments`, then:

```powershell
gh api -X POST repos/<owner>/<repo>/actions/runs/<id>/pending_deployments -F "environment_ids[]=<environment id>" -f state=approved -f comment="<what was authorized>"
```

`deliver_testflight.py --approve` posts the approval when an eligible reviewer is configured and a deployment is pending. With no pending deployment, it continues normally.

## 3. Permission script

Say the "before" line, wait for an answer that names the action, and only then act. An earlier general "go ahead" does not cover a new category: approval for diagnostics does not cover signing, and signing does not cover upload ([apple-setup.md](apple-setup.md#collect-the-approval-gates-together)). Where you can, combine related approvals into one request.

| Action | Category | Say before acting | Approval looks like |
| --- | --- | --- | --- |
| Apply repository settings | `github-settings` | "This changes these settings on `<owner>/<repo>`: \<dry-run diff\>. Direct pushes to `main` will be blocked for you too. Apply?" | "Apply the repo settings." |
| Transfer the API key | `github-settings` | "I'll send the `.p8` at \<path\> to `apple-credentials` secrets on `<owner>/<repo>` over stdin, as a \<team or individual\> key with role \<role\>, approval policy \<policy\>. I won't open or print the file." | "Transfer the key." |
| Authenticated diagnostics | `apple-read` | "I'll run read-only App Store Connect checks for \<bundle ID\> on team \<team\> from `main`." | "Run the account diagnostics." |
| Signed archive | `apple-provisioning` | "Xcode may create a distribution certificate and create or refresh the App Store profile for \<bundle ID\> on team \<team\>. Nothing is uploaded." | "Sign it." |
| Create the TestFlight group | `apple-testflight` | "The plan run says: \<plan summary\>. Apply will create internal group \<name\> with access to all builds and add \<n\> users holding \<role\>. Nothing is deleted." | "Create the group." |
| Upload a build | `apple-testflight` | "I'll upload \<configuration\> at `main` \<sha\>, build \<proposed number\>, to internal TestFlight." | "Upload it." / "Deliver." |
| Device install (Mac) | `device-install` | "I'll build Debug for \<device\> and let Xcode register it and refresh the development profile on team \<team\>." | "Run it on the phone." |
| Upload the social preview | `github-browser` | "I'll open Settings → General → Social preview on `<owner>/<repo>` in your signed-in browser and upload `build/social-preview/social-preview-<light or dark>.jpg`." | "Upload it." |
| Browser step | `apple-browser` | "I'll open \<page\> in your signed-in browser to \<create the app record / create the key\> with these values: \<…\>. You will need to type any two-factor code yourself." | "Go ahead in the browser." |

Even with consent, never:

- Revoke or replace a key, certificate or profile. Lost or compromised keys are the owner's deliberate action.
- Create a broader key or raise a key's role to make a check pass.
- Create a second app record, bundle ID, group or enrollment because a read came back `missing`, `inaccessible` or empty. Check team and permissions first.
- Change repository visibility.
- Accept agreements, answer export compliance for an app with real cryptography, or submit for review or publication.
- Echo, log, upload or paste secret values, or dump the process environment while diagnosing.
- Invite testers outside the agreed role.

## 4. Failure table

Before investigating, check these failures already recorded in [the journal](setup-experience.md).

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
| An account job waits indefinitely after dispatch. | Confirmed historically: a configured `apple-credentials` reviewer gate was pending. | Check `pending_deployments`; when reviewers are configured, approve only an authorized run ("Optional required-reviewer gate" above). | [milestone 5](journal/milestone-5-signing.md), 2026-10-09 |
| The app record name is rejected as taken. | Confirmed: record names are global across developers. | Propose another record name for approval. The Home Screen name and the bundle ID are unaffected. The SKU cannot be changed later. | [milestones 1–4](journal/milestone-1-4-foundation.md), Starter App demo identity |
| A dispatch fails with zero jobs and `Unrecognized named-value: 'runner'`. | Confirmed: `runner.*` used in a job-level `env`. | Move it to step-level `env`. | [milestone 7](journal/milestone-7-diagnostics.md), 2026-10-16 probe rejected |
| PowerShell prints replacement characters in diagnostic output. | Confirmed: Windows default stream encoding. | `$env:PYTHONUTF8='1'` and `[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()`. | [milestone 5](journal/milestone-5-signing.md), 2026-10-09 PR #8 |
| Diagnostics pass but membership and agreements stay "unverified". | Confirmed: the API diagnostics cannot check them. | Ask the Account Holder to confirm both in App Store Connect before the first upload. | [milestone 5](journal/milestone-5-signing.md), 2026-10-10 |

## 5. Setup limits and follow-ups

| Gap | Today | Tracked by |
| --- | --- | --- |
| Guided resumable setup | `python scripts/setup.py` checkpoints consent and completed stages; stage actions stay in this runbook, and each tool still needs its own action approval. Broader consent integration is not built | Master plan step 6, `scripts/setup.py`; issues #2, #3, #4, #17 |
| Stored key role record | Stage C notes; role must be confirmed separately from secret-name checks | Issue #1 |
| Feedback to sanitized issue draft | The feedback reader can write a redacted draft; review it privately and confirm its build association before filing | [Tester feedback guide](tester-feedback.md#windows-review-and-triage) |
| Ad hoc install without TestFlight | TestFlight only (Windows), `run-on-device` (Mac) | [Master plan](master-plan.md) step 4, evaluation pending |
| App record creation through the API | Human or browser agent | Issue #4 (verify whether the API permits it) |
