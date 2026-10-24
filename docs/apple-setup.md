# Set up Apple access and signing

Use this guide when you want to sign your app or prepare it for TestFlight. Check the Apple account, choose the access each operation needs, and run diagnostics before changing anything. You can build and test the app without an Apple account. For hosted builds, GitHub Actions handles Xcode; you do not need to manage a Mac.

## Human prerequisites

1. Check whether you already have an active [Apple Developer Program membership](https://developer.apple.com/programs/enroll/). Choose individual or organization enrollment deliberately. Apple requires identity verification; organizations also need appropriate legal authority and organization information. Enrollment includes payment unless a waiver applies. Do not create a second membership merely because an API check failed.
2. Sign in to [App Store Connect](https://appstoreconnect.apple.com/) and confirm the intended team and your role. Have the Account Holder review membership status and outstanding agreements. These diagnostics do not verify that all contractual prerequisites are satisfied.
3. The Account Holder requests API access under **Users and Access → Integrations → App Store Connect API → Request Access**. Apple reviews requests. A missing button or pending approval is a human/account prerequisite, not a broken Windows installation. See [Apple's API access instructions](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/).
4. Choose key type and role with the account owner. Team keys have role-based access across the team's apps; individual keys inherit their user's app access and permissions. Do not default to Admin. Provisioning permissions must be checked separately from app-list access; a successful app read does not establish signing access. See [Apple's key creation instructions](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api) and [role permissions](https://developer.apple.com/support/roles/). The diagnostic records inaccessible provisioning endpoints without trying a broader key automatically.
5. Generate and download the chosen key through Apple's website. Private keys can be downloaded only once. Keep a secure backup outside the checkout; never paste the private key, passwords, 2FA codes or signing passwords into agent chat. Lost/compromised keys require deliberate revocation and replacement by the owner.

The starter has one iPhone/iPad app target and its test targets. Mac, Watch, TV and Vision targets are planned options. The native configuration check rejects capability/entitlement additions until their setup is supported. Declaring an entitlement in Xcode does not grant Apple account approval; request-only capabilities need Apple's approval separately. Diagnostics do not enable capabilities or assume that a key can do so.

A computer-use agent can explain the pages, navigate, inspect visible account state, diagnose missing permissions and prepare a concrete plan. The human handles identity verification, passwords/2FA, payment and agreement decisions. Key creation, permission changes and account mutations need a specific authorized plan; agreeing to diagnostics does not authorize them. Avoid capturing private-key contents in screenshots or logs. There is no Apple browser automation or MCP dependency in this template.

## Choose access for the operation

Apple explicitly excludes provisioning endpoints from **individual API keys**, even when the associated user has an elevated role. A **team key** can use those endpoints subject to its role, and covers all team apps. The role of the person creating a key and the role assigned to that key are separate decisions. See [Apple's key-type restrictions](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api).

The pinned wrapper executes the following commands with `--paginate --output json`. This table maps the access needed; it does not certify an untested key's permissions.

| Operation | Access plan |
| --- | --- |
| `apps list --bundle-id <exported ID>` | App Store Connect app-read access. An individual key inherits the user's selected apps; a team key covers all apps. Reuse existing permitted access. |
| `bundle-ids list --identifier <exported ID>` | Provisioning endpoint: team key and permission to read registered identifiers. |
| `certificates list --certificate-type DISTRIBUTION,IOS_DISTRIBUTION --fields certificateType,expirationDate` | Provisioning endpoint: team key and certificate inventory access. This team-wide read does not retrieve the signing private key. |
| `bundle-ids profiles list --id <accessible resource ID>` | Provisioning endpoint: team key and profile-read access. Runs only when a matching bundle ID resource is accessible. |

These provisioning resources are described in Apple's [Bundle IDs](https://developer.apple.com/documentation/appstoreconnectapi/bundle-ids), [Certificates](https://developer.apple.com/documentation/appstoreconnectapi/certificates), and [Profiles](https://developer.apple.com/documentation/appstoreconnectapi/profiles) references. App reads may succeed while provisioning reads are denied. Keep those findings unknown; do not create duplicate identifiers or request a broader key merely to turn the report green.

Use **Developer** as the least-privilege starting role for read-only diagnostics: an individual key is limited to the user's selected apps and can run the app-record read; the full diagnostic also reads provisioning resources, so it needs a team key. Apple documents that individual keys cannot use provisioning endpoints, but does not specify the minimum team-key role for each inventory endpoint. Verify those reads with existing authorized access; a denied read stays unknown and is not a reason to broaden a key automatically.

For the hosted automatic-signing workflow, use a **team API key with the Admin role** when Xcode is allowed to create or refresh distribution assets. The workflow passes that key to `xcodebuild` with `-allowProvisioningUpdates`. Apple's certificate overview and App Store profile guide both specify Account Holder or Admin for creating the distribution certificate and profile; Admin is the least-privileged team-key role among those documented options. A team key also covers every team app. If a valid certificate/private key and matching profile are already prepared and the selected signing path can reuse them without provisioning updates, use that narrower path instead of granting an API key broader access.

The acceptance repository's existing stored team key has the **Admin** role. The role was confirmed separately from secret metadata and the key was reused for the protected signing run; no key identifier or private-key material is recorded here. Template adopters must confirm and record their own role. Never create, replace, elevate or revoke a key automatically.

Choose a signing path before choosing new credentials:

| Step | Permission and verification needed |
| --- | --- |
| Archive with already prepared signing assets | Reuse an authorized distribution certificate **with its private key** and a matching valid profile. Local signing does not itself require an API key. Validate the archive on the hosted runner. |
| Automatic signing with provisioning updates | Use a team key with **Admin** role for the supported hosted workflow. Xcode may create or update identifiers, certificates and profiles, so preview those intended changes first. An app-read or profile-list success does not verify creation permission. |
| Create or refresh distribution assets through the supported Xcode automatic-signing workflow | Apple documents Account Holder or Admin for creating distribution certificates and App Store profiles; Admin is the available team-key role with the documented permission. Do not treat the role matrix's separate Certificates, Identifiers & Profiles access as proof that App Manager can perform these specific writes. If assets can be reused without provisioning updates, choose that path and avoid this broader permission. |
| Create an App Store Connect app record | Account Holder, Admin or App Manager, plus required agreements. This is separate from registering an App ID. |
| Upload to TestFlight | Check upload permission separately before using the delivery workflow. A key accepted for diagnosis has not been verified for uploading. |

Start by reusing existing access and assets, with no new key during diagnosis. For organization users, Certificates, Identifiers & Profiles is separate access. Users invited to an individual's App Store Connect account are not members of that person's Developer Program team. Enrollment, API-access approval and agreements stay with the owner.

Before credential entry, record the intended team, selected manifest/bundle ID, key type and role, whether each operation is a read or a change, and the automatic/manual signing path. Never broaden, replace or revoke an existing key automatically. Verify signing permissions for the chosen path; successful diagnostics alone do not establish them.

## App identity and Apple's defaults

The manifest's bundle identifier links the app to its Apple records. **Home Screen display name** (`INFOPLIST_KEY_CFBundleDisplayName`) and **App Store Connect record name** are separate. Apple's record-name availability rules can reject a name another developer uses without preventing that Home Screen name. If creation rejects a name, present an alternative for approval before retrying; do not change the app identifier or create duplicate records to work around the name. See [Apple's new-app instructions](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/).

Before creating a record, confirm the team, intended app access, platform, bundle ID, record name, primary language and SKU. The SKU is internal and cannot be changed after creation ([Apple app-information reference](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)). First inspect and reuse a matching existing record. Our demo uses the existing **Starter App Template Demo** record; its Home Screen name is **Starter App**. Template adopters edit `project.yml` with their own identity and use the `starter` selection; they should not register or sign our demo identifier.

**In-App Purchase is enabled by default for an explicit App ID**, and Apple's form disables a checkbox when a service is enabled by default ([Apple App ID registration](https://developer.apple.com/help/account/identifiers/register-an-app-id/)). A checked, disabled toggle is expected; it does not mean the starter implements purchases or needs StoreKit code. Leave unrelated optional capabilities off.

Account capabilities are an allowlist, separate from the project's requested capabilities and the app's signed entitlements. During signed-archive validation, check that the generated signing settings, profile and signed app entitlements match the selected app and planned features. An unsigned simulator build cannot supply that evidence.

## Run diagnostics without credentials

The command requires Python 3 and works on Windows, Linux and macOS. It does not require Xcode, the CLI, a key or an Apple account:

```powershell
python scripts/apple-doctor.py
```

It writes `build/apple-diagnostics/report.md` and `report.json`. A successful exit means the diagnostic completed, **not** that signing or TestFlight is ready. Missing prerequisites remain findings with next actions. Malformed configuration input or report-writing failures exit unsuccessfully.

For project findings, run the **iOS** workflow and download `ios-test-results-starter` from its run page. Extract it outside the repository and use its `configuration.json`:

```powershell
python scripts/apple-doctor.py --configuration C:\Downloads\ios-test-results-starter\configuration.json
```

Match the run's commit to your current `project.yml`. The export contains Xcode's resolved Debug and Release settings; this script consumes that report rather than attempting to run Xcode or introducing another configuration format on Windows. An old export does not verify your current changes. Minimum iOS 17 in the export does not prove a test was run on iOS 17.

Alternatively, run **Actions → Apple diagnostics → Run workflow**, choose **configuration** (`starter`, `pocket-notes`, or `starter-app-demo`), and leave account reads disabled. `starter` uses your current `project.yml`; the other choices use native example overrides. The hosted Mac validates and exports that selection. If account reads are enabled, they use the same run's export.

The configuration job summary shows the manifest, commit and resolved bundle identifier. Download `apple-project-diagnostics` for the report and `apple-configuration` for the export. Ordinary push/PR checks use no Apple secrets. The signed-archive workflow also requires an explicit selection and generates a fresh export from it on each run. It never uses a stale downloaded export.

## Optional authenticated reads

`apple-credentials` is a GitHub Actions environment for access to Apple API secrets. GitHub may show its jobs under “Deployments”; the diagnostic job reads account state and does not upload or publish an app.

Reuse an approved key when possible. Credentials are unnecessary for unsigned CI; configure them when you need account diagnostics or signing. For the GitHub path, create an environment named **apple-credentials** with deployment branches restricted to exactly `main`. The documented setup has no required reviewer; you may add one in GitHub environment settings. Verify the main-only rule before storing any values.

`scripts/bootstrap-apple-credentials.py` transfers a securely stored `.p8` file directly to GitHub Secrets over `gh` standard input. It first checks the environment restrictions and existing secret names. It does not read secret values back and refuses replacement unless explicitly requested. Keep the source file outside the checkout. Never put its contents into chat or command arguments.

The script's `--approval-policy` defaults to `none`. Select `independent` or `solo-owner` only if that reviewer policy is configured. The script verifies settings; it does not change them, invite collaborators, enable authenticated reads or change Apple account settings. Use `--help` for the remaining syntax. The transfer works on Windows, macOS and Linux with Python and an authenticated GitHub CLI. Windows testing establishes portability; setup does not have to happen there.

| Bootstrap option | Required environment policy |
| --- | --- |
| `--approval-policy none` (default) | No required reviewers; exactly one deployment branch rule for `main`. |
| `--approval-policy independent` | One or more required reviewers; **Prevent self-review** enabled. A different eligible reviewer must approve the job. |
| `--approval-policy solo-owner` | Personal repository; its authenticated owner is the sole required reviewer; **Prevent self-review** disabled. The owner manually approves their own job. |

Every mode requires exactly one branch rule for `main`. Reviewer policies add a deployment approval gate; the default `none` mode does not. Solo-owner approval provides a deliberate manual checkpoint, without an independent second person. Choose it explicitly for a personal repository; do not configure a collaborator solely to satisfy the template. Organization repositories that want a reviewer gate should use independent approval. An agent must present the selected policy and intended Apple signing changes before credential setup.

### Collect the approval gates together

To avoid interrupting setup for predictable decisions, the agent should first inspect the current repository, team, app identity, existing key and assets, then present one concrete approval request covering the planned phases. Name the repository/environment policy and any optional reviewer; the exact Apple team, existing app/bundle ID and key type/role; transfer of that existing key into the named GitHub environment; read-only diagnostics for the selected manifest; and, if signing is in scope, Xcode automatic signing and its possible profile/certificate changes. State what is expressly excluded, such as new app records, unrelated capability changes, revocation and TestFlight upload.

Do not ask for or accept passwords, 2FA codes, payment or agreement decisions. The account owner completes sign-in and those human-only steps. If the intended team, app, key, assets or effects are unknown, inspect first and ask only about the unresolved choice. A diagnostic authorization covers read-only account requests; it does not authorize signing. A signing authorization covers the named app and allowed automatic-signing effects; it does not authorize TestFlight. With a reviewer policy enabled, approve an environment deployment only when the owner explicitly included that workflow and effect in the authorization. Solo-owner approval is the repository owner's approval, not an independent review.

| Name | Value |
| --- | --- |
| `ASC_KEY_ID` | API key ID |
| `ASC_ISSUER_ID` | Issuer ID for a team key; omit for an individual key |
| `ASC_PRIVATE_KEY` | Complete downloaded `.p8` PEM contents, entered directly into GitHub Secrets |

In GitHub, use **Settings → Environments → apple-credentials → Environment secrets → Add secret**. See [GitHub's secret-entry instructions](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets#creating-secrets-for-an-environment) and [environment protections](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments).

Set environment **variable** `ASC_KEY_TYPE` to `team` or `individual`; do not use ordinary variables for private material. Protect `main` and review workflow changes: code allowed to run with secrets can access them. The account job is manually enabled, restricted to `main`, and separate from PR jobs. It performs no login, key creation, account mutation, archive, or upload.

Run **Apple diagnostics** on `main`, choose the intended configuration and enable its account checkbox only when ready for authenticated reads. Missing secrets produce a prominent **requested but skipped** warning and job summary. The headline distinguishes skipped, authentication-failed, inaccessible, incomplete and completed checks, with the number of successfully resolved record checks. A completed empty read still counts as a successful check, while its finding is `missing`; a profile check remains unverified if no accessible bundle ID was established. Green means the diagnostic ran, not that Apple setup is ready. The report includes only sanitized findings and counts. Do not upload raw CLI responses or credential files. Review artifact access before sharing a diagnostic, even though it excludes credentials and upstream account identifiers.

The **Signed archive validation** workflow runs a credential-free preflight for pull requests and manual dispatches, using the demo manifest and a fresh native Xcode configuration export. Its signing-validator fixtures check validation behavior; they do not establish a real signed archive. Leave **perform_signing** unchecked for preflight only.

Actual signing requires a dispatch from `main`, **perform_signing** explicitly enabled, and one manifest choice with a configured team ID. The `apple-credentials` environment limits these jobs to `main`; the documented setup has no required reviewer. Pull requests do not use this environment or receive signing secrets.

The hosted Xcode 27 runner regenerates the project and configuration export. The same export supplies authenticated account diagnostics, team selection and archive validation. Accessible existing app and bundle-ID records must be verified before Xcode starts the archive. The workflow builds an unsigned archive, then asks Xcode to export an App Store Connect distribution package with automatic signing and `destination=export`. It does not upload the package.

Xcode may create or update the app's distribution provisioning profile and may create a distribution certificate. Review and approve those intended Apple account changes before dispatching. The exported app is checked against the archive and fresh manifest for identity, signature, entitlements, profile/certificate match and expiry.

Preflight uploads the public configuration export. The signing job uploads only the sanitized validation report. It removes the private key, archive and exported package from runner temporary storage. TestFlight uses a reviewed, checked-in `ExportOptions.plist` policy at [config/ExportOptions-TestFlight.plist](../config/ExportOptions-TestFlight.plist).

Automatic signing requires an App ID prefix matching the team ID. Legacy prefixes are rejected and need a separately reviewed manual-signing path; that alternative is not yet implemented.

For local Windows use, Python 3 and `curl.exe` are prerequisites; no Go toolchain is needed:

```powershell
python scripts/install-asc.py
python scripts/apple-doctor.py --configuration C:\Downloads\ios-test-results-starter\configuration.json --account --asc build\tools\asc.exe
```

Supply the same credential environment fields through your secure local environment/secret tooling. You can use `ASC_PRIVATE_KEY_PATH` pointing to an existing securely stored file outside the checkout instead of `ASC_PRIVATE_KEY`. Do not type literal secrets into shell commands or transcripts. Local file access restrictions and Windows ACLs remain your responsibility; these tools do not install a Windows credential vault. Individual keys omit the issuer ID.

The wrapper isolates CLI configuration, bypasses stored Keychain/config profiles, disables telemetry/debug settings and uses only the supplied environment credential fields. It does not save a credential profile. Temporary key material stays in the wrapper's temporary directory, which it removes after reads or a child timeout. Hard termination of the wrapper itself can still interrupt cleanup. Prefer the short-lived hosted runner for account checks; use the bootstrap script above to transfer credentials securely to GitHub.

## Interpret the report

| Status | Meaning |
| --- | --- |
| `reported` | An exported configuration was inspected; verify its provenance and freshness. |
| `configured` | Required fields are supplied; this does not establish validity. |
| `placeholder` | The app still uses a `com.example.*` identifier. |
| `present` | A completed read found accessible records. This does not prove assets are usable. |
| `missing` | A completed, paginated read returned no accessible matching records. Check the team and permissions before creating anything. |
| `inaccessible` | The CLI reported recognizable denied-access language. This does not establish whether records exist. |
| `authentication_failed` | The CLI reported recognizable authentication failure language. |
| `not_configured` | Complete explicit environment credentials were not supplied. |
| `not_verified` | The check was skipped or could not establish a result. |

The wrapper reads app records filtered by the configured bundle ID, matching registered bundle IDs, distribution-certificate inventory, and profiles linked to an accessible bundle ID. Certificate inventory is team-wide. Existing certificates may be expired or lack a locally available private key. Linked profiles may be expired, invalid or wrong for distribution; signed-archive validation checks these separately. Diagnostics leave membership, agreement acceptance, capability approval, signed archives and device delivery unverified.

The CLI emits human-readable errors which do not always include an HTTP status/code. The wrapper conservatively classifies recognizable denied/authentication language and leaves other errors unverified; a 403 or 404 must never be treated as an empty successful list. A later CLI version with structured errors could improve specificity.

## Reviewed CLI dependency

The template uses [App-Store-Connect-CLI 5.14.0](https://github.com/rorkai/App-Store-Connect-CLI/releases/tag/5.14.0) as a subprocess, downloaded only when requested. `scripts/install-asc.py` pins published SHA-256 values and checks bytes before saving a binary. It executes no remote installer and changes no global PATH. Its native Windows release is amd64; Windows ARM has no reviewed native asset in this pin. Linux and macOS support amd64/arm64. TLS verification stays enabled.

The upstream CLI is MIT licensed; see [the upstream license](https://github.com/rorkai/App-Store-Connect-CLI/blob/5.14.0/LICENSE). This template does not vendor its source or redistribute release binaries. Its module path retains the original `rudrankriyam` owner even though the release repository is `rorkai`; that is not a reason to build the ignored reference checkout.

Upstream telemetry defaults to enabled. The integration sets `ASC_TELEMETRY_DISABLED=1` and `DO_NOT_TRACK=1` without changing a user's preferences. The wrapper uses only `apps list`, `bundle-ids list`, `certificates list`, and `bundle-ids profiles list`, with JSON and pagination. Do not replace these with `auth login`, `auth doctor --fix`, web-session login, token output or arbitrary agent-generated CLI strings. Those commands have different effects and exposure risks.

CI tests permission failures, incomplete credentials, malformed responses, timeouts and secret-canary redaction using fixtures. Native CLI help/version runs check executable and flag availability on each platform. **A fixture pass is not a real Apple account check.** Use the opt-in workflow to establish findings for your account before signing. The demo's recorded signing result does not verify another account.


## Continue to TestFlight

The demo's signing evidence is recorded in the [roadmap](../roadmap.md). To upload your app, obtain explicit TestFlight authorization and follow [the delivery guide](testflight-delivery.md). The [archived Windows handoff](archive/windows-milestone-6-handoff.md) records the original acceptance steps.

Existing signing/key approvals persist; do not request them again unless the plan changes. Check upload permission separately. The Account Holder handles agreements and compliance decisions. Release app/build reads use the same pinned CLI and isolated Reader through fixed commands in `scripts/testflight-release.py`. They require explicit `--account`, keep the diagnostic command interface narrow, and never forward raw account output. Implementation and fixture tests alone do not establish live account access or a successful upload.
