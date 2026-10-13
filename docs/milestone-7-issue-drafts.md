# Milestone 7 issue drafts

**Priority revised 2026-10-13:** Follow [the shared order](mac-windows-coordination.md). Demonstrate ordinary TestFlight feedback through the browser first. The symbolication, CLI export and performance ideas below are conditional backlog, not mandatory prerequisites. OS coverage remains required.

GitHub issue creation returned HTTP 401 on 2026-10-12. These drafts are not published issues. Publish from an authenticated GitHub session, check for duplicates first, then replace this file with links in the roadmap.

## Release symbols and hosted symbolication

Milestone 7 needs exact-build symbols to investigate iPhone crashes from Windows. The export policy requests symbol upload. Commit `33ffe9e` adds UUID verification and optional private-repository dSYM retention; Windows reported hosted archive matching in PR #22. Exported-IPA matching, public-demo private storage and hosted symbolication remain open.

Acceptance:
- Inspect fresh hosted Release settings and distributed binary/dSYM UUIDs.
- Preserve matching symbols with a reviewed access/retention policy; keep credentials, profiles and signed packages out of public artifacts.
- Provide a hosted macOS symbolication path for a supplied report; reject UUID mismatches and identify missing OS symbols.
- Verify using synthetic or explicitly approved diagnostic data and inspect Windows-readable outputs.

Design: docs/device-diagnostics.md. No live crash collection or symbolication has been verified. Depend on the milestone 6 acceptance documentation landing; do not require an owned Mac.

## TestFlight feedback and performance assessment

Add a Windows-accessible milestone 7 feedback loop for the exact TestFlight app/build. Pinned asc 5.14.0 documents crash/feedback reads, but the template has no supported diagnostic wrapper and account access/data availability are unverified.

Acceptance:
- Verify pinned command help and API permissions; implement fixed opt-in reads using existing isolated credential conventions.
- Distinguish denied, skipped, incomplete and successful-empty results; paginate and filter by app/build.
- Keep raw feedback, screenshots, identity and crash text out of public logs/artifacts. Provide a reviewed download/access policy and sanitized summaries.
- Document beta description, What to Test, version/build/device OS and reproduction steps; preview metadata edits separately from tester notifications/invitations.
- Inspect a controlled real feedback export from Windows after explicit account-read approval; add meaningful error/redaction checks.
- Assess aggregate performance report availability and limits without promising live per-iPhone traces. Optional MetricKit remains a separate feature.

Design: docs/device-diagnostics.md. Symbolication depends on matching symbols. No account mutation or new tester invitation is authorized by this issue.

## Minimum-OS runtime coverage

Milestone 7 must establish runtime evidence for the declared iOS 17 minimum. Current hosted smoke tests run on iOS 27.0 only; the accepted physical iPhone OS is unknown.

Acceptance:
- Inventory actual Xcode/SDK/simulator availability on hosted runners and document a feasible minimum-OS lane/toolchain.
- Run meaningful smoke checks on the minimum OS before claiming verified compatibility; add iOS 18/26 lanes only where provisioned.
- Publish actual runtime identity, counts and coverage gaps in Windows-readable reports.
- Keep new toolchain checks separate from established runtime coverage; document unavailable lanes honestly.
- Record physical device OS/build during the next authorized acceptance loop.

Design: docs/device-diagnostics.md. Do not advance milestone 8 until milestone 7 required checks pass.

## CI review and iteration backlog

This reporting enhancement is separate from milestone 7's device-diagnostics acceptance. Milestone 2's original reporting gate remains complete.

- Provide a compact Windows-accessible review command or Actions summary combining PR and exact post-merge results by configuration.
- Include artifact-derived test counts, simulator runtime, app identity, archive symbol UUIDs and direct artifact/log links. Distinguish archived-app matching from exported-IPA matching.
- Label signing/account/delivery skips as policy skips; never treat them as verified operations.
- Compare the checkout commit/branch with the PR head before reviewing local source. Fetch artifacts on request and keep routine output small and sanitized.
- Use [issue #20](https://github.com/asavs/ios-app-starter/issues/20) for a targeted manual simulator lane; preserve all three required PR/main configurations.
- Cancel superseded PR runs with event-aware concurrency; preserve main verification and protected delivery serialization.
- Measure cold/warm costs before changing build-output caching or eliminating repeated preflights. Exact merge-commit simulator evidence remains required.

Acceptance: inspect successful and deliberately failed evidence from Windows, verify skip/scope labels and checkout mismatch detection, and show reduced review friction without weakening required coverage. The consolidated review command and targeted lane have passed functional Windows acceptance (PRs #23/#24). End-to-end development speed remains unresolved; Windows tracks queue, execution, review and handoff time during the tester feedback task.
