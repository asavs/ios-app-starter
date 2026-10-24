# Working on this starter

## Start here

- **Setting up an app from this template** (fresh repository to the app on the owner's iPhone): follow [`docs/agent-onboarding.md`](docs/agent-onboarding.md) in order. It lists what to ask the owner for, the commands to run, what to say before each account-affecting action, and the known failures.
- **Changing the template itself:** read the rest of this file first.

Read `roadmap.md`, `README.md`, `docs/ci.md` (how builds, tests and delivery run), and `docs/setup-experience.md` (the journal index; entries live in `docs/journal/<milestone>.md`) before changing the template. The roadmap records agreed decisions and milestone gates; the experience journal records observed failures, fixes, and verification evidence.

## What the starter is

An iOS starter app. Onboarding, theme and UX elements, settings with secure storage, and next sign-in and a database layer are scaffolded as modules an app keeps or deletes, so its builder works on what makes the app different. Builds, signing and delivery run on GitHub and are handled for them. Lead docs and decisions with the app; the pipeline serves it.

## Product constraints

- The pipeline must work for someone with only Windows, GitHub and an iPhone. Xcode work runs on GitHub-hosted macOS runners. Do not require a separately managed Mac for app development, signing, or TestFlight delivery.
- A persistent owned or rented Mac is required only for the optional live iMessage bridge. Local Mac development is an optional faster loop.
- Keep iPhone/iPad as the default. Additional platforms and AI/backend capabilities are independently optional.
- Keep SDK selection separate from minimum supported OS and tested runtime coverage. Do not claim iOS 17 runtime compatibility from an iOS 27 simulator result.

## Implementation and verification

- Work through the roadmap in order; finish required checks before starting the next milestone. Keep changes and commits reviewable.
- Modules are products of the root `Package.swift`, one `Modules/<Name>/` folder each with their own tests; the template depends on them by path and generated apps by tag. Enable a module with a product line in `project.yml`; template sources reference modules only under `#if canImport`. Read `docs/modules.md` before adding or releasing one.
- `project.yml` is the source of truth for the Xcode project. Change the manifest, then run `bash scripts/generate-project.sh` on a Mac or the GitHub runner. Commit the regenerated project alongside manifest changes.
- CI explicitly selects Xcode 27.0 on the `xcode-27` runner. Upgrade deliberately and verify the actual version, bundled SDK, and simulator availability. The runner image is not immutable.
- Inspect the actual test results, not just a green job. The milestone 1 workflow runs one welcome-screen UI assertion; placeholder unit tests do not establish feature coverage.
- `platform-and-sdk-notes.md` preserves an earlier user-provided text verbatim. Use the roadmap for current decisions rather than silently rewriting that reference.
- `App-Store-Connect-CLI/` is an ignored reference checkout with its own Git repository. Do not stage it into this repository or treat it as an integrated dependency. Audit its license and platform support before reuse.

## Agent skills

Use the pinned skills in `.agents/skills/` (Codex) or `.claude/skills/` (Claude Code): `swiftui-pro` for SwiftUI views, `swift-concurrency-pro` for concurrency, `swift-testing-pro` for tests, `swiftdata-pro` for SwiftData, `write-swift` for Swift style, `emil-design-eng` for motion and interface polish, `apple-design` for Apple design conventions, `review-animations` for motion review, and `swiftui-accessibility-auditor` before closing a visible task or when reviewing VoiceOver, Dynamic Type, contrast, and touch targets. `review-animations` opts out of automatic model invocation and runs only when asked. Copies are pinned in `skills.lock`; verify them with `python scripts/sync-skills.py` and update them only with `python scripts/sync-skills.py --update [name]`. To add one, add its source repository and skill path to `skills.lock`, run `python scripts/sync-skills.py --update <name>`, and add it to this list. To remove one, remove its lock entry and both copied folders, then remove it from this list. Never edit pinned copies by hand.

## Credentials and release

- Use GitHub Secrets for private keys, tokens, and signing passwords. Ordinary GitHub Variables are for non-sensitive configuration.
- Do not request secret values in chat or put them in source, example files, logs, app bundles, or uploaded artifacts. Never dump the process environment when diagnosing credentials.
- At the signing/release milestones, scope credential access to the release job and intended environment. Keep pull-request builds unsigned and secretless. Preview account changes; do not silently revoke existing signing assets.
- The documented `apple-credentials` setup restricts deployments to `main` and does not require a reviewer. A template user may opt into an additional required reviewer in GitHub environment settings or with `scripts/configure-github-repo.py --require-reviewer`.
- Repository visibility is a user decision. Private source is not a substitute for secure credential handling; do not change visibility without user authorization.

## Do not wait on CI

Never poll GitHub Actions from a model loop or spawn an agent to watch a run. Open the pull request, enable auto-merge once required checks exist (`gh pr merge <n> --auto --merge`), and move on. When a result is needed in this session, block in a shell for free (`gh pr checks <n> --watch`, `gh run watch <id>`, or a background `until` loop) and read the outcome with `python scripts/review_ci.py` afterwards. Keep required checks under about ten minutes; anything slower is scheduled or manual.

## Leave a breadcrumb trail

Update the setup journal whenever setup, implementation, or verification reveals a non-obvious failure, limitation, workaround, or important decision. `docs/setup-experience.md` is the index; add the entry to the current milestone's file in `docs/journal/<milestone>.md`, newest first. Record:

1. The date, task/milestone, and relevant tool versions.
2. The symptom and whether the cause is confirmed or suspected.
3. A reproducible fix or next diagnostic step, without credentials or personal machine details.
4. The verification result, with commit/run links where useful.
5. Remaining uncertainty and any onboarding/tooling improvement needed.

When a step needs a person, add or update its row in `docs/human-steps.md` with the automation path before telling the user it is theirs to do. Distinguish observed behavior from assumptions. Report material trouble to the user as it occurs, explain the resolution, and mention any remaining limitation. Turn recurring workarounds into documented commands or onboarding improvements. Avoid duplicating raw logs; preserve the useful diagnosis and evidence.

## Apple setup diagnostics

Read `docs/apple-setup.md` before guiding Apple setup. Start with credential-free `python scripts/apple-doctor.py`; use the current run's native Xcode `configuration.json` export for project findings. Never claim a stale artifact verifies edited configuration.

Authenticated reads require explicit opt-in. Use the pinned CLI through `scripts/apple-doctor.py --account --asc <binary>`, not arbitrary CLI commands. Do not run login, fixes, key generation, certificate/profile changes or revocation during diagnosis. Do not forward raw upstream output into logs or artifacts. Treat inaccessible and unverified checks as unknown, never as proof that an asset is missing. Present intended team, key type, role and account changes before any later setup operation; human enrollment, payment, identity and agreement decisions remain specific human steps.
