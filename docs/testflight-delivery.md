# Install your app through TestFlight

Use this guide to upload a signed build and install it on an iPhone through internal TestFlight testing. GitHub-hosted macOS runners build, sign and upload the app, so you can start from Windows or a Mac. Uploading, Apple processing and installation are separate steps; check each result.

## When to test where

| When | What runs | Device delivery |
| --- | --- | --- |
| Every pull request | Portable tests and one simulator smoke lane; these are required checks. | None. |
| Every merge to `main` | All configured simulator lanes. Signing and TestFlight preflights run on pull requests or manual dispatch, as described in [the CI guide](ci.md#the-pull-request-loop). | None. |
| Owner's iPhone, internal TestFlight | When merged changes alter what a user sees or does in the app. Batch changes, with at most one delivery per hour, dispatched from `main`. The `apple-credentials` environment accepts deployments from `main` only. | The delivery workflow uploads to internal TestFlight. |
| Other testers, external TestFlight | When a set of changes is ready for wider testing, at the owner's decision. | External testing is a separate owner decision and workflow; this guide's internal-only upload does not enable it. |

Changes with nothing visible to the user, including scripts, documentation and CI, never trigger a device build.

## Before the first upload

Read [Apple setup](apple-setup.md), inspect the intended app/team and current GitHub environment protections, and reuse existing credentials. Signing authorization alone does not authorize a TestFlight upload. Present one concrete plan covering the selected manifest/app, existing team key and role, app/build inventory reads, possible automatic signing effects, and upload. GitHub `apple-credentials` stays restricted to `main`; a required reviewer is optional. Pull requests never receive these secrets.

Apple lists Account Holder, Admin, App Manager and Developer as upload roles ([upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)). Signing/provisioning permissions are a separate requirement. Reuse the existing authorized key; do not automatically create, replace or broaden it. Its upload permission is unverified until a live attempt. The Account Holder reviews active membership and outstanding agreements before delivery. Those decisions are not proved by our diagnostics and remain human steps.

Replace the starter's placeholder icon before shipping. The Icon Composer document at `StarterApp/StarterApp/AppIcon.icon` contains SVG layers in `Assets/`, with the background, opacity, Liquid Glass and dark appearance set in `icon.json`. The placeholder uses Apple's demo circles and guide grid under Apple's Design Resources license; see the [app icon guide](app-icon.md) for its source and replacement steps.

Xcode compiles the document into the iOS 26 layered icon and PNG fallbacks for older iOS. Replace it with your own `.icon` of the same name (Icon Composer ships with Xcode), or edit the SVGs and `icon.json` by hand on any platform. The native archive/export checks require a compiled AppIcon. See [Apple icon guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons).

The initial route is **internal TestFlight testing** using an App Store Connect user with access to the app, normally the existing owner. Check whether the owner can already see and install the build in TestFlight before assuming a missing invitation or zero custom groups blocks installation. The owner reported successful installation without receiving a tester message; no group, invitation or individual assignment was created for this acceptance. This does not establish access for another tester/account. If the owner cannot access the build, inspect the existing account/build access first; creating a tester group or adding/inviting testers is a distinct account action requiring authorization. Managed Apple Accounts have testing restrictions; see [Apple's TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/) and [internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers).

Answer export-compliance questions based on the actual app. The workflow does not set `ITSAppUsesNonExemptEncryption`, sign agreements, create tester groups, invite people, submit Beta App Review or publish to the App Store. Internal-only exports cannot be used for external testing or App Store release; a future distribution route needs a reviewed export-policy change and a new build.

## Reviewed configuration and numbering

`project.yml` still controls the app identity, `MARKETING_VERSION`, deployment minimum and default `CURRENT_PROJECT_VERSION`. Adopters configure their own identity/team and choose `starter`; `starter-app-demo` is the existing acceptance app, not an identity to register for a new user. A fresh native export now records marketing version and default build number as well as identity/platform settings.

[The checked-in export policy](../config/ExportOptions-TestFlight.plist) sets `method=app-store-connect`, `destination=export`, automatic signing, internal-only testing and symbol upload eligibility. It disables Xcode's automatic build-number rewriting. The helper adds the selected native team ID without editing the policy in Git. It rejects unreviewed policy changes. Xcode exports first; the workflow validates the exact package before an explicit `altool --upload-package` operation. These choices were checked against native Xcode command help; the hosted preflight verifies the upload flags on the pinned toolchain.

The app's marketing version (`MARKETING_VERSION`) is separate from its build number (`CURRENT_PROJECT_VERSION`). Set or change the marketing version in `project.yml` when preparing a new app version; the delivery workflow reads it from that revision. For each upload attempt, the workflow proposes a distinct build number and checks it against the manifest and verified App Store Connect inventory. Builds for the same marketing version can therefore be uploaded successively without changing the app version; change the marketing version when you intend to distribute a new app version. Apple associates uploads with the version and build number embedded in the package ([Apple: view builds and metadata](https://developer.apple.com/help/app-store-connect/manage-builds/view-builds-and-metadata/)).

Build numbers use Apple's numeric `major.minor.patch` form (four/two/two digits; [Apple reference](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html)). The release helper reads **all** visible iOS build numbers for the exact existing app, including failed/expired builds, through paginated pinned CLI reads. It proposes a number from a stable base plus this workflow's run number and attempt, then requires it to exceed the manifest and every verified existing build. The base defaults to the manifest build number; set the non-secret **repository variable** `TESTFLIGHT_BUILD_NUMBER_BASE` to a reviewed higher numeric build version when adopting an existing app or competing upload tool. For example, base `500` makes the first proposal `500.0.1`. Keep the base stable or raise it; never lower it. A conflicting remote build blocks release with instructions to review/raise the base, rather than automatically reusing a number while Apple upload visibility is delayed. For example, run 1/attempt 1 starts at `1.0.1`; a rerun advances it. Gaps are intentional.

TestFlight text is currently entered manually in App Store Connect; metadata automation is not implemented. The app-level **Beta App Description** describes the beta and is required for external testing ([Apple: provide test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/)). **What to Test** is build testing guidance entered when distributing/adding that build for testers; explain what changed and which behaviors to check ([Apple: add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/)). Keep this information accurate for the selected app and build. Internal-only upload does not itself automate or require these metadata changes.

A missing/denied/malformed inventory is unknown and blocks release; it never becomes an assumed empty list. Workflow runs 1–999900 and attempts 1–99 are supported, and exhaustion fails explicitly. The release job is serialized within this repository. Another repository/tool uploading the same app can still race an eventually consistent Apple inventory. An upload failure or timeout may have accepted the build: inspect App Store Connect before retrying. The next run/attempt produces a distinct proposal from the stable base, even if Apple has not exposed the earlier upload yet. Do not assume a duplicate error means the app was never uploaded.

## Credential-free preflight

Pull-request checks use the demo manifest without accessing Apple credentials. **Actions → TestFlight delivery → Run workflow**, with **perform_upload unchecked**, performs the same unsigned preflight for the selected configured identity. It verifies native settings, reviewed export policy, upload-tool flags, release fixtures and an unsigned archive's actual identity, marketing version and planned build number. It downloads no live Apple inventory and validates no distribution signature.

Download `testflight-preflight` to read `configuration.json`, `release-plan.json` and the generated export options. `offline_preflight` explicitly means the build number has not been checked against Apple. It is not permission to upload. No API private key is needed for this check.

## Main-branch delivery

After the implementation is reviewed, merged and its required checks pass:

1. Change visible app behavior, commit/push, and inspect passing smoke-test and compiled-app artifacts for that commit. Use your configured manifest or the existing acceptance demo.
2. Review/approve the concrete upload plan. Dispatch **TestFlight delivery** on **main**, choose the intended **configuration**, and enable **perform_upload**. With `gh`, the demo command is:

   ```powershell
   gh workflow run testflight-delivery.yml --ref main --field configuration=starter-app-demo --field perform_upload=true
   ```

3. Inspect the selected commit/app in the workflow. The `apple-credentials` environment permits deployments from `main` only; there is no per-run reviewer step in this repository's setup. GitHub-hosted Xcode builds an unsigned archive, automatically exports a signed distribution package, and checks the signature/profile/certificate plus the actual package's identity and planned versions. The upload helper binds its authorization to the validated IPA's SHA-256. The private key is a temporary, restricted file; no private value is passed in arguments or logged.
4. Read the workflow summary and download `testflight-delivery-<configuration>`. It contains only allowlisted configuration/plan/validation/upload/processing reports and a Markdown summary. Archives, IPAs, key files, profiles, certificates and raw uploader responses are not uploaded as GitHub artifacts or cached. The runner removes temporary signing material and packages after success/failure.
5. `upload_accepted` means the uploader returned success, **not** that the build is ready to test. A bounded follow-up read records `not_visible_yet`, `PROCESSING`, `VALID`, `FAILED` or `INVALID`; inaccessible reads fail and remain unknown. `FAILED`/`INVALID` fail the processing step while preserving the accepted-upload evidence. `VALID` establishes processing, not compliance clearance, tester assignment or installation. A processing-read failure after upload can make the job red while the upload-report still says accepted—check that report before retrying.
6. In App Store Connect, confirm the exact marketing version/build number finished processing and review compliance questions. Check the existing owner's TestFlight access before deciding a group or assignment is needed. If a group or tester change is required, get authorization and follow [Apple's internal testing instructions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers); do not automatically invite others. Enter or update Beta App Description/What to Test manually when applicable; the workflow does not automate metadata.
7. Install/open TestFlight on the iPhone, install that exact build and confirm the visible behavior change. Record the version/build, commit/run link, device OS and observed result without exposing account credentials or unrelated personal data. A physical iPhone checks that device's OS; it does not establish iOS 17 runtime compatibility unless the phone actually runs iOS 17.

One command handles steps 2 to 5 from any machine with `gh`: `python scripts/deliver_testflight.py --configuration <name>`. It proposes the build, showing the `main` head, its newest iOS push run and any deliveries in flight. It dispatches with `perform_upload`, waits for preflight and completion, then prints the four stage statuses and a result line.

Use `--approve` only for repositories that choose to require a reviewer. If GitHub has no pending deployment, the option is ignored and the command keeps waiting for the workflow. Exit codes: 0 processed or accepted, 1 failed at a named step, 2 setup problem, 3 still running after `--wait-minutes` (resume with `--run <id>`). The command downloads only the sanitized `testflight-delivery-<configuration>` artifact and reads fixed status fields.

Template users who want an extra per-run gate can add a required reviewer in **Settings → Environments → `apple-credentials` → Required reviewers**, or run `python scripts/configure-github-repo.py --repo <owner>/<repository> --require-reviewer --apply`. The normal documented setup leaves reviewers off and retains the `main`-only deployment rule.

To dispatch from an automated caller and return immediately, use `python scripts/deliver_testflight.py --configuration <name> --no-wait`. It prints the workflow run ID and URL plus a `--run <id>` resume command, then exits 0 without waiting for an optional environment approval or workflow completion. `--approve` cannot be combined with `--no-wait`; if a reviewer is configured, approve the run through the normal environment review, then resume it when you want its final report.

### Recorded demo result

On 2026-10-12, the approved [GitHub-hosted delivery run](https://github.com/asavs/ios-app-starter/actions/runs/38117486727) accepted `starter-app-demo` build **1.0 (1.9.1)**. The owner reported opening that TestFlight build on their iPhone and seeing the `Built on GitHub Actions.` caption. No agent device inspection, screenshot or automated device report was collected, and the phone's OS version is unknown. No local Xcode or separately managed Mac was required.

Future app changes need their own delivery and device acceptance. Keep App Store publication separate. The demo's distribution certificate expires February 8, 2027; the validator must continue rejecting expired assets rather than treating earlier signing evidence as current readiness.

## Internal group with automatic distribution

An internal TestFlight group created with access to all builds receives every processed build without manual assignment. The setting is fixed at creation, so the **TestFlight groups** workflow creates a new group rather than editing one. Plan first (read-only), then apply:

```powershell
gh workflow run testflight-groups.yml --ref main --field configuration=starter-app-demo --field group_name=dev-auto --field tester_role=ACCOUNT_HOLDER --field apply=false
gh workflow run testflight-groups.yml --ref main --field configuration=starter-app-demo --field group_name=dev-auto --field tester_role=ACCOUNT_HOLDER --field apply=true
```

Both runs use the `apple-credentials` environment, whose deployment policy allows `main` only. If a repository separately configures required reviewers, that policy also gates these runs. The plan reports whether the group exists, whether it is internal with all-builds access, how many App Store Connect users hold the chosen role and how many are already members, and the actions it would take. Apply creates the group with `--internal --access-all-builds`, adds each missing user, and re-reads the group to verify. Nothing is deleted or modified; an existing group with the same name but without all-builds access stops the run for manual review. Retire a superseded group by hand in App Store Connect once the new one is verified. Reports and logs carry counts and statuses, never tester identities.

The manifest declares `ITSAppUsesNonExemptEncryption = NO`, so Apple does not ask the export-compliance question per build for apps without non-exempt encryption; the compiled-app and archive checks require the key. Revisit it when an app adds networking or cryptography.

## Debug symbols

Preflight verifies archive app/dSYM UUIDs; delivery additionally matches the exported IPA. See [symbol retention](device-diagnostics.md#implemented-symbol-check-and-retention). Optional `retain_symbols` keeps only dSYMs and their manifest for 90 days in private repositories. Public repositories reject this option; the default remains off. Older deliveries have no recoverable retained symbols in this repository.

## Tester feedback

Use [the tester feedback guide](tester-feedback.md) for focused What to Test notes, controlled submissions, Windows triage and targeted retest. Existing build access is sufficient to verify collection; do not upload merely for this exercise.
