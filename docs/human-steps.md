# Human-step ledger

Every step that a person currently has to do by hand is a row here, with the path to automating it. The target experience: clone the repository, grant permissions once, sign in to the few windows that require you, then walk away and come back to a template app on your phone. A step stays human only when a law, a payment, an identity check, or a second-factor code makes it so.

Add a row the same day any agent or document says "only you can do this". Update the status column when a step is automated. The onboarding runbook (master plan step 6) reads this ledger to decide what to ask for and when.

## Automation paths

- **API / CLI:** already scriptable with the pinned tools and GitHub CLI; needs a granted permission category, not a human.
- **Browser agent:** doable by a computer-use agent in the user's signed-in browser once the user has granted that category. Apple two-factor prompts still reach the user's trusted device, so the agent asks for the code rather than owning the login.
- **Config:** avoidable entirely by shipping the right configuration in the template.
- **Human:** identity, payment, legal agreement, physical device action, or a second factor. Ask once, clearly, at the right moment.

## Permission categories (consent granted once at setup)

| Category | Grants | Used by |
| --- | --- | --- |
| `github-settings` | Repository settings, rulesets, environments, secrets metadata | `configure-github-repo.py`, environment reviewer setup |
| `apple-read` | Read-only App Store Connect API calls | diagnostics, feedback reader, build inventory |
| `apple-provisioning` | Xcode automatic signing may create or refresh profiles and certificates for the named team | signing, delivery, `run-on-device` |
| `apple-testflight` | Create or modify beta groups, assign builds, set build attributes | dev-group automation, compliance attribute |
| `apple-browser` | Computer-use agent acts in the user's signed-in App Store Connect and developer-portal tabs for steps the API cannot do | app record creation, key creation |
| `device-install` | Install and launch development builds on the user's registered devices | `run-on-device`, ad hoc channel |

| Setup permission choices | Human choice | `python scripts/setup.py` records the six yes/no choices and completed stages in ignored `build/setup-state.json`; granting a category does not replace action-specific approval |

## Ledger

| Step | Today | Path | Status / next action |
| --- | --- | --- | --- |
| Apple Developer Program enrollment and payment | Human | Human | Ask once, before anything Apple. Link to Apple's enrollment page; verify membership afterwards with `apple-doctor`. |
| Accept Apple agreements (Paid Apps, program license) | Human | Human | Legal acceptance stays with the Account Holder; the runbook detects the "agreement outstanding" API error and names the agreement. |
| Create App Store Connect API key and download the one-time `.p8` | Human in browser | Browser agent (`apple-browser`), then `bootstrap-apple-credentials.py` | Key creation is a portal form; the download is a single file the agent can hand to the bootstrap script without reading it back. Role choice is presented first (issue #1). |
| Transfer `.p8` into the GitHub environment | Scripted | API / CLI (`github-settings`) | Done: `bootstrap-apple-credentials.py` sends over stdin, verifies metadata only. |
| Create the `apple-credentials` environment with reviewer and `main`-only policy | Human in GitHub UI | API / CLI (`github-settings`) | GitHub's environments and deployment-branch-policy endpoints cover it. Add to `configure-github-repo.py`. |
| Repository settings and `main` ruleset | Scripted | API / CLI (`github-settings`) | Done: `configure-github-repo.py --apply`. |
| `gh auth login` | Human (device code in browser) | Human, once | A login is the user's; the runbook asks for it first and verifies with `gh auth status`. |
| Register the App ID / bundle identifier | Human in portal | API / CLI (`apple-provisioning`) | `bundle-ids` create exists in the pinned CLI; Xcode automatic signing also registers it on first signed build. Preview before creating; reuse existing (issue #4). |
| Create the App Store Connect app record | Human in browser | Browser agent (`apple-browser`) | The public API does not create apps (verify at implementation). Confirm name, bundle ID, SKU, language first; handle a name collision (issue #4). |
| Export-compliance answer per build | Config shipped | Config | **Done 2026-10-16 ([PR #41](https://github.com/asavs/ios-app-starter/pull/41)):** `ITSAppUsesNonExemptEncryption = NO` in the manifest; compiled-app and archive checks require it. Revisit per app when networking or cryptography is added. Resolves most of issue #17; first confirmation comes with the next upload. |
| Create the TestFlight internal group with automatic distribution | Scripted, awaiting first run | API / CLI (`apple-testflight`) | **Implemented 2026-10-16:** `TestFlight groups` workflow plans on every dispatch and, with `apply=true` from `main` behind the protected environment, runs `asc testflight groups create --internal --access-all-builds` and adds users of a chosen role. Nothing is deleted; the old `dev` group is retired by hand after the new one is verified. |
| Add the owner as tester to the group | Scripted, awaiting first run | API / CLI (`apple-testflight`) | Same workflow: `asc testflight testers add --email <user> --group <id>` for each App Store Connect user with the selected role (default `ACCOUNT_HOLDER`); identities never appear in logs or reports. |
| Accept the TestFlight invitation on the phone | Human | Human (once per tester) | Internal testers who are App Store Connect users see builds in the TestFlight app without an email step once in a group with automatic distribution. |
| Install the build from TestFlight on the phone | Human tap | Human | The distribution tier. For iteration use `run-on-device` (Mac) or the ad hoc channel (any OS). |
| Choose whether an ad hoc signed IPA may be publicly hosted | Human decision | Config / API / CLI | Before implementing ad hoc delivery, default to private hosting. A public GitHub Release requires explicit approval for that app's binary; a public template repository alone is not approval. |
| Enable Developer Mode and trust the computer on the phone | Human | Human (once per device) | Physical device prompts; the runbook names them before the first `run-on-device`. |
| Register the device for development | Human in portal | API / CLI (`apple-provisioning`) | `run-on-device` with `IOS_REGISTER_DEVICE=1` lets Xcode do it; the pinned CLI can also create the device record. Preview first. |
| Approve the `apple-credentials` environment deployment per run | Scripted behind a flag | API / CLI (`github-settings`), or policy | `scripts/deliver_testflight.py --approve` posts the approval under the caller's GitHub login once preflight passes; without the flag it prints the exact `gh api ... pending_deployments` command. With solo-owner policy the approval is self-approval already; the flag keeps it a conscious decision per upload. Read-only dispatches (groups plan, diagnostics) still need the click until a separate read-only environment exists. |
| Merge pull requests | Was human | Done: auto-merge after required checks | Rulesets and `gh pr merge --auto`. |
| Grant the agent harness permission for `gh pr merge` / `gh pr close` | Human, once | Human, once | Recorded in the runbook as a one-time local setup step. |
| Apple ID two-factor code when a browser session starts | Human | Human (each new session) | API keys avoid it for everything the API covers; browser-agent steps ask the user for the code. |

## Cloud computers

Nothing before the live iMessage bridge (master plan step 10) needs a machine other than GitHub-hosted runners and the user's own devices. The browser agent runs where the user's signed-in browser is, on Windows or Mac; it does not need a cloud Mac. The live bridge needs a persistent Mac signed into Messages. Decide the provider at that milestone against: persistent login and Apple ID on the machine, remote access for the agent, cost per month, and the rule that pull-request CI never runs on it. Candidates to evaluate then: a hosted Mac provider, a cloud vendor's Mac instances, or an owned Mac mini.
