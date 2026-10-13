# Mac and Windows coordination

This is the shared execution plan agreed on 2026-10-12. Read it with [the roadmap](../roadmap.md), [agent instructions](../AGENTS.md), and [setup evidence](setup-experience.md). Milestone 7 remains open. The milestone 2 reporting gate is complete, but improving reporting comes first because it makes every subsequent change cheaper to verify.

## Assignment rule

For each task ask: can Xcode or this Mac produce useful tooling, artifacts or evidence that future template users can obtain through the repository? If so, implement that reusable work here. Delegate substantial Windows-specific work to the Windows agent; complete quick fixes where they are discovered. GitHub-hosted macOS remains the required native build environment. Local Mac evidence supplements hosted checks.

## Execution and commit order

Each row can require several focused commits. Finish its acceptance before advancing; do not bundle unrelated changes. Existing symbol work remains valid even though reporting now takes priority.

| Order | Task | Mac implementation | Windows acceptance | Completion evidence |
| --- | --- | --- | --- | --- |
| 1 | Consolidated CI evidence | Inspect native report formats; implement portable review command and useful Actions summaries | Exercise from PowerShell; verify downloads, links, scope labels and checkout mismatch detection | Actual counts, runtime, app identity and symbol UUIDs grouped by configuration; PR and exact merge-commit results; policy skips distinct from passes; archive matching distinct from IPA matching; controlled success/failure review |
| 2 | Faster iteration | Add one-configuration manual simulator lane and event-aware cancellation of superseded PR runs | Dispatch targeted lane; confirm full required PR/main coverage remains | Manual result names selected configuration; three required lanes preserved; obsolete PR run cancellation demonstrated; main/protected release work preserved |
| 3 | Complete symbol retention | Implement reviewed private storage for the public demo and native UUID checks | Retrieve symbols and identify exact build; inspect storage access | Matching app/dSYM and exported-IPA UUIDs; documented access/retention; package comparison during next authorized delivery |
| 4 | TestFlight crash/feedback export | Inspect pinned CLI/API surface; implement fixed portable opt-in reads and sanitized reports | Verify installer, authorized reads and local report handling | Denied/skipped/incomplete/empty results distinct; pagination/build filters verified; controlled feedback export readable from Windows |
| 5 | Device investigation loop | Implement hosted macOS symbolication with UUID checks | Coordinate owner iPhone feedback; retrieve and interpret diagnostic outputs | Report tied to exact version/build/device OS; matching symbols; reproducible investigation; missing OS symbols stated |
| 6 | OS runtime coverage | Inspect available native runtimes/toolchains and implement feasible hosted lanes | Verify reports accurately describe tested coverage | Minimum-OS execution evidence before compatibility claims; actual runtime/test totals; unavailable coverage documented |
| 7 | Performance assessment | Assess Apple reports; implement optional MetricKit only for an identified gap | Verify report accessibility and usefulness | Actual data availability/latency/thresholds stated; aggregates distinguished from per-device traces; optional collection has reviewed privacy/storage design |

