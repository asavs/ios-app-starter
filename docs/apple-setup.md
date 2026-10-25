# Set up Apple access and signing

This guide covers what signing and TestFlight need from Apple: the account, the API access each operation needs, and the diagnostics to run before you change anything. Building and testing need no Apple account, and hosted builds run Xcode on GitHub Actions, so you do not need to manage a Mac.

## Human prerequisites

1. Check whether you already have an active [Apple Developer Program membership](https://developer.apple.com/programs/enroll/). Choose individual or organization enrollment deliberately: Apple verifies identity, and an organization also needs legal authority and organization details. Enrollment includes payment unless a waiver applies. A failed API check is not a reason to create a second membership.
2. Sign in to [App Store Connect](https://appstoreconnect.apple.com/) and confirm the intended team and your role. The Account Holder reviews membership status and outstanding agreements; the diagnostics do not check contractual prerequisites.
3. The Account Holder requests API access under **Users and Access → Integrations → App Store Connect API → Request Access**, and Apple reviews each request. A missing button or pending approval means a human step is needed, not that the Windows installation is broken. See [Apple's API access instructions](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/).
4. Choose the key type and role with the account owner. A team key has role-based access to all of the team's apps; an individual key inherits its user's app access and permissions. Do not default to Admin. A successful app read does not show signing access, so check provisioning permissions separately. See [Apple's key creation instructions](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api) and [role permissions](https://developer.apple.com/support/roles/). When provisioning endpoints are inaccessible, the diagnostic records that and does not try a broader key.
5. Generate and download the key on Apple's website. Apple allows only one download, so keep a secure backup outside the checkout. Never paste the private key, passwords, 2FA codes or signing passwords into agent chat. If a key is lost or compromised, the owner revokes and replaces it deliberately.

The starter has one iPhone/iPad app target plus test targets; Mac, Watch, TV and Vision targets are planned. The native configuration check rejects added capabilities or entitlements until the template supports their setup. Declaring an entitlement in Xcode does not get Apple's approval for a request-only capability. Diagnostics do not enable capabilities and do not assume a key can.

A computer-use agent can explain pages, navigate, read visible account state, diagnose missing permissions and prepare a plan. The human handles identity verification, passwords and 2FA, payment and agreements. Key creation, permission changes and other account changes each need their own authorized plan; agreeing to diagnostics does not authorize them. Keep private-key contents out of screenshots and logs. The template has no Apple browser automation or MCP dependency.

## Choose access for the operation

Apple excludes **individual API keys** from provisioning endpoints, even when the key's user has an elevated role. A **team key** can use them within its role and covers all team apps. The role of the person who creates a key and the role assigned to the key are separate decisions. See [Apple's key-type restrictions](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api).

The pinned wrapper runs these commands with `--paginate --output json`. The table shows the access each needs; it does not certify what an untested key can do.

| Operation | Access plan |
| --- | --- |
| `apps list --bundle-id <exported ID>` | App-read access. An individual key covers its user's selected apps; a team key covers all apps. Reuse existing permitted access. |
| `bundle-ids list --identifier <exported ID>` | Provisioning endpoint: team key with permission to read registered identifiers. |
| `certificates list --certificate-type DISTRIBUTION,IOS_DISTRIBUTION --fields certificateType,expirationDate` | Provisioning endpoint: team key with certificate inventory access. Team-wide; does not retrieve the signing private key. |
| `bundle-ids profiles list --id <accessible resource ID>` | Provisioning endpoint: team key with profile-read access. Runs only when a matching bundle ID resource is accessible. |

Apple's [Bundle IDs](https://developer.apple.com/documentation/appstoreconnectapi/bundle-ids), [Certificates](https://developer.apple.com/documentation/appstoreconnectapi/certificates), and [Profiles](https://developer.apple.com/documentation/appstoreconnectapi/profiles) references describe these resources. App reads can succeed while provisioning reads are denied; leave those findings unknown. Do not create duplicate identifiers or request a broader key to turn the report green.

For read-only diagnostics, start with the least-privilege **Developer** role. An individual key can run the app-record read for its user's selected apps; the provisioning reads need a team key. Apple does not document the minimum team-key role for each inventory endpoint, so verify those reads with existing authorized access. A denied read stays unknown and is not a reason to broaden a key.

For hosted automatic signing, where Xcode may create or refresh distribution assets, use a **team API key with the Admin role**. The workflow passes it to `xcodebuild` with `-allowProvisioningUpdates`. Apple names Account Holder or Admin for creating the distribution certificate and App Store profile, and Admin is the least privileged team-key role among those. If a valid certificate with its private key and a matching profile already exist, and the signing path can reuse them without provisioning updates, use that path and give no key broader access.

The demo repository's team key has the **Admin** role, confirmed separately from the secret metadata and reused for the protected signing run. Confirm and record your own key's role. Never create, replace, elevate or revoke a key automatically.

Choose a signing path before choosing new credentials:

| Step | Permission and verification needed |
| --- | --- |
| Archive with already prepared signing assets | Reuse an authorized distribution certificate **with its private key** and a matching valid profile. Local signing needs no API key. Validate the archive on the hosted runner. |
| Automatic signing with provisioning updates (creates or refreshes distribution assets) | Team key with **Admin** role, through the supported hosted Xcode workflow. Xcode may create or update identifiers, certificates and profiles, so preview those changes first. Apple documents Account Holder or Admin for creating distribution certificates and App Store profiles; the role matrix's separate Certificates, Identifiers & Profiles access does not prove App Manager can make these writes. An app-read or profile-list success does not verify creation permission. |
| Create an App Store Connect app record | Account Holder, Admin or App Manager, plus required agreements. This is separate from registering an App ID. |
| Upload to TestFlight | Check upload permission separately before using the delivery workflow. A key accepted for diagnosis is not verified for upload. |

Start with existing access and assets, and create no new key during diagnosis. In an organization, Certificates, Identifiers & Profiles access is granted separately. Users invited to an individual's App Store Connect account are not members of that person's Developer Program team. Enrollment, API-access approval and agreements stay with the owner.

Before anyone enters credentials, record the intended team, the selected manifest and bundle ID, the key type and role, whether each operation reads or changes something, and whether signing is automatic or manual. Passing diagnostics do not prove signing permissions; verify them for the chosen path.

## App identity and Apple's defaults

The manifest's bundle identifier links the app to its Apple records. The **Home Screen display name** (`INFOPLIST_KEY_CFBundleDisplayName`) and the **App Store Connect record name** are separate: Apple can reject a record name another developer already uses, and you can still use that name on the Home Screen. If a name is rejected, propose another for approval before retrying. Do not change the app identifier or create duplicate records to get around it. See [Apple's new-app instructions](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/).

Before creating a record, confirm the team, intended app access, platform, bundle ID, record name, primary language and SKU. The SKU is internal and cannot be changed later ([Apple app-information reference](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)). Reuse a matching record if one exists. The demo uses the existing **Starter App Template Demo** record, with the Home Screen name **Starter App**. If you adopt the template, put your own identity in `project.yml` and use the `starter` selection. Do not register or sign the demo identifier.

**In-App Purchase is enabled by default for an explicit App ID**, so Apple's form shows it as a checked, disabled toggle ([Apple App ID registration](https://developer.apple.com/help/account/identifiers/register-an-app-id/)). The starter has no purchases or StoreKit code. Leave unrelated optional capabilities off.

Account capabilities are an allowlist, separate from the capabilities the project requests and the entitlements the app is signed with. During signed-archive validation, check that the generated signing settings, profile and signed entitlements match the selected app and its planned features. An unsigned simulator build cannot show this.

## Run diagnostics without credentials

This needs only Python 3, on Windows, Linux or macOS; no Xcode, CLI, key or Apple account:

```powershell
python scripts/apple-doctor.py
```

It writes `build/apple-diagnostics/report.md` and `report.json`, with missing prerequisites listed as findings and next actions. A successful exit means the diagnostic completed, **not** that signing or TestFlight is ready. It exits with an error on malformed configuration input or if it cannot write the report.

For project findings, run the **iOS** workflow, download `ios-test-results-starter` from its run page, extract it outside the repository and pass its `configuration.json`:

```powershell
python scripts/apple-doctor.py --configuration C:\Downloads\ios-test-results-starter\configuration.json
```

The export holds Xcode's resolved Debug and Release settings; the script only reads it and does not run Xcode. Check that the run's commit matches your current `project.yml`, because an old export does not verify your changes. A minimum of iOS 17 in the export does not prove a test ran on iOS 17.

Alternatively, run **Actions → Apple diagnostics → Run workflow**, choose **configuration** (`starter`, `pocket-notes`, or `starter-app-demo`), and leave account reads disabled. `starter` uses your current `project.yml`; the others use native example overrides. The hosted Mac validates and exports the selection, and account reads, if enabled, use that same export.

The job summary shows the manifest, commit and resolved bundle identifier. Download `apple-project-diagnostics` for the report and `apple-configuration` for the export. Ordinary push and PR checks use no Apple secrets. The signed-archive workflow also takes an explicit selection and generates a fresh export from it on every run, never a downloaded one.

## Optional authenticated reads

`apple-credentials` is a GitHub Actions environment that holds the Apple API secrets. GitHub may list its jobs under "Deployments"; the diagnostic job only reads account state and does not upload or publish an app.

Unsigned CI needs no credentials; set them up when you need account diagnostics or signing, and reuse an approved key when you can. Create an environment named **apple-credentials** with deployment branches restricted to exactly `main`, and verify that rule before you store any values. The documented setup has no required reviewer; you can add one in GitHub environment settings.

`scripts/bootstrap-apple-credentials.py` sends a securely stored `.p8` file straight to GitHub Secrets through `gh` standard input. It first checks the environment restrictions and existing secret names, never reads secret values back, and replaces a secret only when you explicitly ask. Keep the source file outside the checkout, and never put its contents into chat or command arguments.

`--approval-policy` defaults to `none`; select `independent` or `solo-owner` only if that reviewer policy is configured. The script checks settings but does not change them, invite collaborators, enable authenticated reads or change Apple account settings. It needs Python and a signed-in GitHub CLI, and runs on Windows, macOS and Linux. Run `--help` for the rest of the syntax.

| Bootstrap option | Required environment policy |
| --- | --- |
| `--approval-policy none` (default) | No required reviewers; exactly one deployment branch rule for `main`. |
| `--approval-policy independent` | One or more required reviewers; **Prevent self-review** enabled. A different eligible reviewer must approve the job. |
| `--approval-policy solo-owner` | Personal repository; its authenticated owner is the sole required reviewer; **Prevent self-review** disabled. The owner approves their own job. |

Every mode requires exactly one branch rule for `main`; the reviewer policies add a deployment approval step. Solo-owner approval is a deliberate manual checkpoint with no second person: choose it explicitly for a personal repository, and do not add a collaborator only to satisfy the template. Organization repositories that want a reviewer step should use independent approval. Before credential setup, an agent must present the selected policy and the intended Apple signing changes.

### Collect the approval gates together

To avoid interrupting setup for predictable decisions, the agent first inspects the repository, team, app identity, existing key and assets, then presents one concrete approval request covering the planned phases. The request names:

- the repository and environment policy, and any optional reviewer;
- the exact Apple team, the existing app and bundle ID, and the key type and role;
- the transfer of that existing key into the named GitHub environment;
- read-only diagnostics for the selected manifest;
- if signing is in scope, Xcode automatic signing and the profile and certificate changes it may make.

It also states what is excluded, such as new app records, unrelated capability changes, revocation and TestFlight upload.

Do not ask for or accept passwords, 2FA codes, payment or agreement decisions; the account owner does the sign-in and those steps. If the team, app, key, assets or effects are unknown, inspect first and ask only about the choice still open. Approval for diagnostics covers read-only account requests, not signing. Approval for signing covers the named app and the allowed automatic-signing effects, not TestFlight. When a reviewer policy is on, approve an environment deployment only if the owner explicitly included that workflow and effect. Solo-owner approval is the repository owner's own approval, not an independent review.

### Store the key and run the reads

Add these as environment secrets under **Settings → Environments → apple-credentials → Environment secrets → Add secret** (see [GitHub's secret-entry instructions](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets#creating-secrets-for-an-environment) and [environment protections](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)):

| Name | Value |
| --- | --- |
| `ASC_KEY_ID` | API key ID |
| `ASC_ISSUER_ID` | Issuer ID for a team key; omit for an individual key |
| `ASC_PRIVATE_KEY` | Complete downloaded `.p8` PEM contents, entered directly into GitHub Secrets |

Set the environment **variable** `ASC_KEY_TYPE` to `team` or `individual`. Never put private material in ordinary variables. Protect `main` and review workflow changes, because any code allowed to run with the secrets can read them. The account job runs only when manually enabled, only on `main`, and apart from PR jobs. It does no login, key creation, account change, archive or upload.

Run **Apple diagnostics** on `main`, choose the configuration, and tick its account checkbox only when you are ready for authenticated reads. If secrets are missing, the run shows a **requested but skipped** warning and job summary. The headline separates skipped, authentication-failed, inaccessible, incomplete and completed checks, and counts the record checks that resolved. A completed empty read is a successful check whose finding is `missing`. A profile check stays unverified if no accessible bundle ID was found. Green means the diagnostic ran, not that Apple setup is ready. The report holds only sanitized findings and counts, without credentials or upstream account identifiers; still review who can access the artifact before you share it. Do not upload raw CLI responses or credential files.

### Signed archive validation

The **Signed archive validation** workflow runs a credential-free preflight for pull requests and manual dispatches, using the demo manifest and a fresh native Xcode configuration export. Its signing-validator fixtures test the validator and do not produce a real signed archive. Leave **perform_signing** unchecked to run only the preflight.

Real signing needs a dispatch from `main`, **perform_signing** explicitly enabled, and one manifest choice with a configured team ID. Pull requests do not use the `apple-credentials` environment or receive signing secrets.

On the hosted Xcode 27 runner, the workflow regenerates the project and the configuration export; that one export feeds account diagnostics, team selection and archive validation. The existing app and bundle-ID records must be verified as accessible before Xcode starts the archive. The workflow builds an unsigned archive, then has Xcode export an App Store Connect distribution package with automatic signing and `destination=export`. It does not upload the package.

Xcode may create or update the app's distribution provisioning profile and may create a distribution certificate; review and approve those Apple account changes before you dispatch. The workflow checks the exported app against the archive and the fresh manifest for identity, signature, entitlements, profile and certificate match, and expiry.

Preflight uploads the public configuration export. The signing job uploads only the sanitized validation report, and removes the private key, archive and exported package from the runner's temporary storage. TestFlight uses a reviewed, checked-in `ExportOptions.plist` policy at [config/ExportOptions-TestFlight.plist](../config/ExportOptions-TestFlight.plist).

Automatic signing needs an App ID prefix that matches the team ID. The workflow rejects legacy prefixes, which would need a separately reviewed manual-signing path that is not implemented.

### Run account reads locally

On Windows, the prerequisites are Python 3 and `curl.exe`; no Go toolchain is needed:

```powershell
python scripts/install-asc.py
python scripts/apple-doctor.py --configuration C:\Downloads\ios-test-results-starter\configuration.json --account --asc build\tools\asc.exe
```

Supply the same credential fields through your secure local environment or secret tooling. Instead of `ASC_PRIVATE_KEY`, you can set `ASC_PRIVATE_KEY_PATH` to an existing securely stored file outside the checkout. Do not type literal secrets into shell commands or transcripts. Local file access restrictions and Windows ACLs are your responsibility; these tools install no Windows credential vault.

The wrapper isolates the CLI configuration, skips stored Keychain and config profiles, turns off telemetry and debug settings, uses only the credential fields supplied in the environment, and saves no credential profile. It removes temporary key material after the reads or after a child process times out, but cleanup can be interrupted if the wrapper itself is killed. Prefer the short-lived hosted runner for account checks, using the bootstrap script above to move credentials to GitHub.

## Interpret the report

| Status | Meaning |
| --- | --- |
| `reported` | An exported configuration was inspected; verify its provenance and freshness. |
| `configured` | Required fields are supplied; this does not establish validity. |
| `placeholder` | The app still uses a `com.example.*` identifier. |
| `present` | A completed read found accessible records. This does not prove they are usable. |
| `missing` | A completed, paginated read returned no accessible matching records. Check the team and permissions before creating anything. |
| `inaccessible` | The CLI reported recognizable denied-access language. Whether records exist is unknown. |
| `authentication_failed` | The CLI reported recognizable authentication failure language. |
| `not_configured` | Complete explicit environment credentials were not supplied. |
| `not_verified` | The check was skipped or could not establish a result. |

The wrapper reads app records filtered by the configured bundle ID, matching registered bundle IDs, the team-wide distribution-certificate inventory, and profiles linked to an accessible bundle ID. A certificate it finds may be expired or have no private key available locally; a profile may be expired, invalid or wrong for distribution. Signed-archive validation checks these separately. Diagnostics do not verify membership, agreement acceptance, capability approval, signed archives or device delivery.

The CLI's errors are human-readable and do not always include an HTTP status or code, so the wrapper classifies only recognizable denied-access and authentication messages and leaves other errors unverified. Never treat a 403 or 404 as an empty successful list.

## Reviewed CLI dependency

The template runs [App-Store-Connect-CLI 5.14.0](https://github.com/rorkai/App-Store-Connect-CLI/releases/tag/5.14.0) as a subprocess and downloads it only when asked. `scripts/install-asc.py` pins the published SHA-256 values and checks the bytes before saving a binary. It runs no remote installer, keeps TLS verification on and does not change the global PATH. The pinned native binaries are Windows amd64 and Linux and macOS amd64/arm64; Windows ARM has no reviewed native asset.

The upstream CLI is MIT licensed ([the upstream license](https://github.com/rorkai/App-Store-Connect-CLI/blob/5.14.0/LICENSE)). The template neither vendors its source nor redistributes release binaries. Its module path keeps the original `rudrankriyam` owner although the release repository is `rorkai`; that mismatch is not a reason to build the ignored reference checkout.

Upstream telemetry is on by default; the integration sets `ASC_TELEMETRY_DISABLED=1` and `DO_NOT_TRACK=1` for its own runs without changing the user's preferences. The wrapper uses only `apps list`, `bundle-ids list`, `certificates list`, and `bundle-ids profiles list`, with JSON and pagination. Do not replace these with `auth login`, `auth doctor --fix`, web-session login, token output or arbitrary agent-generated CLI strings, which have other effects and exposure risks.

CI uses fixtures to test permission failures, incomplete credentials, malformed responses, timeouts and secret-canary redaction, and runs native CLI help and version on each platform to check that the executable and flags exist. **A fixture pass is not a real Apple account check.** Run the opt-in workflow for findings on your account before signing; the demo's signing result says nothing about another account.

## Continue to TestFlight

The demo's signing evidence is in the [roadmap](../roadmap.md), and the [archived Windows handoff](archive/windows-milestone-6-handoff.md) records the original acceptance steps. To upload your app, obtain explicit TestFlight authorization and follow [the delivery guide](testflight-delivery.md).

Signing and key approvals already given still stand; do not ask again unless the plan changes. Check upload permission separately. The Account Holder handles agreements and compliance decisions. Release app and build reads go through fixed commands in `scripts/testflight-release.py`, using the same pinned CLI and isolated reader. They require an explicit `--account` and never forward raw account output. Code and fixture tests alone do not show live account access or a successful upload.
