# Modules: the versioned library apps are built from

The template is copied once ("Use this template"), so later improvements reach existing apps only through versioned packages. Modules live in this repository as products of one Swift package; the template app depends on it by path, and an app created from the template depends on a tagged version by URL. Backpropagation is a pull request here, a tag, and a version bump in each app.

## Layout

| Piece | Where | Rule |
| --- | --- | --- |
| Manifest | `Package.swift` at the repository root | One package, `StarterModules`, one library product per module. Swift Package Manager resolves a git dependency only from the root manifest and rejects a tagged package that depends on nested path packages, so modules are products, not nested packages. |
| Module | `Modules/<Name>/Sources/` and `Modules/<Name>/Tests/` | Product `<Name>` built from target `<Name>`; test target `<Name>Tests`. UpperCamelCase names. |
| Enablement | `project.yml`, `targets.StarterApp.dependencies` | One `- package: StarterModules` / `product: <Name>` line per enabled module. Remove the line to disable. No second configuration format. |
| Template sources | `StarterApp/StarterApp/` | Reference modules only inside `#if canImport(<Name>)` so the app builds with any subset enabled. `examples/no-modules.yml` is the overlay with everything disabled. |
| Platform minimum | `platforms:` in `Package.swift` | At or below `options.deploymentTarget.iOS`; `scripts/check-modules.py` compares them. macOS is listed only so host-side `swift test` works for host-portable modules. |
| Version | `Modules/TemplateVersion/Sources/TemplateVersion.swift` | `TemplateVersion.modules` equals the git tag that ships it. The welcome screen shows it. |

`scripts/check-modules.py` validates all of this from `swift package dump-package` and the generated project, and writes `modules.json` (modules, enabled, disabled, platforms) that CI uploads with the test results. The `iOS` workflow runs it on every lane.

## Add a module

1. Create `Modules/<Name>/Sources/<Name>.swift` and `Modules/<Name>/Tests/<Name>Tests.swift` (Swift Testing).
2. Add the product and both targets to `Package.swift`, with explicit `path:` values as the existing entries show.
3. Enable it in `project.yml` under `targets.StarterApp.dependencies`, then `bash scripts/generate-project.sh` and commit the regenerated project.
4. Use it in template sources only under `#if canImport(<Name>)`.
5. Run `python3 scripts/check-modules.py`, `bash scripts/test-module.sh <Name>` (simulator) and `bash scripts/test-ios.sh` (app smoke test). `swift test` from the repository root is a fast host-side check when the module compiles on macOS.
6. Open the pull request; the required iOS lane checks the layout and builds the app with the module.

## Test a module

```bash
bash scripts/test-module.sh TemplateVersion            # one module's tests on the iOS simulator
IOS_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 17,OS=26.5' bash scripts/test-module.sh TemplateVersion
swift test                                             # host-side, all host-portable modules
```

Xcode derives a single scheme, `StarterModules`, from the manifest; the script selects one module with `-only-testing:<Name>Tests` and writes the same `summary.md`, `results.json` and log layout as `test-ios.sh`. A per-module CI lane and the required every-module-disabled lane are the next step on the board.

## Release a version

Tags on this repository are module library versions, never app builds. Semantic versions without a `v` prefix, as Swift Package Manager expects.

1. In a pull request, set `TemplateVersion.modules` to the new version and merge.
2. From a clean `main` checkout at the merged commit: `python3 scripts/tag-modules.py 0.2.0`, then the printed `git push origin 0.2.0` (or add `--push`). The script refuses a version that differs from the constant, a dirty tree, another branch, a stale `main`, or an existing tag.
3. Bump `from:` in each app that should receive the change.

## Use the library from an app

An app created from this template starts with the same `Package.swift`, `Modules/` and path dependency. Within one release it should switch to the tagged library (the rule from the master plan: an app may not carry a copy of module code for more than one release):

```yaml
packages:
  StarterModules:
    url: https://github.com/asavs/ios-app-starter
    from: "0.1.0"
targets:
  StarterApp:
    dependencies:
      - package: StarterModules
        product: TemplateVersion
```

Then delete `Package.swift` and `Modules/` from the app, or keep them under a different package name for app-local modules. Xcode writes `StarterApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` for a URL dependency; commit it. To improve a module from inside an app, point the app at a local clone (`path: ../ios-app-starter`) while developing, open the pull request here, tag, and switch back to `url:` with the new version.

## XcodeGen include note

`packages.<name>.path` in the top-level spec is written verbatim, relative to the generated project directory (`StarterApp/`), so the template uses `path: ..`. When a spec includes `project.yml`, XcodeGen rebases that value relative to the including file, which lands one directory too high. Every overlay therefore repeats `packages: StarterModules: path: ..` (see `examples/pocket-notes.yml`), the configuration probes pass an absolute path, and `check-modules.py` fails with a named fix when a generated project's package reference does not resolve to this repository.