Issue [#20](https://github.com/asavs/ios-app-starter/issues/20) already tracks targeted iteration. Check existing issues/PRs before opening duplicates. Repository task records are sufficient to proceed; publishing an issue is not a gate.

## Communicate through GitHub

1. Fetch before starting. Compare local branch/commit with the named PR head or main commit; never assume a checkout is current. Preserve unrelated work and use a task branch.
2. Read this file and the latest setup journal entries. Announce the exact task ownership in a committed update or the relevant PR comment. Avoid simultaneous edits to the same files; each side owns its implementation or acceptance branch.
3. The implementing agent pushes a reviewable branch and records a handoff with commit, PR, changed files, exact commands, expected artifacts, checks already completed and remaining acceptance. Do not claim a task is complete merely because code was pushed.
4. The receiving agent reads the GitHub revision, runs the specified acceptance, inspects actual artifacts, and posts a result tied to commit/run links. Update the journal for meaningful friction, fixes and uncertainty. Use a small documentation PR when acceptance evidence needs to enter the repository.
5. The original agent fetches and reads that response before continuing dependent work. Merge only after required checks and evidence review; inspect exact post-merge results too. Keep task state current below.

No automatic agent-to-agent messaging service is implemented. Agents exchange committed handoffs, PR comments and evidence through GitHub when their sessions are active; the user can point the other session to the relevant link. Never include secrets, raw account responses, tester identity or private crash content in this public coordination record.

## Handoff format

Use this compact format for each task; update status from implementation to awaiting acceptance, verified, or blocked with a concrete cause.

- Task/order and owner:
- Branch, commit and PR:
- Implemented behavior and changed files:
- Commands and artifact names for the other agent:
- Evidence already reviewed, with run links:
- Remaining acceptance and known limits:
- Result/next action, with responsible side:

## Current handoff

- **Current task:** Order 1, consolidated CI evidence. Implementation is on `codex/ci-evidence-review`, based on merged main `09ad9d5`; shared handoff documentation commits were carried forward as `bb2d3d0` and `02f0cca`.
- **Implemented:** `scripts/review_ci.py` combines PR checks, elapsed times, skip states, test/app/symbol evidence, artifact run links, checkout/head comparison, and workflows/artifacts for the exact merge commit. The iOS and TestFlight summaries now show compiled identity and archive/dSYM UUID evidence with run links. `README.md` documents the Windows command.
- **Windows verification command:** `python scripts/review_ci.py --pr <number>`; use `--no-download` to review check states/links only and `--require-checkout-head` to fail when local `HEAD` differs from the PR head. It reads only selected sanitized fields from recognized artifacts and downloads them to a temporary directory.
- **PR acceptance:** [PR #23](https://github.com/asavs/ios-app-starter/pull/23), head `683879d`, passed portable Windows/Linux/macOS, signing preflight, TestFlight preflight, and all three iOS lanes. Windows command `python scripts/review_ci.py --pr 23` reported exact checkout/head `MATCH`, check durations, policy skips, and downloaded sanitized evidence. Each app ran one UI assertion on iOS 27.0 (1 passed, 0 failed/skipped), with expected bundle IDs, iOS 17 minimum and iPhone/iPad families. The TestFlight report matched the archive app/dSYM UUID `B3197B45-3C86-36B4-91A4-6EC891966551` (`arm64`); no IPA comparison was run. The rendered iOS and TestFlight job summaries were visually inspected on the GitHub Actions pages and show counts, runtime, compiled app identity, UUID and run/artifact links.
- **Existing-PR exercise:** The same command reviewed [PR #22](https://github.com/asavs/ios-app-starter/pull/22) plus exact merge `09ad9d5` and correctly flagged checkout mismatch. It showed all three PR and main simulator reports as 1/1 passed and archive UUID/policy skips. The full portable suite passes locally on Windows: 54 tests, 3 platform/dependency skips.
- **Known boundary:** TestFlight preflight's symbol report verifies archive app/dSYM matching. It does not verify an exported IPA. Do not dispatch signing or upload for reporting acceptance; `retain_symbols` remains off for this public repository.
- **Next action:** Review and merge PR #23 when authorized, then run `python scripts/review_ci.py --pr 23` again to inspect the exact merge-commit workflows/artifacts. Keep order 1 open until post-merge evidence is reviewed. Do not begin order 2 before order 1 acceptance is complete.

## Approval boundaries

Existing authorization persists. Native implementation and credential-free review can proceed. Present a concrete scope before new authenticated Apple reads, private symbol-storage access changes or delivery. Owner compliance decisions and iPhone acceptance remain human steps. Keep PR builds unsigned and secretless; never change repository visibility to enable retention. Performance collection must not impose a backend on the basic starter.
