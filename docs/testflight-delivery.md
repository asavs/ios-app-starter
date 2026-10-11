# TestFlight delivery from Windows

Milestone 5 proved a distribution-signed export for the demo app. Milestone 6 finishes only when a Windows user changes visible app behavior, uploads the resulting build using GitHub Actions, and installs/verifies it on their iPhone. This implementation is awaiting live upload and device acceptance. No local Xcode or separately managed Mac is required.

## Before the first upload

Read [Apple setup](apple-setup.md), inspect the intended app/team and current GitHub environment protections, and reuse existing approved credentials. Signing authorization alone does not authorize a TestFlight upload. Present one concrete approval plan covering the selected manifest/app, existing team key and role, app/build inventory reads, possible automatic signing effects, and upload. GitHub `apple-credentials` stays restricted to main with the chosen reviewer policy. Pull requests never receive these secrets.

Apple lists Account Holder, Admin, App Manager and Developer as upload roles ([upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)). Signing/provisioning permissions are a separate requirement. Reuse the existing authorized key; do not automatically create, replace or broaden it. Its upload permission is unverified until a live attempt. The Account Holder reviews active membership and outstanding agreements before delivery. Those decisions are not proved by our diagnostics and remain human steps.

The starter includes an original opaque 1024px placeholder icon. Replace it through the existing AppIcon asset catalog for your own app. Its vector reference is `design/starter-icon.svg`; `python scripts/generate-starter-icon.py` regenerates the default PNG/SVG using only the standard library. The native archive/export checks require a compiled AppIcon. See [Apple icon guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons).

The initial route is **internal TestFlight testing** using an App Store Connect user with access to the app, normally the existing owner. Confirm that tester's access rather than inviting unrelated people or broadening team roles. Managed Apple Accounts have testing restrictions; see [Apple's TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/) and [internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers). Creating a tester group or adding/inviting testers is a distinct account action requiring the user's authorization.

Answer export-compliance questions based on the actual app. The workflow does not set `ITSAppUsesNonExemptEncryption`, sign agreements, create tester groups, invite people, submit Beta App Review or publish to the App Store. Internal-only exports cannot be used for external testing or App Store release; a future distribution route needs a reviewed export-policy change and a new build.

## Reviewed configuration and numbering

`project.yml` still controls the app identity, `MARKETING_VERSION`, deployment minimum and default `CURRENT_PROJECT_VERSION`. Adopters configure their own identity/team and choose `starter`; `starter-app-demo` is the existing acceptance app, not an identity to register for a new user. A fresh native export now records marketing version and default build number as well as identity/platform settings.

[The checked-in export policy](../config/ExportOptions-TestFlight.plist) sets `method=app-store-connect`, `destination=export`, automatic signing, internal-only testing and symbol upload eligibility. It disables Xcode's automatic build-number rewriting. The helper adds the selected native team ID without editing the policy in Git. It rejects unreviewed policy changes. Xcode exports first; the workflow validates the exact package before an explicit `altool --upload-package` operation. These choices were checked against native Xcode command help; the hosted preflight verifies the upload flags on the pinned toolchain.

Build numbers use Apple's numeric `major.minor.patch` form (four/two/two digits; [Apple reference](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html)). The release helper reads **all** visible iOS build numbers for the exact existing app, including failed/expired builds, through paginated pinned CLI reads. It proposes a number from a stable base plus this workflow's run number and attempt, then requires it to exceed the manifest and every verified existing build. The base defaults to the manifest build number; set the non-secret **repository variable** `TESTFLIGHT_BUILD_NUMBER_BASE` to a reviewed higher numeric build version when adopting an existing app or competing upload tool. For example, base `500` makes the first proposal `500.0.1`. Keep the base stable or raise it; never lower it. A conflicting remote build blocks release with instructions to review/raise the base, rather than automatically reusing a number while Apple upload visibility is delayed. For example, run 1/attempt 1 starts at `1.0.1`; a rerun advances it. Gaps are intentional. Marketing version remains separately controlled by the manifest.

A missing/denied/malformed inventory is unknown and blocks release; it never becomes an assumed empty list. Workflow runs 1–999900 and attempts 1–99 are supported, and exhaustion fails explicitly. The release job is serialized within this repository. Another repository/tool uploading the same app can still race an eventually consistent Apple inventory. An upload failure or timeout may have accepted the build: inspect App Store Connect before retrying. The next run/attempt produces a distinct proposal from the stable base, even if Apple has not exposed the earlier upload yet. Do not assume a duplicate error means the app was never uploaded.

## Credential-free preflight

PR/push checks use the demo manifest without accessing Apple credentials. **Actions → TestFlight delivery → Run workflow**, with **perform_upload unchecked**, performs the same unsigned preflight for the selected configured identity. It verifies native settings, reviewed export policy, upload-tool flags, release fixtures and an unsigned archive's actual identity, marketing version and planned build number. It downloads no live Apple inventory and validates no distribution signature.

Download `testflight-preflight` to read `configuration.json`, `release-plan.json` and the generated export options. `offline_preflight` explicitly means the build number has not been checked against Apple. It is not permission to upload. No API private key is needed for this check.

## Approved main-branch delivery

After the implementation is reviewed, merged and its required checks pass:

1. Change visible app behavior from Windows, commit/push, and inspect passing smoke-test and compiled-app artifacts for that commit. Use your configured manifest or the existing acceptance demo.
2. Review/approve the concrete upload plan. Dispatch **TestFlight delivery** on **main**, choose the intended **configuration**, and enable **perform_upload**. With `gh`, the demo command is:

   ```powershell
   gh workflow run testflight-delivery.yml --ref main --field configuration=starter-app-demo --field perform_upload=true
   ```

3. Inspect the selected commit/app in the workflow, and complete the already authorized `apple-credentials` environment approval. GitHub-hosted Xcode builds an unsigned archive, automatically exports a signed distribution package, and checks the signature/profile/certificate plus the actual package's identity and planned versions. The upload helper binds its authorization to the validated IPA's SHA-256. The private key is a temporary, restricted file; no private value is passed in arguments or logged.
4. Read the workflow summary and download `testflight-delivery-<configuration>`. It contains only allowlisted configuration/plan/validation/upload/processing reports and a Markdown summary. Archives, IPAs, key files, profiles, certificates and raw uploader responses are not uploaded as GitHub artifacts or cached. The runner removes temporary signing material and packages after success/failure.
5. `upload_accepted` means the uploader returned success, **not** that the build is ready to test. A bounded follow-up read records `not_visible_yet`, `PROCESSING`, `VALID`, `FAILED` or `INVALID`; inaccessible reads fail and remain unknown. `VALID` establishes processing, not compliance clearance, tester assignment or installation. A processing-read failure after upload can make the job red while the upload-report still says accepted—check that report before retrying.
6. In App Store Connect, confirm the exact marketing version/build number finished processing, review compliance questions, and add the approved build to the intended internal tester group. Use the existing authorized tester. Follow [Apple's internal testing instructions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers); do not automatically invite others.
7. Install/open TestFlight on the iPhone, install that exact build and confirm the visible behavior change. Record the version/build, commit/run link, device OS and observed result without exposing account credentials or unrelated personal data. A physical iPhone checks that device's OS; it does not establish iOS 17 runtime compatibility unless the phone actually runs iOS 17.

Only that successful upload/processing/installation/behavior loop completes milestone 6. Keep App Store publication separate. The demo's distribution certificate expires February 8, 2027; the validator must continue rejecting expired assets rather than treating earlier signing evidence as current readiness.
