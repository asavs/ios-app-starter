# Milestone 10 journal: agent onboarding and guided setup

Entries for the fresh-repository onboarding path, consent model, and resumable setup command. Newest first. Index: [setup-experience.md](../setup-experience.md).

## 2026-10-25 — A bot's pull request needs the owner twice

- **Context:** First run of the opt-in README icon sync (`readme-icon.yml`), GitHub-hosted runners, gh CLI on macOS. The workflow opened [PR #119](https://github.com/asavs/ios-app-starter/pull/119) with the workflow token and dispatched `ios.yml` and `apple-diagnostics.yml` on its branch so the required checks would report.
- **Symptom (confirmed):** All four required checks passed on the head commit and auto-merge was on, yet the PR stayed `BLOCKED` ("the base branch policy prohibits the merge"). The PR's own `pull_request` runs sat at `action_required`: the fork-contributor approval policy (all outside contributors) treats `github-actions[bot]` as an outsider. The `main` ruleset also carries `require_extra_approval_for_unattributed_changes: true`, which GitHub set by default; `configure-github-repo.py` never asked for it.
- **Fix:** The owner approved the change (`gh pr review 119 --approve`), which alone did not unblock it, then clicked **Approve workflows to run**. Both `pull_request` runs passed and the PR merged within minutes. The dispatched runs did not satisfy the merge by themselves, so the workflow no longer dispatches them; the docs now say the owner approves the runs and the change.
- **Remaining uncertainty:** Whether the review approval is needed in addition to the run approval was not isolated; both were given. Keep both safeguards: a bot's change merges only after a person has looked at it.

## 2026-10-19 — Script the Apple credentials environment policy

- **Context:** The onboarding guide and human-step ledger still described `apple-credentials` creation as a manual GitHub UI step, although GitHub's REST API supports environment reviewers and deployment branch policies. Relevant command versions were not queried in this local implementation session.
- **Change:** `configure-github-repo.py` now previews and applies a required reviewer, a `main`-only deployment policy, and a self-review setting. It uses the authenticated user as reviewer; the personal repository owner may approve their own deployment, while other configurations prevent self-review. The bootstrap runbook, README, and human-step ledger now describe this path.
- **Verification:** Reviewed the code and documentation changes locally. No GitHub API call or test suite was run, so live permissions and endpoint behavior remain unverified.
- **Remaining uncertainty:** GitHub may reject environment protection changes for a repository plan or permission level that cannot manage deployment environments. Run the script's dry run and apply only after reviewing the exact reviewer and policy; retain the current UI path as a fallback if API access is unavailable.

## 2026-10-19 — No-echo credential bootstrap guidance

- **Context:** Stage C showed the existing transfer command but still labeled its safety write-up a placeholder. The implementation sends the private key through `gh` standard input, validates the environment before transfer, and confirms secret names without reading values.
- **Change:** Documented the environment checks, outside-checkout key path, stdin-only transfer, captured CLI errors, secret-name-only confirmation, non-secret key-type variable, and the sequential-write/partial-failure recovery path. Removed issue #7 from the onboarding gaps; issue #1 remains because the stored key's role is not learned from secret metadata.
- **Tools and verification:** Windows PowerShell 5.1.26100.9711, Python 3.13.14, Git 2.54.0.windows.1. Documentation-only review against `scripts/bootstrap-apple-credentials.py`, its existing tests, and Stage C's approval rules; tests were not run.
- **Remaining uncertainty:** The bootstrap confirms secret names, not the contents, key validity at App Store Connect, or key role. Role must be confirmed and recorded separately without exposing the key.

## 2026-10-19 — Resumable setup checkpoints

- **Context:** The onboarding runbook had human-readable stages but no saved progress. A fresh agent or interrupted setup had to infer which stages and permission categories had already been handled.
- **Change:** Added `scripts/setup.py` to persist explicit consent decisions and sequential A–H completion checkpoints under ignored `build/setup-state.json`. The interactive flow shows the current runbook stage, pauses when consent is declined, and saves after each answer. It rejects skipped stages and requires the stage's mapped consent before completion. State contains only consent booleans and stage letters; no secrets, team identifiers or account output are read or saved. `--status`, `--grant`, `--decline`, `--complete` and `--reset` support non-interactive continuation.
- **Tools and verification:** Python 3.13.14; `python -m py_compile scripts/setup.py scripts/tests/test_setup.py` passed; `python scripts/tests/test_setup.py` passed all five tests. The tests cover initial status, consent gating and stage order, the state schema, invalid-state handling, and pausing after a declined consent.
- **Remaining uncertainty:** This first version records progress around the runbook; it does not dispatch GitHub/Apple actions or verify their results itself. The operator must run each stage's commands and checks before recording completion. Future automation can replace individual manual checkpoints while keeping the same state file contract and consent stops.

## 2026-10-19 — Consent-once permission checklist

- **Context:** The onboarding runbook's consent section was a placeholder. It named the six categories from the human-step ledger, but did not present a checklist or spell out how to handle a denied category. The categories also needed to be distinguished from the per-action change previews, environment gates, and human-only decisions elsewhere in the runbook.
- **Change:** Replaced the placeholder with a six-category grant table scoped to the repository and, where relevant, the named Apple team. The runbook records answers in the setup conversation, stops before a step that needs an ungranted category, and does not repeat a category grant already given for that setup. It states that the conversation record is temporary until the guided setup command can read a persistent record.
- **Tools and verification:** Windows PowerShell and Git. Documentation-only inspection against `docs/human-steps.md` and master plan step 6; automated tests were not run.
- **Remaining uncertainty:** The future setup command's consent-record format and persistence behavior are not implemented. Keep its behavior aligned with the categories and grant rule in the ledger.
