# Set up Apple access and signing

Use this guide to sign your app or prepare it for TestFlight. Check the Apple account, choose the access each operation needs, and run diagnostics before you change anything. You can build and test the app without an Apple account. For hosted builds, GitHub Actions runs Xcode, so you do not need to manage a Mac.

## Human prerequisites

1. Check whether you already have an active [Apple Developer Program membership](https://developer.apple.com/programs/enroll/). Decide between individual and organization enrollment on purpose. Apple requires identity verification, and organizations also need legal authority and organization information. Enrollment includes payment unless a waiver applies. A failed API check is not a reason to create a second membership.
2. Sign in to [App Store Connect](https://appstoreconnect.apple.com/) and confirm the intended team and your role. Have the Account Holder review membership status and outstanding agreements. These diagnostics do not check that all contractual prerequisites are met.
3. The Account Holder requests API access under **Users and Access → Integrations → App Store Connect API → Request Access**. Apple reviews each request. If the button is missing or approval is pending, the account needs a human step; the Windows installation is not broken. See [Apple's API access instructions](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/).
4. Choose the key type and role with the account owner. Team keys have role-based access to all of the team's apps. Individual keys inherit their user's app access and permissions. Do not default to Admin. Check provisioning permissions separately from app-list access: a successful app read does not show signing access. See [Apple's key creation instructions](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api) and [role permissions](https://developer.apple.com/support/roles/). When provisioning endpoints are inaccessible, the diagnostic records that and does not try a broader key.
5. Generate and download the chosen key through Apple's website. Apple lets you download a private key only once. Keep a secure backup outside the checkout. Never paste the private key, passwords, 2FA codes or signing passwords into agent chat. If a key is lost or compromised, the owner revokes and replaces it deliberately.

The starter has one iPhone/iPad app target plus its test targets. Mac, Watch, TV and Vision targets are planned options. The native configuration check rejects added capabilities or entitlements until the template supports their setup. Declaring an entitlement in Xcode does not get Apple account approval; request-only capabilities need Apple's approval separately. Diagnostics do not enable capabilities and do not assume a key can.

A computer-use agent can explain the pages, navigate, inspect visible account state, diagnose missing permissions and prepare a concrete plan. The human handles identity verification, passwords and 2FA, payment and agreement decisions. Key creation, permission changes and other account changes each need a specific authorized plan; agreeing to diagnostics does not authorize them. Keep private-key contents out of screenshots and logs. This template has no Apple browser automation or MCP dependency.

## Choose access for the operation

Apple excludes provisioning endpoints from **individual API keys**, even when the key's user has an elevated role. A **team key** can use those endpoints, limited by its role, and covers all team apps. The role of the person who creates a key and the role assigned to the key are separate decisions. See [Apple's key-type restrictions](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api).

The pinned wrapper runs these commands with `--paginate --output json`. The table shows the access each one needs. It does not certify what an untested key can do.

| Operation | Access plan |
| --- | --- |
| `apps list --bundle-id <exported ID>` | App Store Connect app-read access. An individual key inherits the user's selected apps; a team key covers all apps. Reuse existing permitted access. |
| `bundle-ids list --identifier <exported ID>` | Provisioning endpoint: team key and permission to read registered identifiers. |
| `certificates list --certificate-type DISTRIBUTION,IOS_DISTRIBUTION --fields certificateType,expirationDate` | Provisioning endpoint: team key and certificate inventory access. This team-wide read does not retrieve the signing private key. |
| `bundle-ids profiles list --id <accessible resource ID>` | Provisioning endpoint: team key and profile-read access. Runs only when a matching bundle ID resource is accessible. |

These provisioning resources are described in Apple's [Bundle IDs](https://developer.apple.com/documentation/appstoreconnectapi/bundle-ids), [Certificates](https://developer.apple.com/documentation/appstoreconnectapi/certificates), and [Profiles](https://developer.apple.com/documentation/appstoreconnectapi/profiles) references. App reads can succeed while provisioning reads are denied. Leave those findings unknown. Do not create duplicate identifiers or request a broader key just to turn the report green.

For read-only diagnostics, start with the least-privilege **Developer** role. An individual key is limited to the user's selected apps and can run the app-record read. The full diagnostic also reads provisioning resources, so it needs a team key. Apple documents that individual keys cannot use provisioning endpoints, but does not give the minimum team-key role for each inventory endpoint. Verify those reads with existing authorized access. A denied read stays unknown and is not a reason to broaden a key automatically.

For the hosted automatic-signing workflow, use a **team API key with the Admin role** when Xcode is allowed to create or refresh distribution assets. The workflow passes that key to `xcodebuild` with `-allowProvisioningUpdates`. Apple's certificate overview and App Store profile guide both name Account Holder or Admin for creating the distribution certificate and profile, and Admin is the least privileged team-key role among those options. A team key also covers every team app. If a valid certificate with its private key and a matching profile are already prepared, and the selected signing path can reuse them without provisioning updates, use that narrower path and do not give an API key broader access.

The acceptance repository's stored team key has the **Admin** role. The role was confirmed separately from the secret metadata, and the key was reused for the protected signing run. This page records no key identifier or private-key material. Template adopters must confirm and record their own role. Never create, replace, elevate or revoke a key automatically.

Choose a signing path before choosing new credentials:

| Step | Permission and verification needed |
| --- | --- |
| Archive with already prepared signing assets | Reuse an authorized distribution certificate **with its private key** and a matching valid profile. Local signing does not itself require an API key. Validate the archive on the hosted runner. |
| Automatic signing with provisioning updates | Use a team key with **Admin** role for the supported hosted workflow. Xcode may create or update identifiers, certificates and profiles, so preview those intended changes first. An app-read or profile-list success does not verify creation permission. |
| Create or refresh distribution assets through the supported Xcode automatic-signing workflow | Apple documents Account Holder or Admin for creating distribution certificates and App Store profiles; Admin is the available team-key role with the documented permission. Do not treat the role matrix's separate Certificates, Identifiers & Profiles access as proof that App Manager can perform these specific writes. If assets can be reused without provisioning updates, choose that path and avoid this broader permission. |
| Create an App Store Connect app record | Account Holder, Admin or App Manager, plus required agreements. This is separate from registering an App ID. |
| Upload to TestFlight | Check upload permission separately before using the delivery workflow. A key accepted for diagnosis has not been verified for uploading. |

Start with existing access and assets, and create no new key during diagnosis. For organization users, Certificates, Identifiers & Profiles access is granted separately. Users invited to an individual's App Store Connect account are not members of that person's Developer Program team. Enrollment, API-access approval and agreements stay with the owner.

Before anyone enters credentials, record the intended team, the selected manifest and bundle ID, the key type and role, whether each operation reads or changes something, and whether signing is automatic or manual. Never broaden, replace or revoke an existing key automatically. Verify signing permissions for the chosen path; passing diagnostics do not prove them.

## App identity and Apple's defaults

The manifest's bundle identifier links the app to its Apple records. The **Home Screen display name** (`INFOPLIST_KEY_CFBundleDisplayName`) and the **App Store Connect record name** are separate. Apple can reject a record name that another developer already uses, and that does not stop you using the same Home Screen name. If creation rejects a name, propose another one for approval before retrying. Do not change the app identifier or create duplicate records to get around the name. See [Apple's new-app instructions](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/).

Before creating a record, confirm the team, intended app access, platform, bundle ID, record name, primary language and SKU. The SKU is internal and cannot be changed after creation ([Apple app-information reference](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)). Look for a matching record first and reuse it. Our demo uses the existing **Starter App Template Demo** record, with the Home Screen name **Starter App**. If you adopt the template, put your own identity in `project.yml` and use the `starter` selection. Do not register or sign our demo identifier.

**In-App Purchase is enabled by default for an explicit App ID**, and Apple's form disables a checkbox when a service is enabled by default ([Apple App ID registration](https://developer.apple.com/help/account/identifiers/register-an-app-id/)). Expect a checked, disabled toggle. The starter does not implement purchases or need StoreKit code. Leave unrelated optional capabilities off.

Account capabilities are an allowlist. They are separate from the capabilities the project requests and the entitlements the app is signed with. During signed-archive validation, check that the generated signing settings, profile and signed app entitlements match the selected app and its planned features. An unsigned simulator build cannot show this.

## Run diagnostics without credentials

The command needs Python 3 and runs on Windows, Linux and macOS. It does not need Xcode, the CLI, a key or an Apple account:

```powershell
python scripts/apple-doctor.py
```

It writes `build/apple-diagnostics/report.md` and `report.json`. A successful exit means the diagnostic completed, **not** that signing or TestFlight is ready. Missing prerequisites show up as findings with next actions. The command exits with an error on malformed configuration input or if it cannot write the report.

For project findings, run the **iOS** workflow and download `ios-test-results-starter` from its run page. Extract it outside the repository and use its `configuration.json`:

```powershell
python scripts/apple-doctor.py --configuration C:\Downloads\ios-test-results-starter\configuration.json
```

Check that the run's commit matches your current `project.yml`. The export holds Xcode's resolved Debug and Release settings. The script reads that report; it does not run Xcode or add another configuration format on Windows. An old export does not verify your current changes. A minimum of iOS 17 in the export does not prove a test ran on iOS 17.

Alternatively, run **Actions → Apple diagnostics → Run workflow**, choose **configuration** (`starter`, `pocket-notes`, or `starter-app-demo`), and leave account reads disabled. `starter` uses your current `project.yml`; the other choices use native example overrides. The hosted Mac validates and exports the selection. Account reads, if enabled, use the same run's export.

The configuration job summary shows the manifest, commit and resolved bundle identifier. Download `apple-project-diagnostics` for the report and `apple-configuration` for the export. Ordinary push and PR checks use no Apple secrets. The signed-archive workflow also needs an explicit selection and generates a fresh export from it on every run. It never uses a stale downloaded export.

## Optional authenticated reads

`apple-credentials` is a GitHub Actions environment that holds the Apple API secrets. GitHub may list its jobs under "Deployments". The diagnostic job only reads account state; it does not upload or publish an app.

Reuse an approved key when you can. Unsigned CI needs no credentials; set them up when you need account diagnostics or signing. For the GitHub path, create an environment named **apple-credentials** with deployment branches restricted to exactly `main`. The documented setup has no required reviewer; you can add one in GitHub environment settings. Verify the main-only rule before you store any values.

`scripts/bootstrap-apple-credentials.py` sends a securely stored `.p8` file straight to GitHub Secrets through `gh` standard input. It checks the environment restrictions and existing secret names first. It never reads secret values back, and it refuses to replace a secret unless you explicitly ask it to. Keep the source file outside the checkout. Never put its contents into chat or command arguments.

The script's `--approval-policy` defaults to `none`. Select `independent` or `solo-owner` only if that reviewer policy is configured. The script checks settings. It does not change them, invite collaborators, enable authenticated reads or change Apple account settings. Run `--help` for the rest of the syntax. The transfer works on Windows, macOS and Linux with Python and a signed-in GitHub CLI. It is tested on Windows to confirm portability, but you can run setup anywhere.

| Bootstrap option | Required environment policy |
| --- | --- |
| `--approval-policy none` (default) | No required reviewers; exactly one deployment branch rule for `main`. |
| `--approval-policy independent` | One or more required reviewers; **Prevent self-review** enabled. A different eligible reviewer must approve the job. |
| `--approval-policy solo-owner` | Personal repository; its authenticated owner is the sole required reviewer; **Prevent self-review** disabled. The owner manually approves their own job. |

Every mode requires exactly one branch rule for `main`. The reviewer policies add a deployment approval step; the default `none` mode does not. Solo-owner approval is a deliberate manual checkpoint with no second person. Choose it explicitly for a personal repository, and do not add a collaborator only to satisfy the template. Organization repositories that want a reviewer step should use independent approval. Before credential setup, an agent must present the selected policy and the intended Apple signing changes.

### Collect the approval gates together

So that setup is not interrupted for predictable decisions, the agent first inspects the current repository, team, app identity, existing key and assets. It then presents one concrete approval request that covers the planned phases. The request names:

- the repository and environment policy, and any optional reviewer;
- the exact Apple team, the existing app and bundle ID, and the key type and role;
- the transfer of that existing key into the named GitHub environment;
- read-only diagnostics for the selected manifest;
- if signing is in scope, Xcode automatic signing and the profile and certificate changes it may make.

It also states what is excluded, such as new app records, unrelated capability changes, revocation and TestFlight upload.

Do not ask for or accept passwords, 2FA codes, payment or agreement decisions. The account owner does the sign-in and those human-only steps. If the intended team, app, key, assets or effects are unknown, inspect first and ask only about the choice that is still open. Approval for diagnostics covers read-only account requests and does not cover signing. Approval for signing covers the named app and the allowed automatic-signing effects and does not cover TestFlight. When a reviewer policy is on, approve an environment deployment only if the owner explicitly included that workflow and effect in the approval. Solo-owner approval is the repository owner's own approval, not an independent review.

| Name | Value |
| --- | --- |
| `ASC_KEY_ID` | API key ID |
| `ASC_ISSUER_ID` | Issuer ID for a team key; omit for an individual key |
| `ASC_PRIVATE_KEY` | Complete downloaded `.p8` PEM contents, entered directly into GitHub Secrets |

In GitHub, use **Settings → Environments → apple-credentials → Environment secrets → Add secret**. See [GitHub's secret-entry instructions](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets#creating-secrets-for-an-environment) and [environment protections](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments).

Set the environment **variable** `ASC_KEY_TYPE` to `team` or `individual`. Never put private material in ordinary variables. Protect `main` and review workflow changes, because any code allowed to run with the secrets can read them. The account job runs only when manually enabled, only on `main`, and apart from PR jobs. It does no login, key creation, account change, archive or upload.

Run **Apple diagnostics** on `main`, choose the intended configuration, and tick its account checkbox only when you are ready for authenticated reads. If secrets are missing, the run shows a **requested but skipped** warning and job summary. The headline separates skipped, authentication-failed, inaccessible, incomplete and completed checks, and gives the number of record checks that resolved. A completed empty read counts as a successful check, and its finding is `missing`. A profile check stays unverified if no accessible bundle ID was found. Green means the diagnostic ran, not that Apple setup is ready. The report holds only sanitized findings and counts. Do not upload raw CLI responses or credential files. The report leaves out credentials and upstream account identifiers, but still review who can access the artifact before you share it.

The **Signed archive validation** workflow runs a credential-free preflight for pull requests and manual dispatches. It uses the demo manifest and a fresh native Xcode configuration export. Its signing-validator fixtures test the validator's behavior and do not produce a real signed archive. Leave **perform_signing** unchecked to run only the preflight.

Real signing needs a dispatch from `main`, **perform_signing** explicitly enabled, and one manifest choice with a configured team ID. The `apple-credentials` environment limits these jobs to `main`; the documented setup has no required reviewer. Pull requests do not use this environment or receive signing secrets.

The hosted Xcode 27 runner regenerates the project and the configuration export. That one export feeds authenticated account diagnostics, team selection and archive validation. The existing app and bundle-ID records must be verified as accessible before Xcode starts the archive. The workflow builds an unsigned archive, then asks Xcode to export an App Store Connect distribution package with automatic signing and `destination=export`. It does not upload the package.

Xcode may create or update the app's distribution provisioning profile and may create a distribution certificate. Review and approve those Apple account changes before you dispatch. The workflow checks the exported app against the archive and the fresh manifest for identity, signature, entitlements, profile and certificate match, and expiry.

Preflight uploads the public configuration export. The signing job uploads only the sanitized validation report, and removes the private key, archive and exported package from the runner's temporary storage. TestFlight uses a reviewed, checked-in `ExportOptions.plist` policy at [config/ExportOptions-TestFlight.plist](../config/ExportOptions-TestFlight.plist).

Automatic signing needs an App ID prefix that matches the team ID. The workflow rejects legacy prefixes. They would need a separately reviewed manual-signing path, which is not implemented yet.

For local Windows use, Python 3 and `curl.exe` are prerequisites; no Go toolchain is needed:

```powershell
python scripts/install-asc.py
python scripts/apple-doctor.py --configuration C:\Downloads\ios-test-results-starter\configuration.json --account --asc build\tools\asc.exe
```

Supply the same credential environment fields through your secure local environment or secret tooling. Instead of `ASC_PRIVATE_KEY`, you can set `ASC_PRIVATE_KEY_PATH` to an existing securely stored file outside the checkout. Do not type literal secrets into shell commands or transcripts. Local file access restrictions and Windows ACLs are your responsibility; these tools do not install a Windows credential vault. Individual keys omit the issuer ID.

The wrapper isolates the CLI configuration, skips stored Keychain and config profiles, turns off telemetry and debug settings, and uses only the credential fields supplied in the environment. It does not save a credential profile. Temporary key material stays in the wrapper's temporary directory, which the wrapper removes after the reads or after a child process times out. If the wrapper itself is killed, cleanup can still be interrupted. Prefer the short-lived hosted runner for account checks, and use the bootstrap script above to move credentials to GitHub securely.

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

The wrapper reads app records filtered by the configured bundle ID, matching registered bundle IDs, the distribution-certificate inventory, and profiles linked to an accessible bundle ID. The certificate inventory is team-wide. An existing certificate may be expired or have no private key available locally. A linked profile may be expired, invalid or wrong for distribution; signed-archive validation checks these separately. Diagnostics do not verify membership, agreement acceptance, capability approval, signed archives or device delivery.

The CLI prints human-readable errors that do not always include an HTTP status or code. The wrapper classifies only recognizable denied-access and authentication messages and leaves other errors unverified. Never treat a 403 or 404 as an empty successful list. A later CLI version with structured errors could make this more specific.

## Reviewed CLI dependency

The template runs [App-Store-Connect-CLI 5.14.0](https://github.com/rorkai/App-Store-Connect-CLI/releases/tag/5.14.0) as a subprocess and downloads it only when asked. `scripts/install-asc.py` pins the published SHA-256 values and checks the bytes before saving a binary. It runs no remote installer and does not change the global PATH. Its native Windows release is amd64; Windows ARM has no reviewed native asset in this pin. Linux and macOS support amd64/arm64. TLS verification stays enabled.

The upstream CLI is MIT licensed; see [the upstream license](https://github.com/rorkai/App-Store-Connect-CLI/blob/5.14.0/LICENSE). This template does not vendor its source or redistribute release binaries. Its module path keeps the original `rudrankriyam` owner although the release repository is `rorkai`; that mismatch is not a reason to build the ignored reference checkout.

Upstream telemetry is on by default. The integration sets `ASC_TELEMETRY_DISABLED=1` and `DO_NOT_TRACK=1` for its own runs without changing the user's preferences. The wrapper uses only `apps list`, `bundle-ids list`, `certificates list`, and `bundle-ids profiles list`, with JSON and pagination. Do not replace these with `auth login`, `auth doctor --fix`, web-session login, token output or arbitrary agent-generated CLI strings. Those commands have other effects and exposure risks.

CI uses fixtures to test permission failures, incomplete credentials, malformed responses, timeouts and secret-canary redaction. Native CLI help and version runs check that the executable and flags exist on each platform. **A fixture pass is not a real Apple account check.** Run the opt-in workflow to get findings for your account before signing. The demo's recorded signing result says nothing about another account.

## Continue to TestFlight

The demo's signing evidence is recorded in the [roadmap](../roadmap.md). To upload your app, obtain explicit TestFlight authorization and follow [the delivery guide](testflight-delivery.md). The [archived Windows handoff](archive/windows-milestone-6-handoff.md) records the original acceptance steps.

Signing and key approvals already given still stand; do not ask again unless the plan changes. Check upload permission separately. The Account Holder handles agreements and compliance decisions. Release app and build reads use the same pinned CLI and isolated Reader through fixed commands in `scripts/testflight-release.py`. They require an explicit `--account`, keep the diagnostic command interface narrow, and never forward raw account output. Code and fixture tests alone do not show live account access or a successful upload.
