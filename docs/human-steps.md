# Setup steps that need a person

This list shows each setup step that needs your decision or action, what an agent can do with your permission, and how the step could be automated. The aim: you clone the starter, grant permissions once, answer the sign-in and device prompts, and get your app onto your phone. Identity checks, payments, legal decisions, physical device actions and second factors stay with you.

Add a row the day an agent or document says "only you can do this", and update its status once the step is automated. The [onboarding runbook](agent-onboarding.md) uses this list to decide what to ask for and when.

## Automation paths

- **API / CLI:** scriptable with the pinned tools and GitHub CLI once the owner grants the permission category and, where required, approves the specific action.
- **Browser agent:** an agent uses the owner's signed-in browser with permission. Apple two-factor prompts still go to the owner's trusted device; the owner enters the code in the browser, never in chat.
- **Config:** the template ships a configuration that removes the step.
- **Human:** identity, payment, legal agreement, physical device action, or a second factor. Ask once, clearly, at the right moment.

## Permission categories (consent granted once at setup)

| Category | Grants | Used by |
| --- | --- | --- |
| `github-settings` | Repository settings, rulesets, environments, secrets metadata | `configure-github-repo.py`, main-only environment policy; optional reviewer setup |
| `apple-read` | Read-only App Store Connect API calls | diagnostics, feedback reader, build inventory |
| `apple-provisioning` | Xcode automatic signing may create or refresh profiles and certificates for the named team | signing, delivery, `run-on-device` |
| `apple-testflight` | Create or modify beta groups, assign builds, set build attributes | dev-group automation, compliance attribute |
| `apple-browser` | Computer-use agent acts in the user's signed-in App Store Connect and developer-portal tabs for steps the API cannot do | app record creation, key creation |
| `device-install` | Install and launch development builds on the user's registered devices | `run-on-device`, ad hoc channel |

The owner chooses which to grant. `python scripts/setup.py` records the six yes/no choices and completed stages in ignored `build/setup-state.json`. A granted category does not replace approval of each specific action.

## Ledger

| Step | Today | Path | Status / next action |
| --- | --- | --- | --- |
| Apple Developer Program enrollment and payment | Human | Human | Ask once, before anything Apple. Link to Apple's enrollment page; verify membership afterwards with `apple-doctor`. |
| Accept Apple agreements (Paid Apps, program license) | Human | Human | Acceptance stays with the Account Holder. The runbook detects the "agreement outstanding" API error and names the agreement. |
| Create App Store Connect API key and download the one-time `.p8` | Human in browser | Browser agent (`apple-browser`), then `bootstrap-apple-credentials.py` | Key creation is a portal form. The agent can pass the downloaded file to the bootstrap script without reading it. Present the role choice first (issue #1). |
| Transfer `.p8` into the GitHub environment | Scripted | API / CLI (`github-settings`) | Done: `bootstrap-apple-credentials.py` sends it over stdin and verifies metadata only. |
| Create the `apple-credentials` environment with a `main`-only policy | Scripted | API / CLI (`github-settings`) | Done: `configure-github-repo.py` applies exactly one `main` branch policy and no required reviewer by default. To require a reviewer, pass `--require-reviewer` or add one in repository Settings → Environments → `apple-credentials`. |
| Repository settings and `main` ruleset | Scripted | API / CLI (`github-settings`) | Done: `configure-github-repo.py --apply`. |
| `gh auth login` | Human (device code in browser) | Human, once | The user logs in. The runbook asks for it first and verifies it with `gh auth status`. |
| Register the App ID / bundle identifier | Human in portal | API / CLI (`apple-provisioning`) | The pinned CLI has `bundle-ids` create, and Xcode automatic signing registers the ID on the first signed build. Preview before creating; reuse an existing one (issue #4). |
| Create the App Store Connect app record | Human in browser | Browser agent (`apple-browser`) | The public API does not create apps (verify at implementation). Confirm name, bundle ID, SKU and language first; handle a name collision (issue #4). |
| Export-compliance answer per build | Config shipped | Config | Done: `ITSAppUsesNonExemptEncryption = NO` in the manifest, and the compiled-app and archive checks require it. Revisit per app when it adds networking or cryptography. |
| Create the TestFlight internal group with automatic distribution | Scripted, awaiting first run | API / CLI (`apple-testflight`) | The `TestFlight groups` workflow prints a plan on every dispatch. With `apply=true` from `main` behind the protected environment, it runs `asc testflight groups create --internal --access-all-builds` and adds users of a chosen role. It deletes nothing. |
| Add the owner as tester to the group | Scripted, awaiting first run | API / CLI (`apple-testflight`) | Same workflow: `asc testflight testers add --email <user> --group <id>` for each App Store Connect user with the selected role (default `ACCOUNT_HOLDER`). Identities never appear in logs or reports. |
| Accept the TestFlight invitation on the phone | Human | Human (once per tester) | Internal testers who are App Store Connect users see builds in the TestFlight app, with no email step, once they are in a group with automatic distribution. |
| Install the build from TestFlight on the phone | Human tap | Human | Install the exact version and build being checked. For local iteration, use `run-on-device` on a Mac; an ad hoc channel for any OS is still under evaluation. |
| Choose whether an ad hoc signed IPA may be publicly hosted | Human decision | Config / API / CLI | Default to private hosting when ad hoc delivery is built. A public GitHub Release needs explicit approval for that app's binary; a public template repository is not approval. |
| Enable Developer Mode and trust the computer on the phone | Human | Human (once per device) | Physical prompts on the device. The runbook names them before the first `run-on-device`. |
| Unlock the login keychain for the agent's shell after a Mac restart | Human (password) | Human (after each restart) | Signing for the phone (`run-on-device`, UI tests on the device) fails with `errSecInternalComponent` while the login keychain is locked for the agent's session. Unlocking in Terminal or Keychain Access does not reach that session. Run `! security unlock-keychain /Users/<you>/Library/Keychains/login.keychain-db` in the agent's own prompt, with the full path (`~` is not expanded). Once per Mac, also run `security set-key-partition-list -S apple-tool:,apple:,codesign: -s <same path>`. |
| Register the device for development | Human in portal | API / CLI (`apple-provisioning`) | `run-on-device` with `IOS_REGISTER_DEVICE=1` lets Xcode do it; the pinned CLI can also create the device record. Preview first. |
| Merge pull requests | Was human | Done: auto-merge after required checks | Rulesets and `gh pr merge --auto`. |
| Grant the agent harness permission for `gh pr merge` / `gh pr close` | Human, once | Human, once | A one-time local setup step in the runbook. |
| Apple ID two-factor code when a browser session starts | Human | Human (each new session) | API keys avoid it for everything the API covers. In browser-agent steps the user enters the code in the browser, never in chat. |

## Cloud computers

Building and delivering the app needs only GitHub-hosted runners and the owner's devices. A browser agent uses the owner's signed-in browser on Windows or Mac and needs no cloud Mac.

Only the optional live iMessage bridge needs a persistent Mac signed into Messages: an owned Mac mini, a hosted Mac provider, or a cloud vendor's Mac instances. Before choosing, check persistent login and Apple ID support, how the agent gets remote access, and the monthly cost. Pull-request CI must never run on that machine.
