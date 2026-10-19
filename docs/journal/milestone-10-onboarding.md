# Milestone 10 journal: agent onboarding and guided setup

Entries for the onboarding runbook, consent model, and resumable setup command. Newest first. Index: [setup-experience.md](../setup-experience.md).

## 2026-10-19 — Consent-once permission checklist

- **Context:** The onboarding runbook's consent section was a placeholder. It named the six categories from the human-step ledger, but did not present a checklist or spell out how to handle a denied category. The categories also needed to be distinguished from the per-action change previews, environment gates, and human-only decisions elsewhere in the runbook.
- **Change:** Replaced the placeholder with a six-category grant table scoped to the repository and, where relevant, the named Apple team. The runbook records answers in the setup conversation, stops before a step that needs an ungranted category, and does not repeat a category grant already given for that setup. It states that the conversation record is temporary until the guided setup command can read a persistent record.
- **Tools and verification:** Windows PowerShell and Git. Documentation-only inspection against `docs/human-steps.md` and master plan step 6; automated tests were not run.
- **Remaining uncertainty:** The future setup command's consent-record format and persistence behavior are not implemented. Keep its behavior aligned with the categories and grant rule in the ledger.
