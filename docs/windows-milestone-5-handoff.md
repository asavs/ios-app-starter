# Windows milestone 5 handoff

Continue the Windows chat that authored PR #8. Its local setup observations are useful context; the current repository and fresh CI evidence take precedence over earlier plans. A fresh chat is only needed if that chat is unavailable.

Copy the following prompt:

```text
Continue milestone 5 for https://github.com/asavs/ios-app-starter from Windows. Use this existing chat's Apple setup observations, but recheck current state. The Mac agent fixed PR #8 and verified the signing preflight, portable tests and all three simulator lanes. Your task is to prove the Windows onboarding path and, after explicit approval, validate a real signed archive on GitHub Actions.

1. Preserve local work, fetch the latest codex/milestone-5-signing branch and inspect PR #8. Do not overwrite the Mac agent's fixes or either agent's journal entries. Read AGENTS.md, roadmap.md, README.md, docs/setup-experience.md and docs/apple-setup.md. Start with credential-free python scripts/apple-doctor.py. Check PowerShell paths, prerequisites, bootstrap help and downloading/reading the current run's native configuration and test reports. Use a fresh export matching the selected manifest and commit; do not assume cached reports verify edited settings.

2. Verify the latest PR head's CI and review its changes. When required checks pass and the changes are sound, mark PR #8 ready, merge it, and update the local checkout to main. Verify main's checks before credential workflows. Merging the implementation does not complete milestone 5.

3. Present one concrete approval plan before changing environment protections or storing credentials. Recommend solo-owner approval: apple-credentials allows exactly the main branch, the personal repository owner is the sole required reviewer, and self-review is allowed. Confirm the authenticated GitHub owner. Explain that this is owner approval rather than independent review.

4. In that plan, confirm Developer Program team 9L6Y9T3PPW (Individual membership), existing bundle ID com.asaschaeffer.starterappdemo and existing App Store Connect record Starter App Template Demo. The existing team API key with Admin role is a candidate, not yet approved. Confirm its securely stored .p8 is available outside the checkout without displaying its contents. Do not create, broaden, replace or revoke keys automatically. If unavailable, present the next human step instead of inventing credentials.

5. After explicit approval for policy, credential transfer and authenticated reads, configure and verify the chosen protections and use scripts/bootstrap-apple-credentials.py with --approval-policy solo-owner (or the approved alternative). Never ask for secrets in chat or expose them in arguments, logs, screenshots, source or artifacts. Verify secret names only. Run the main-branch Apple diagnostics workflow for starter-app-demo with account reads enabled; use the pinned wrapper, and treat inaccessible checks as unknown.

6. Before dispatching signing, get explicit approval for automatic signing of that existing app: Xcode may create/update its App Store provisioning profile and create a distribution certificate if needed. No duplicate app records/identifiers, unrelated capability changes, revocation or TestFlight upload. Only after diagnostics and approval, dispatch Signed archive validation on main with starter-app-demo and perform_signing enabled. Inspect the actual sanitized archive validation result, not just a green job; stop on failures or unexpected account changes.

Record Windows-specific friction, reproducible fixes, tool versions, commit/run links and remaining uncertainty in docs/setup-experience.md. Commit documentation fixes in reviewable changes. Keep milestone 5 open until a real archive passes; TestFlight implementation and iPhone installation are milestone 6. Xcode runs on GitHub, and a separately managed Mac is not required. Finish with completed actions, verification evidence and any precise human decision still needed.
```
