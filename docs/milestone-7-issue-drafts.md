# Milestone 7 issue drafts

GitHub issue creation returned HTTP 401 on 2026-10-12. These drafts are not published issues. Publish from an authenticated GitHub session, check for duplicates first, then replace this file with links in the roadmap.

## Release symbols and hosted symbolication

Milestone 7 needs exact-build symbols to investigate iPhone crashes from Windows. The current export policy requests symbol upload, but delivery deletes its archive and retains no dSYMs. Actual Release dSYM production has not been inspected.

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
