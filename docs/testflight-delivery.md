# Install your app through TestFlight

This guide takes a signed build to an iPhone through internal TestFlight testing. GitHub-hosted macOS runners build, sign and upload the app, so you can start from Windows or a Mac. Upload, Apple processing and installation can each fail on their own; check each result.

## When to test where

| When | What runs | Device delivery |
| --- | --- | --- |
| Every pull request | Portable tests and one simulator smoke lane, as required checks. | None. |
| Every merge to `main` | All configured simulator lanes. Signing and TestFlight preflights run on pull requests or manual dispatch ([CI guide](ci.md#the-pull-request-loop)). | None. |
| Owner's iPhone, internal TestFlight | When merged changes alter what a user sees or does. Batch them: at most one delivery per hour, dispatched from `main`, the only branch the `apple-credentials` environment accepts. | The delivery workflow uploads to internal TestFlight. |
| Other testers, external TestFlight | When the owner decides a set of changes is ready for wider testing. | A separate decision and workflow; the internal-only upload here does not enable it. |

Changes nothing in the app shows, such as scripts, documentation and CI, never trigger a device build.

## Before the first upload

Read [Apple setup](apple-setup.md), check the intended app, team and GitHub environment protections, and reuse existing credentials. Authorization to sign does not authorize a TestFlight upload. Present one concrete plan covering the selected manifest and app, the existing team key and its role, the app and build inventory reads, possible automatic signing effects, and the upload. `apple-credentials` stays restricted to `main`; a required reviewer is optional. Pull requests never receive these secrets.

Apple allows Account Holder, Admin, App Manager and Developer to upload ([upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)); signing and provisioning permissions are a separate requirement. Reuse the existing authorized key; do not automatically create, replace or broaden it. Whether it can upload is unknown until a live attempt. The Account Holder confirms active membership and signed agreements before delivery; the diagnostics cannot check these, so they stay human steps.

Replace the placeholder icon before shipping. `StarterApp/StarterApp/AppIcon.icon` is an Icon Composer document: SVG layers in `Assets/`, with background, opacity, Liquid Glass and dark appearance in `icon.json`. The placeholder uses Apple's demo circles and guide grid under Apple's Design Resources license; the [app icon guide](app-icon.md) covers its source and replacement.

Xcode compiles the document into the iOS 26 layered icon plus PNG fallbacks for older iOS. Replace it with your own `.icon` of the same name (Icon Composer ships with Xcode), or edit the SVGs and `icon.json` by hand on any platform. The native archive and export checks require a compiled AppIcon. See [Apple icon guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons).

The first route is internal testing by an App Store Connect user with access to the app, normally the owner. Check whether the owner can already see and install the build before assuming a missing invitation or empty group list blocks installation: the owner of the demo app installed it with no tester message, group, invitation or assignment. That says nothing about other testers or accounts. If the owner cannot see the build, inspect existing account and build access first; creating a tester group or inviting testers is a separate account action that needs authorization. Managed Apple Accounts have testing restrictions; see [Apple's TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/) and [internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers).

Answer export-compliance questions for the actual app. The workflow does not set `ITSAppUsesNonExemptEncryption`, sign agreements, create tester groups, invite people, submit for Beta App Review or publish to the App Store. Internal-only exports cannot be used for external testing or App Store release; that needs a reviewed export-policy change and a new build.

## Reviewed configuration and numbering

`project.yml` controls the app identity, `MARKETING_VERSION`, deployment minimum and default `CURRENT_PROJECT_VERSION`. Configure your own identity and team and choose the `starter` configuration; `starter-app-demo` is the template's own registered app, not an identity to register. A fresh native export records the marketing version, default build number, identity and platform settings.

[The checked-in export policy](../config/ExportOptions-TestFlight.plist) sets `method=app-store-connect`, `destination=export`, automatic signing, internal-only testing and symbol upload, and turns off Xcode's automatic build-number rewriting. The helper adds the selected team ID without editing the policy in Git and rejects unreviewed policy changes. Xcode exports first; the workflow validates that exact package before uploading it with `altool --upload-package`. The hosted preflight verifies the upload flags on the pinned toolchain.

The marketing version (`MARKETING_VERSION`) is separate from the build number (`CURRENT_PROJECT_VERSION`). Change the marketing version in `project.yml` when you start a new app version; the workflow reads it from that revision. Each upload attempt gets a new build number, so you can upload repeatedly under one marketing version. Apple identifies uploads by the version and build number in the package ([Apple: view builds and metadata](https://developer.apple.com/help/app-store-connect/manage-builds/view-builds-and-metadata/)).

Build numbers use Apple's numeric `major.minor.patch` form (four, two and two digits; [Apple reference](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html)). The release helper reads **all** visible iOS build numbers for the app, including failed and expired builds, through paginated pinned CLI reads. It proposes a number from a stable base plus the workflow run number and attempt, and requires it to exceed the manifest and every existing build. Run 1, attempt 1 starts at `1.0.1`; a rerun advances it, and gaps are intentional. The base defaults to the manifest build number. When adopting an existing app or switching from another upload tool, set the non-secret repository variable `TESTFLIGHT_BUILD_NUMBER_BASE` to a reviewed higher build number: base `500` makes the first proposal `500.0.1`. Keep the base stable or raise it; never lower it. A conflicting remote build blocks release with instructions to raise the base; the helper never reuses a number, because Apple can be slow to show recent uploads.

A missing, denied or malformed inventory counts as unknown and blocks release; it is never treated as empty. Runs 1–999900 and attempts 1–99 are supported, and running out fails explicitly. Release jobs in this repository run one at a time, but another repository or tool uploading the same app can still race Apple's slow-to-update inventory. A failed or timed-out upload may still have been accepted: check App Store Connect before retrying, and do not read a duplicate error as proof it was never uploaded. The next run or attempt gets a new number either way.

TestFlight text is entered by hand in App Store Connect; the workflow does not automate it. The app-level **Beta App Description** is required for external testing ([Apple: provide test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/)). **What to Test** is per-build guidance entered when distributing the build: say what changed and what to check ([Apple: add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/)). Keep both accurate for the selected app and build.

## Credential-free preflight

Pull-request checks run this preflight on the demo manifest without Apple credentials. To run it for your configuration, use **Actions → TestFlight delivery → Run workflow** with **perform_upload unchecked**. It verifies native settings, the export policy, upload-tool flags, release fixtures, and an unsigned archive's identity, marketing version and planned build number. It reads no live Apple inventory and checks no distribution signature.

Download `testflight-preflight` to read `configuration.json`, `release-plan.json` and the generated export options. `offline_preflight` means the build number has not been checked against Apple; it is not permission to upload. No API private key is needed.

## Main-branch delivery

After the change is reviewed and merged and its required checks pass:

1. Check the passing smoke-test and compiled-app artifacts for the commit with the visible change.
2. Review and approve the concrete upload plan. Dispatch **TestFlight delivery** on **main**, choose the **configuration** (`starter` for your own app), and enable **perform_upload**. With `gh`, the demo command is:

   ```powershell
   gh workflow run testflight-delivery.yml --ref main --field configuration=starter-app-demo --field perform_upload=true
   ```

3. Check the commit and app the workflow selected. `apple-credentials` permits deployments from `main` only, with no per-run reviewer in the default setup. Hosted Xcode builds an unsigned archive, exports a signed distribution package, and checks its signature, profile, certificate, identity and planned versions. The upload helper binds its authorization to the validated IPA's SHA-256. The private key is a temporary, restricted file; no private value is passed in arguments or logged.
4. Read the workflow summary and download `testflight-delivery-<configuration>`. It holds only allowlisted configuration, plan, validation, upload and processing reports and a Markdown summary. Archives, IPAs, key files, profiles, certificates and raw uploader responses are never uploaded as artifacts or cached, and the runner deletes signing material and packages whether the job passes or fails.
5. `upload_accepted` means the uploader returned success, **not** that the build is ready to test. A bounded follow-up read records `not_visible_yet`, `PROCESSING`, `VALID`, `FAILED` or `INVALID`; a read that cannot reach Apple fails and stays unknown. `FAILED` and `INVALID` fail the processing step but keep the accepted-upload evidence. `VALID` means processed, not cleared for compliance, assigned to testers or installed. A failed processing read can turn the job red while the upload report still says accepted, so check that report before retrying.
6. In App Store Connect, confirm that exact version and build finished processing and review the compliance questions. Check the owner's existing TestFlight access before deciding a group or assignment is needed. If a group or tester change is needed, get authorization and follow [Apple's internal testing instructions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers); do not invite others automatically. Enter Beta App Description and What to Test by hand where they apply.
7. On the iPhone, install that exact build from TestFlight and confirm the visible change. Record the version and build, commit and run link, device OS and result, without account credentials or unrelated personal data. A physical iPhone tests its own OS only; it does not establish iOS 17 compatibility unless it runs iOS 17.

`python scripts/deliver_testflight.py --configuration <name>` does steps 2 to 5 from any machine with `gh`. It shows the proposed build, the `main` head, its newest iOS push run and any deliveries in flight, dispatches with `perform_upload`, waits for preflight and completion, then prints the four stage statuses and a result line. It downloads only the sanitized `testflight-delivery-<configuration>` artifact and reads fixed status fields.

Exit codes: 0 processed or accepted, 1 failed at a named step, 2 setup problem, 3 still running after `--wait-minutes` (resume with `--run <id>`). Use `--approve` only if the repository requires a reviewer; with no pending deployment it is ignored.

To dispatch from an automated caller and return at once, use `python scripts/deliver_testflight.py --configuration <name> --no-wait`. It prints the run ID, URL and a `--run <id>` resume command, then exits 0. `--approve` cannot be combined with `--no-wait`; if a reviewer is configured, approve the run through the environment review and resume when you want the final report.

To add a per-run gate, add a required reviewer under **Settings → Environments → `apple-credentials` → Required reviewers**, or run `python scripts/configure-github-repo.py --repo <owner>/<repository> --require-reviewer --apply`. The default setup has no reviewer and keeps the `main`-only rule.

### Recorded demo result

On 2026-10-12, the approved [GitHub-hosted delivery run](https://github.com/asavs/ios-app-starter/actions/runs/38117486727) accepted `starter-app-demo` build 1.0 (1.9.1). The owner reported opening it from TestFlight on their iPhone and seeing the `Built on GitHub Actions.` caption. No agent inspected the device or collected a screenshot, and the phone's OS version is unknown. No local Xcode or separate Mac was used.

Each later app change needs its own delivery and device check. Keep App Store publication separate. The demo's distribution certificate expires February 8, 2027; the validator must keep rejecting expired assets rather than trusting earlier signing evidence.

## Internal group with automatic distribution

An internal TestFlight group created with access to all builds receives every processed build without manual assignment. That setting is fixed at creation, so the **TestFlight groups** workflow creates a new group rather than editing one. Plan first (read-only), then apply. The demo commands are below; for your own app use `configuration=starter`:

```powershell
gh workflow run testflight-groups.yml --ref main --field configuration=starter-app-demo --field group_name=dev-auto --field tester_role=ACCOUNT_HOLDER --field apply=false
gh workflow run testflight-groups.yml --ref main --field configuration=starter-app-demo --field group_name=dev-auto --field tester_role=ACCOUNT_HOLDER --field apply=true
```

Both runs use `apple-credentials`, so they run from `main` only, and behind any required reviewer the repository has added. The plan reports whether the group exists, whether it is internal with all-builds access, how many App Store Connect users hold the chosen role and how many are already members, and what it would do. Apply creates the group with `--internal --access-all-builds`, adds each missing user, and re-reads the group to verify. Nothing is deleted or modified; an existing group of the same name without all-builds access stops the run for manual review. Once the new group is verified, retire any group it replaces by hand in App Store Connect. Reports and logs carry counts and statuses, never tester identities.

The manifest declares `ITSAppUsesNonExemptEncryption = NO`, so Apple does not ask the export-compliance question for each build; the compiled-app and archive checks require the key. Revisit it when the app adds networking or cryptography.

## Debug symbols

Preflight matches the archive's app and dSYM UUIDs; delivery also matches the exported IPA. See [symbol retention](device-diagnostics.md#implemented-symbol-check-and-retention). The optional `retain_symbols` input keeps only dSYMs and their manifest for 90 days, in private repositories only; public repositories reject it, and it is off by default.

## Tester feedback

See [the tester feedback guide](tester-feedback.md) for What to Test notes, controlled submissions, Windows triage and retesting. Existing build access is enough to verify feedback collection; do not upload a build just for this.
