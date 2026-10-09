# Apple setup from Windows

This is milestone 4: guidance and read-only diagnostics. You can already build and test without an Apple account. Signing and validated archives follow in milestone 5; installing through TestFlight follows in milestone 6. You do not need to operate a Mac: GitHub Actions performs Xcode work.

## Human prerequisites

1. Check whether you already have an active [Apple Developer Program membership](https://developer.apple.com/programs/enroll/). Choose individual or organization enrollment deliberately. Apple requires identity verification; organizations also need appropriate legal authority and organization information. Enrollment includes payment unless a waiver applies. Do not create a second membership merely because an API check failed.
2. Sign in to [App Store Connect](https://appstoreconnect.apple.com/) and confirm the intended team and your role. Have the Account Holder review membership status and outstanding agreements. These diagnostics do not verify that all contractual prerequisites are satisfied.
3. The Account Holder requests API access under **Users and Access → Integrations → App Store Connect API → Request Access**. Apple reviews requests. A missing button or pending approval is a human/account prerequisite, not a broken Windows installation. See [Apple's API access instructions](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/).
4. Choose key type and role with the account owner. Team keys have role-based access across the team's apps; individual keys inherit their user's app access and permissions. Do not default to Admin. Provisioning permissions must be checked separately from app-list access; a successful app read does not establish signing access. See [Apple's key creation instructions](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api) and [role permissions](https://developer.apple.com/support/roles/). The diagnostic records inaccessible provisioning endpoints without trying a broader key automatically.
5. Generate and download the chosen key through Apple's website. Private keys can be downloaded only once. Keep a secure backup outside the checkout; never paste the private key, passwords, 2FA codes or signing passwords into agent chat. Lost/compromised keys require deliberate revocation and replacement by the owner.

The current starter has one iPhone/iPad app target plus its test targets. Mac, Watch, TV and Vision targets remain later optional modules. The native configuration check rejects capability/entitlement additions until the corresponding setup is supported. Declaring an entitlement in Xcode does not grant Apple account approval; request-only capabilities need Apple's approval separately. Diagnostics do not enable capabilities or assume that a key can do so.

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

Our proposed starting role for read-only diagnostics is **Developer**, using an individual key for app-only access or a team key when provisioning reads are needed. For automatic distribution-asset preparation, **App Manager** is the candidate supported by the role matrix, subject to the discrepancy below. These are plans to verify with existing authorized access, not verified minimum API roles: Apple's endpoint references do not specify an exact minimum role for every inventory read, and no live key has been tested here. If that access is denied, stop and review the operation and account permissions; retain the existing key and present any revised role plan before credential setup.

For the later signing workflow, select a path before choosing new credentials:

| Planned step | Permission and verification gate |
| --- | --- |
| Archive with already prepared signing assets | Reuse an authorized distribution certificate **with its private key** and a matching valid profile. Local signing does not itself require an API key. Validate the archive on the hosted runner. |
| Automatic signing with provisioning updates | Use a team key for provisioning access. Xcode may create or update identifiers, certificates and profiles, so preview those intended changes first. An app-read or profile-list success does not verify creation permission. |
| Create distribution assets when needed | Check the intended key role against Apple's [role matrix](https://developer.apple.com/help/account/access/roles/). It permits App Manager with separately granted Certificates, Identifiers & Profiles access; Developer is insufficient for distribution-asset creation. The [certificate overview](https://developer.apple.com/help/account/certificates/certificates-overview/) and [distribution-profile guide](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile/) instead specify Account Holder or Admin. This documentation discrepancy remains unresolved by a live run. Treat App Manager as a candidate to verify, not a guaranteed signing credential, and require an explicit decision before using broader access. |
| Create an App Store Connect app record | Account Holder, Admin or App Manager, plus required agreements. This is separate from registering an App ID. |
| Upload to TestFlight (milestone 6) | Check upload permission separately when that workflow is implemented. A key accepted for diagnosis has not been verified for uploading. |

The narrower first choice is to reuse existing access and assets, with no new key during diagnosis. For organization users, Certificates, Identifiers & Profiles is separate access; users invited to an individual's App Store Connect account are not members of that person's Developer Program team. Human enrollment, API-access approval and agreements stay with the owner. Before credential entry, record the intended team, selected manifest/bundle ID, key type and role, whether each operation is a read or a change, and the chosen automatic/manual signing path. Never broaden, replace or revoke an existing key automatically. Issue #1's live signing-permission gate remains open until the chosen path is verified.

## App identity and Apple's defaults

The manifest's bundle identifier links the app to its Apple records. **Home Screen display name** (`INFOPLIST_KEY_CFBundleDisplayName`) and **App Store Connect record name** are separate. Apple's record-name availability rules can reject a name another developer uses without preventing that Home Screen name. If creation rejects a name, present an alternative for approval before retrying; do not change the app identifier or create duplicate records to work around the name. See [Apple's new-app instructions](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/).

Before creating a record, confirm the team, intended app access, platform, bundle ID, record name, primary language and SKU. The SKU is internal and cannot be changed after creation ([Apple app-information reference](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)). First inspect and reuse a matching existing record. Our demo uses the existing **Starter App Template Demo** record; its Home Screen name is **Starter App**. Template adopters edit `project.yml` with their own identity and use the `starter` selection; they should not register or sign our demo identifier.

**In-App Purchase is enabled by default for an explicit App ID**, and Apple's form disables a checkbox when a service is enabled by default ([Apple App ID registration](https://developer.apple.com/help/account/identifiers/register-an-app-id/)). A checked, disabled toggle is therefore expected; it does not mean this starter implements purchases or needs StoreKit code. Leave unrelated optional capabilities off. Account capabilities are an allowlist, separate from the project's requested capabilities and the actual signed entitlements. At signed-archive validation, inspect the generated signing settings, profile and signed app entitlements for consistency with the selected app and planned features. That evidence is still pending for issue #3; an unsigned simulator build cannot supply it.

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

Alternatively, run **Actions → Apple diagnostics → Run workflow**, choose **configuration** (`starter`, `pocket-notes`, or `starter-app-demo`), and leave account reads disabled. `starter` uses your current `project.yml`; the other choices use native example overrides. Its hosted Mac validates and exports that selection; the same run's export supplies the account job if later enabled. The configuration job summary shows the manifest, commit and resolved bundle identifier. Download `apple-project-diagnostics` for the report and `apple-configuration` for the export. Ordinary push/PR checks use no Apple secrets. The milestone 5 signed-archive workflow also requires one of these explicit selections and generates a fresh export from the selected manifest on its own run; it never uses a stale downloaded export.

## Optional authenticated reads

`apple-credentials` is a GitHub Actions environment for access to Apple API secrets. GitHub may show its jobs under “Deployments”; the diagnostic job reads account state and does not upload or publish an app.

Use an existing approved key when possible. Only configure credentials when you want account diagnostics; they are unnecessary for unsigned CI. For the GitHub path, create an environment named **apple-credentials**, restrict its deployment branches to exactly `main`, and choose an explicit required-reviewer policy before storing credentials. Do not store values until those protections have been verified. `scripts/bootstrap-apple-credentials.py` transfers a securely stored `.p8` file directly to GitHub Secrets over `gh` standard input. It checks the environment restrictions and existing secret names first, does not read secret values back, and refuses replacement unless explicitly requested. Keep the source file outside the checkout and do not put its contents into chat or command arguments. Pass the required `--approval-policy` option after configuring one of the policies below. The script verifies these settings; it does not change them, invite collaborators, enable authenticated reads, or change Apple account settings. Use `--help` for the remaining command syntax. This transfer works from Windows, macOS or Linux with Python and an authenticated GitHub CLI; Windows testing establishes portability rather than a requirement to perform setup there.

| Bootstrap option | Required environment policy |
| --- | --- |
| `--approval-policy independent` | One or more required reviewers; **Prevent self-review** enabled. A different eligible reviewer must approve the job. |
| `--approval-policy solo-owner` | Personal repository; its authenticated owner is the sole required reviewer; **Prevent self-review** disabled. The owner manually approves their own job. |

Both modes require exactly one branch rule for `main`. Solo-owner approval provides a deliberate manual checkpoint, without an independent second person. Choose it explicitly for a personal repository; do not configure a collaborator solely to satisfy the template. Organization repositories use independent approval. An agent must present the selected policy and intended Apple signing changes before credential setup.

### Collect the approval gates together

To avoid interrupting setup for predictable decisions, the agent should first inspect the current repository, team, app identity, existing key and assets, then present one concrete approval request covering the planned phases. Name the repository/environment policy and who will approve; the exact Apple team, existing app/bundle ID and key type/role; transfer of that existing key into the named GitHub environment; read-only diagnostics for the selected manifest; permission for the agent to approve the expected `apple-credentials` deployment gates for those specific runs; and, if signing is in scope, Xcode automatic signing and its possible profile/certificate changes. State what is expressly excluded, such as new app records, unrelated capability changes, revocation and TestFlight upload.

Do not ask for or accept passwords, 2FA codes, payment or agreement decisions. The account owner completes sign-in and those human-only steps. If the intended team, app, key, assets or effects are unknown, inspect first and ask only about the unresolved choice. A diagnostic approval covers read-only account requests; it does not authorize signing. A signing approval covers the named app and allowed automatic-signing effects; it does not authorize TestFlight. Each GitHub environment deployment is an actual approval action: only approve it when the owner explicitly included that workflow and effect in the authorization. Solo-owner approval is the repository owner's approval, not an independent review.

| Name | Value |
| --- | --- |
| `ASC_KEY_ID` | API key ID |
| `ASC_ISSUER_ID` | Issuer ID for a team key; omit for an individual key |
| `ASC_PRIVATE_KEY` | Complete downloaded `.p8` PEM contents, entered directly into GitHub Secrets |

In GitHub, use **Settings → Environments → apple-credentials → Environment secrets → Add secret**. See [GitHub's secret-entry instructions](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets#creating-secrets-for-an-environment) and [environment protections](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments).

Set environment **variable** `ASC_KEY_TYPE` to `team` or `individual`; do not use ordinary variables for private material. Protect `main` and review workflow changes: code allowed to run with secrets can access them. The account job is manually enabled, restricted to `main`, and separate from PR jobs. It performs no login, key creation, account mutation, archive, or upload.

Run **Apple diagnostics** on `main`, choose the intended configuration and enable its account checkbox only when ready for authenticated reads. Missing secrets produce a prominent **requested but skipped** warning and job summary. The headline distinguishes skipped, authentication-failed, inaccessible, incomplete and completed checks, with the number of successfully resolved record checks. A completed empty read still counts as a successful check, while its finding is `missing`; a profile check remains unverified if no accessible bundle ID was established. Green means the diagnostic ran, not that Apple setup is ready. The report includes only sanitized findings and counts. Do not upload raw CLI responses or credential files. Review artifact access before sharing a diagnostic, even though it excludes credentials and upstream account identifiers.

The **Signed archive validation** workflow runs a credential-free preflight on pushes and pull requests, using the demo manifest and fresh native Xcode configuration export. Its signing-validator fixtures check validation behavior; they do not establish a real signed archive. A manual dispatch also runs this preflight. Leave **perform_signing** unchecked for preflight only. Actual signing requires a dispatch from `main`, **perform_signing** explicitly enabled, approval through the `apple-credentials` environment, and one manifest choice with a configured team ID. It regenerates the project and configuration export on the hosted Xcode 27 runner. The same export is used for authenticated account diagnostics, team selection and archive validation. Before Xcode archive begins, accessible existing app and bundle-ID records must be verified. Archive signing uses automatic Xcode signing and an App Store Connect team API key; this may create or update a provisioning profile and may create a managed distribution certificate. It does not upload to TestFlight. Review and approve those intended Apple account changes before dispatching. Pull requests do not use this environment or receive signing secrets. The preflight uploads its public configuration export. The signing job uploads only the sanitized validation report; the private key and archive are removed from runner temporary storage. This initial automatic-signing path requires an App ID prefix matching the team ID. Legacy prefixes are rejected and need a separately reviewed manual-signing path; that alternative is not yet implemented.

For local Windows use, Python 3 and `curl.exe` are prerequisites; no Go toolchain is needed:

```powershell
python scripts/install-asc.py
python scripts/apple-doctor.py --configuration C:\Downloads\ios-test-results-starter\configuration.json --account --asc build\tools\asc.exe
```

Supply the same credential environment fields through your secure local environment/secret tooling, or use `ASC_PRIVATE_KEY_PATH` pointing to an existing securely stored file outside the checkout instead of `ASC_PRIVATE_KEY`. Do not type literal secrets into shell commands or transcripts. Local file access restrictions and Windows ACLs remain your responsibility; this milestone does not install a Windows credential vault. Individual keys omit the issuer ID. The wrapper isolates CLI configuration, bypasses stored Keychain/config profiles, disables telemetry/debug settings and uses only the explicitly supplied environment credential fields. It does not persist a credential profile. Temporary key material created by the CLI is confined to the wrapper's temporary directory, which the wrapper removes after reads or a child timeout. Hard termination of the wrapper itself can still interrupt cleanup. Prefer the short-lived hosted runner for account checks until persistent credential handling is implemented in milestone 5.

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

The wrapper reads app records filtered by the configured bundle ID, matching registered bundle IDs, distribution-certificate inventory, and profiles linked to an accessible bundle ID. Certificate inventory is team-wide. Existing certificates may be expired or lack a locally available private key; linked profiles may be expired, invalid or wrong for distribution. Those validations belong to milestone 5. Membership, agreement acceptance, capability approval, signed archives and device delivery are explicitly unverified here.

The CLI emits human-readable errors which do not always include an HTTP status/code. The wrapper conservatively classifies recognizable denied/authentication language and leaves other errors unverified; a 403 or 404 must never be treated as an empty successful list. A later CLI version with structured errors could improve specificity.

## Reviewed CLI dependency

The template uses [App-Store-Connect-CLI 5.14.0](https://github.com/rorkai/App-Store-Connect-CLI/releases/tag/5.14.0) as a subprocess, downloaded only when requested. `scripts/install-asc.py` pins published SHA-256 values and checks bytes before saving a binary. It executes no remote installer and changes no global PATH. Its native Windows release is amd64; Windows ARM has no reviewed native asset in this pin. Linux and macOS support amd64/arm64. TLS verification stays enabled.

The upstream CLI is MIT licensed; see [the upstream license](https://github.com/rorkai/App-Store-Connect-CLI/blob/5.14.0/LICENSE). This template does not vendor its source or redistribute release binaries. Its module path retains the original `rudrankriyam` owner even though the release repository is `rorkai`; that is not a reason to build the ignored reference checkout.

Upstream telemetry defaults to enabled. The integration sets `ASC_TELEMETRY_DISABLED=1` and `DO_NOT_TRACK=1` without changing a user's preferences. The wrapper uses only `apps list`, `bundle-ids list`, `certificates list`, and `bundle-ids profiles list`, with JSON and pagination. Do not replace these with `auth login`, `auth doctor --fix`, web-session login, token output or arbitrary agent-generated CLI strings. Those commands have different effects and exposure risks.

CI tests permission failures, incomplete credentials, malformed responses, timeouts and secret-canary redaction using fixtures. Native CLI help/version runs establish executable/flag availability on each platform. **A fixture pass is not a real Apple account check:** no live account credentials were supplied during template development. Use the opt-in workflow to establish findings for your account before milestone 5.
