# Contributing

This covers changes to the starter itself. To start your own app from it, see the [README](README.md). Agents read [AGENTS.md](AGENTS.md) first; it has the product rules this loop assumes.

## The loop

1. Branch from an up-to-date `main`. If another session has uncommitted work in your checkout, use a separate `git worktree` instead.
2. Make the change. `project.yml` is the source of truth for the Xcode project: edit it, run `bash scripts/generate-project.sh` on a Mac, and commit the regenerated project with it.
3. Run the checks below that apply.
4. Push and open a pull request. Keep it a draft until it is ready, which keeps it off the macOS runners. Then turn on auto-merge: `gh pr merge <number> --auto --merge`.
5. Read the result with `python scripts/review_ci.py --pr <number>`: checks, test counts, tests that only passed on retry, and which runner each job used. Don't poll in a loop; block on `gh pr checks <number> --watch` if you need to wait.
6. If you found something non-obvious (a failure, a workaround, a decision), add an entry at the top of the current `docs/journal/<milestone>.md`. If a step needs a person, add it to `docs/human-steps.md`.

## Checks before pushing

These run anywhere with Python 3:

| When | Command |
|---|---|
| Always | `python -m unittest discover -s scripts/tests` |
| You changed a workflow | `python scripts/lint-workflows.py` (it says when shellcheck isn't installed; CI runs it with shellcheck) |
| You changed UI tests or identifiers | `python scripts/check-ui-identifiers.py` |
| You changed a module's strings | `python scripts/check-module-strings.py` |
| You changed `.claude/skills` or `.agents/skills` | `python scripts/sync-skills.py` |

On a Mac with Xcode 27 you can also run what CI runs:

| What | Command |
|---|---|
| One CI lane | `IOS_TEST_LANE=shell bash scripts/test-ios.sh` (or `features`, `tabs`, `identity`) |
| Everything | `bash scripts/test-ios.sh` |
| One module's tests | `bash scripts/test-module.sh <Module>` |
| The app on your iPhone | `bash scripts/run-on-device.sh` ([docs/ci.md](docs/ci.md#run-on-your-iphone-from-a-mac)) |

A pull request runs the demo configuration on GitHub's runners. Pushes to `main` run the other configurations, on the owner's Mac when that runner is switched on. [docs/ci.md](docs/ci.md) explains both and how to read a failure.

## Writing

Swift follows the pinned skills listed in AGENTS.md (`write-swift`, `swiftui-pro`, `swift-testing-pro` and the rest). UI tests use the helpers in `StarterUITestCase`; AGENTS.md says which. Docs, pull request descriptions and interface copy go through the `humanizer` skill: plain sentences, the reason for a change before its mechanics.
