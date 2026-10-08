# Working on this starter

Read `roadmap.md`, `README.md`, and `docs/setup-experience.md` before changing the template. The roadmap records agreed decisions and milestone gates; the experience journal records observed failures, fixes, and verification evidence.

## Product constraints

- The default user has Windows, GitHub, and an iPhone. Xcode work runs on GitHub-hosted macOS runners. Do not require a separately managed Mac for app development, signing, or TestFlight delivery.
- A persistent owned or rented Mac is required only for the optional live iMessage bridge. Local Mac development is an optional alternative.
- Keep iPhone/iPad as the default. Additional platforms and AI/backend capabilities are independently optional.
- Keep SDK selection separate from minimum supported OS and tested runtime coverage. Do not claim iOS 17 runtime compatibility from an iOS 27 simulator result.

## Implementation and verification

- Work through the roadmap in order; finish required checks before starting the next milestone. Keep changes and commits reviewable.
- `project.yml` is the source of truth for the Xcode project. Change the manifest, then run `bash scripts/generate-project.sh` on a Mac or the GitHub runner. Commit the regenerated project alongside manifest changes.
- CI explicitly selects Xcode 27.0 on the `xcode-27` runner. Upgrade deliberately and verify the actual version, bundled SDK, and simulator availability. The runner image is not immutable.
- Inspect the actual test results, not just a green job. The milestone 1 workflow runs one welcome-screen UI assertion; placeholder unit tests do not establish feature coverage.
- `platform-and-sdk-notes.md` preserves an earlier user-provided text verbatim. Use the roadmap for current decisions rather than silently rewriting that reference.
- `App-Store-Connect-CLI/` is an ignored reference checkout with its own Git repository. Do not stage it into this repository or treat it as an integrated dependency. Audit its license and platform support before reuse.

## Credentials and release

- Use GitHub Secrets for private keys, tokens, and signing passwords. Ordinary GitHub Variables are for non-sensitive configuration.
- Do not request secret values in chat or put them in source, example files, logs, app bundles, or uploaded artifacts. Never dump the process environment when diagnosing credentials.
- At the signing/release milestones, scope credential access to the release job and intended environment. Keep pull-request builds unsigned and secretless. Preview account changes; do not silently revoke existing signing assets.
- Repository visibility is a user decision. Private source is not a substitute for secure credential handling; do not change visibility without user authorization.

## Leave a breadcrumb trail

Update `docs/setup-experience.md` whenever setup, implementation, or verification reveals a non-obvious failure, limitation, workaround, or important decision. Record:

1. The date, task/milestone, and relevant tool versions.
2. The symptom and whether the cause is confirmed or suspected.
3. A reproducible fix or next diagnostic step, without credentials or personal machine details.
4. The verification result, with commit/run links where useful.
5. Remaining uncertainty and any onboarding/tooling improvement needed.

Distinguish observed behavior from assumptions. Report material trouble to the user as it occurs, explain the resolution, and mention any remaining limitation. Turn recurring workarounds into documented commands or onboarding improvements. Avoid duplicating raw logs; preserve the useful diagnosis and evidence.

## Apple setup diagnostics

Read `docs/apple-setup.md` before guiding Apple setup. Start with credential-free `python scripts/apple-doctor.py`; use the current run's native Xcode `configuration.json` export for project findings. Never claim a stale artifact verifies edited configuration.

Authenticated reads require explicit opt-in. Use the pinned CLI through `scripts/apple-doctor.py --account --asc <binary>`, not arbitrary CLI commands. Do not run login, fixes, key generation, certificate/profile changes or revocation during diagnosis. Do not forward raw upstream output into logs or artifacts. Treat inaccessible and unverified checks as unknown, never as proof that an asset is missing. Present intended team, key type, role and account changes before any later setup operation; human enrollment, payment, identity and agreement decisions remain specific human steps.
