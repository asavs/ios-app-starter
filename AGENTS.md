# Working on this starter

## Start here

- **Setting up an app from this template** (fresh repository to the app on the owner's iPhone): follow [`docs/agent-onboarding.md`](docs/agent-onboarding.md) in order. It lists what to ask the owner, the commands, what to say before each account-affecting action, and known failures.
- **Changing the template itself:** read the rest of this file, then `roadmap.md` (agreed decisions and milestone gates), `README.md`, `docs/ci.md` (how builds, tests and delivery run), and `docs/setup-experience.md` (the journal index of observed failures, fixes and evidence; entries live in `docs/journal/<milestone>.md`).

## What the starter is

An iOS starter app. Onboarding, theme and UX elements, settings with secure storage, and next sign-in and a database layer are modules an app keeps or deletes, so its builder can work on what makes the app different. Builds, signing and delivery run on GitHub without the builder handling them. Lead docs and decisions with the app; the pipeline exists to support it.

## Product constraints

- The pipeline must work with only Windows, GitHub and an iPhone: Xcode work runs on GitHub-hosted macOS runners. Do not require a separately managed Mac for development, signing, or TestFlight delivery.
- A persistent owned or rented Mac is required only for the optional live iMessage bridge. Local Mac development is an optional faster loop.
- Keep iPhone/iPad as the default. Additional platforms and AI/backend capabilities are each optional.
- Keep SDK selection separate from minimum supported OS and tested runtime coverage. Do not claim iOS 17 runtime compatibility from an iOS 27 simulator result.

## Implementation and verification

- Work through the roadmap in order; finish required checks before starting the next milestone. Keep changes and commits reviewable.
- Modules are products of the root `Package.swift`, one `Modules/<Name>/` folder each with its own tests; the template depends on them by path, generated apps by tag. Enable a module with a product line in `project.yml`; template sources reference modules only under `#if canImport`. Read `docs/modules.md` before adding or releasing one.
- `project.yml` is the source of truth for the Xcode project. Change it, run `bash scripts/generate-project.sh` on a Mac or the GitHub runner, and commit the regenerated project with it.
- CI explicitly selects Xcode 27.0 on the `xcode-27` runner. The runner image changes, so upgrade deliberately and verify the actual version, bundled SDK, and simulator availability.
- Inspect the actual test results, not just a green job. Placeholder unit tests do not establish feature coverage.
- `platform-and-sdk-notes.md` preserves an earlier user-provided text verbatim. Do not rewrite it; take current decisions from the roadmap.
- `App-Store-Connect-CLI/` is an ignored reference checkout with its own Git repository. Do not stage it into this repository or treat it as an integrated dependency. Audit its license and platform support before reuse.

## Agent skills

Use the pinned skills in `.agents/skills/` (Codex) or `.claude/skills/` (Claude Code): `swiftui-pro` for SwiftUI views, `swift-concurrency-pro` for concurrency, `swift-testing-pro` for tests, `swiftdata-pro` for SwiftData, `write-swift` for Swift style, `emil-design-eng` for motion and interface polish, `apple-design` for Apple design conventions, `review-animations` for motion review (runs only when asked, never automatically), `humanizer` for prose people read (docs, pull request descriptions, interface copy), and `swiftui-accessibility-auditor` before closing a visible task or when reviewing VoiceOver, Dynamic Type, contrast, and touch targets.

Copies are pinned in `skills.lock`; verify them with `python scripts/sync-skills.py` and update them only with `python scripts/sync-skills.py --update [name]`. Never edit pinned copies by hand. To add a skill, add its source repository and skill path to `skills.lock`, run `python scripts/sync-skills.py --update <name>`, and add it to the list above. To remove one, remove its lock entry and both copied folders, then remove it from the list.

## Credentials and release

- Put private keys, tokens, and signing passwords in GitHub Secrets; ordinary GitHub Variables are only for non-sensitive configuration.
- Do not request secret values in chat or put them in source, example files, logs, app bundles, or uploaded artifacts. Never dump the process environment when diagnosing credentials.
- Scope credential access to the release job and intended environment. Keep pull-request builds unsigned and secretless. Preview account changes; do not silently revoke existing signing assets.
- The documented `apple-credentials` environment restricts deployments to `main` without a required reviewer. A template user may add one in GitHub environment settings or with `scripts/configure-github-repo.py --require-reviewer`.
- Repository visibility is the user's decision; do not change it without their authorization. Private source is no substitute for secure credential handling.

## Do not wait on CI

Never poll GitHub Actions from a model loop or spawn an agent to watch a run. Open the pull request, enable auto-merge once required checks exist (`gh pr merge <n> --auto --merge`), and move on. When this session needs a result, block in a shell (`gh pr checks <n> --watch`, `gh run watch <id>`, or a background `until` loop), then read the outcome with `python scripts/review_ci.py`. Keep required checks under about ten minutes; make anything slower scheduled or manual.

## Leave a breadcrumb trail

When setup, implementation, or verification reveals a non-obvious failure, limitation, workaround, or important decision, add an entry, newest first, to the current milestone's `docs/journal/<milestone>.md` (indexed in `docs/setup-experience.md`). Record:

1. The date, task/milestone, and relevant tool versions.
2. The symptom and whether the cause is confirmed or suspected.
3. A reproducible fix or next diagnostic step, without credentials or personal machine details.
4. The verification result, with commit/run links where useful.
5. Remaining uncertainty and any onboarding/tooling improvement needed.

Preserve the diagnosis and evidence, not raw logs. Distinguish observed behavior from assumptions. Before telling the user a step is theirs to do, add or update its row in `docs/human-steps.md` with the automation path. Report material trouble to the user as it occurs, with the resolution and any remaining limitation. Turn recurring workarounds into documented commands or onboarding improvements.

## Apple setup diagnostics

Read `docs/apple-setup.md` before guiding Apple setup. Start with credential-free `python scripts/apple-doctor.py`; use the current run's native Xcode `configuration.json` export for project findings. Never claim a stale artifact verifies edited configuration.

Authenticated reads require explicit opt-in. Use the pinned CLI only through `scripts/apple-doctor.py --account --asc <binary>`, not arbitrary CLI commands. During diagnosis, do not run login, fixes, key generation, certificate/profile changes or revocation, and do not forward raw upstream output into logs or artifacts. Treat inaccessible and unverified checks as unknown, never as proof an asset is missing. Before any later setup operation, present the intended team, key type, role and account changes. Enrollment, payment, identity and agreement decisions stay with the human.
