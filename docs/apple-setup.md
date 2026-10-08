# Apple setup from Windows

This is milestone 4: guidance and read-only diagnostics. You can already build and test without an Apple account. Signing and validated archives follow in milestone 5; installing through TestFlight follows in milestone 6. You do not need to operate a Mac: GitHub Actions performs Xcode work.

## Human prerequisites

1. Check whether you already have an active [Apple Developer Program membership](https://developer.apple.com/programs/enroll/). Choose individual or organization enrollment deliberately. Apple requires identity verification; organizations also need appropriate legal authority and organization information. Enrollment includes payment unless a waiver applies. Do not create a second membership merely because an API check failed.
2. Sign in to [App Store Connect](https://appstoreconnect.apple.com/) and confirm the intended team and your role. Have the Account Holder review membership status and outstanding agreements. These diagnostics do not verify that all contractual prerequisites are satisfied.
3. The Account Holder requests API access under **Users and Access → Integrations → App Store Connect API → Request Access**. Apple reviews requests. A missing button or pending approval is a human/account prerequisite, not a broken Windows installation. See [Apple's API access instructions](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/).
4. Choose key type and role with the account owner. Team keys have role-based access across the team's apps; individual keys inherit their user's app access and permissions. Do not default to Admin. Provisioning permissions must be checked separately from app-list access; a successful app read does not establish signing access. See [Apple's key creation instructions](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api) and [role permissions](https://developer.apple.com/support/roles/). The diagnostic records inaccessible provisioning endpoints without trying a broader key automatically.
5. Generate and download the chosen key through Apple's website. Private keys can be downloaded only once. Keep a secure backup outside the checkout; never paste the private key, passwords, 2FA codes or signing passwords into agent chat. Lost/compromised keys require deliberate revocation and replacement by the owner.

A computer-use agent can explain the pages, navigate, inspect visible account state, diagnose missing permissions and prepare a concrete plan. The human handles identity verification, passwords/2FA, payment and agreement decisions. Key creation, permission changes and account mutations need a specific authorized plan; agreeing to diagnostics does not authorize them. Avoid capturing private-key contents in screenshots or logs. There is no Apple browser automation or MCP dependency in this template.

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

Alternatively, run **Actions → Apple diagnostics → Run workflow**, leaving account reads disabled. Its hosted Mac validates and exports the current project; the other jobs exercise portable diagnostics and the native CLI on Windows, Linux and macOS. Download `apple-project-diagnostics` for the project report. Ordinary push/PR checks use no Apple secrets.

## Optional authenticated reads

Use an existing approved key when possible. Only configure credentials when you want account diagnostics; they are unnecessary for unsigned CI. For the GitHub path, create an environment named **apple-account** in your own repository, restrict its deployment branches to `main`, and use required reviewers where your GitHub plan supports them. Enter **environment secrets** through GitHub's UI:

| Name | Value |
| --- | --- |
| `ASC_KEY_ID` | API key ID |
| `ASC_ISSUER_ID` | Issuer ID for a team key; omit for an individual key |
| `ASC_PRIVATE_KEY` | Complete downloaded `.p8` PEM contents, entered directly into GitHub Secrets |

Set environment **variable** `ASC_KEY_TYPE` to `team` or `individual`; the default is `team`. Do not use ordinary variables for private material. Protect `main` and review workflow changes: code allowed to run with secrets can access them. The workflow's account job is manually enabled, restricted to `main`, and separate from PR jobs. It performs no login, key creation, account mutation, archive, or upload.

Run **Apple diagnostics** on `main`, enabling its account checkbox. Missing secrets produce `not_configured`/`not_verified`, rather than fabricated account results. The report includes only sanitized findings and counts. Do not upload raw CLI responses or credential files. Review artifact access before sharing a diagnostic, even though it excludes credentials and account identifiers.

For local Windows use, Python 3 and `curl.exe` are prerequisites; no Go toolchain is needed:

```powershell
python scripts/install-asc.py
python scripts/apple-doctor.py --configuration C:\Downloads\ios-test-results-starter\configuration.json --account --asc build\tools\asc.exe
```

Supply the same credential environment fields through your secure local environment/secret tooling, or use `ASC_PRIVATE_KEY_PATH` pointing to an existing securely stored file outside the checkout instead of `ASC_PRIVATE_KEY`. Do not type literal secrets into shell commands or transcripts. Local file access restrictions and Windows ACLs remain your responsibility; this milestone does not install a Windows credential vault. Individual keys omit the issuer ID. The wrapper isolates CLI configuration, bypasses stored Keychain/config profiles, disables telemetry/debug settings and uses only the explicitly supplied environment credential fields. It does not persist a credential profile. Temporary material created by the CLI is subject to upstream cleanup; hard process termination can interrupt cleanup. Prefer the short-lived hosted runner for account checks until persistent credential handling is implemented in milestone 5.

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
