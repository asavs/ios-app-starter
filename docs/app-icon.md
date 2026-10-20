# App icon

The app icon is one Icon Composer document, `StarterApp/StarterApp/AppIcon.icon`. It is the only icon source: there is no asset catalog icon, no PNG and no generator. You can edit it on a Mac in Icon Composer, or by hand on any platform, and review it from Windows through the previews that CI renders on each run.

## What is in the document

An `.icon` document is a folder:

```text
AppIcon.icon/
  icon.json          fills, groups, layers and their effects
  Assets/
    grid.svg         one flat SVG (or PNG) per layer
    construction.svg
    sweep.svg
    radius.svg
```

- **Layers** are flat artwork: white shapes on a transparent 1024 × 1024 canvas. They carry no shading, shadow or colour beyond what you want tinted. Icon Composer adds depth from `icon.json`.
- **Groups** in `icon.json` stack the layers, front first. Each group sets the material that the system draws: `specular`, `shadow` (`neutral` or `layer-color`, with `opacity`), `translucency`, `blur-material` and `lighting`.
- **Layer settings** within a group: `image-name` (a file under `Assets/`), `name`, `glass` (Liquid Glass on or off), `opacity`, `blend-mode` (for example `plus-lighter`) and an optional `fill` that recolours the layer, such as a `linear-gradient` with alpha stops and an `orientation`.
- **`fill-specializations`** set the background: one entry without `appearance` for light mode and one with `"appearance": "dark"`. The template uses `automatic-gradient` colours.
- **`supported-platforms`** is `{"squares": "shared"}` for iPhone and iPad.

XcodeGen picks the document up from the target's sources as an icon resource, so `project.yml` needs no entry beyond `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`. `actool` compiles the document into the iOS 26 layered icon and into the `AppIcon60x60@2x.png` and `AppIcon76x76@2x~ipad.png` fallbacks for the iOS 17 minimum. The TestFlight release checks that those fallbacks exist in the built app.

## Editing it

### In Icon Composer (Mac)

Icon Composer is bundled with Xcode 26 and later at `Xcode.app/Contents/Applications/Icon Composer.app`, and is also available as a separate download. Open `AppIcon.icon`, edit it, save, and commit `icon.json` together with any changed `Assets/`. We have not yet checked that Icon Composer saves this hand-written file unchanged. If saving it rewrites more than you edited, read the diff before committing.

### By hand (any platform)

1. Draw or edit the layer as an SVG on a 1024 × 1024 `viewBox`, in white, and put it in `Assets/`. Keep the important shapes away from the edges, because the system rounds the corners.
2. Add a layer to a group in `icon.json` whose `image-name` is the file name. Every file in `Assets/` must belong to a layer.
3. Keep the keys sorted and written with `" : "` between key and value, as Icon Composer writes them, so that a later save from Icon Composer produces a small diff.
4. Run the check:

   ```bash
   python3 scripts/check-app-icon.py
   ```

   It reports a missing or unreferenced asset, invalid JSON, an empty group or a missing light or dark fill, and names the fix for each problem. It runs on Windows, Linux and macOS, and the portable CI job runs it on every pull request.

## Seeing the result

**On a Mac with Xcode 26 or later**, render the previews:

```bash
python3 scripts/check-app-icon.py --output build/icon
```

This writes `Default-1024.png`, `Dark-1024.png`, `TintedLight-1024.png` and `Default-120.png` (home-screen size, 60 pt @2x) plus `app-icon.json`. Each render takes a few seconds. The script finds `ictool` through `--ictool`, `$ICTOOL`, the selected Xcode's bundled Icon Composer or `/Applications/Icon Composer.app`. For the other appearances, call `ictool` directly:

```bash
ICTOOL="$(dirname "$(xcode-select -p)")/Applications/Icon Composer.app/Contents/Executables/ictool"
"$ICTOOL" StarterApp/StarterApp/AppIcon.icon --export-image --output-file build/icon/ClearDark.png \
  --platform iOS --rendition ClearDark --width 1024 --height 1024 --scale 1
```

Icon Composer 1.6 accepts the renditions `Default`, `Dark`, `TintedLight`, `TintedDark`, `ClearLight` and `ClearDark`. `TintedDark` also takes `--tint-color` and `--tint-strength`.

**From Windows**, push a branch and open a pull request. The `test (starter)` job of the iOS workflow renders the same four previews and uploads them under `icon/` in the `ios-test-results-starter` artifact:

```bash
gh run download <run-id> -n ios-test-results-starter -D build/ci-results
```

**On the phone**, `scripts/run-on-device.sh` installs a build in about a minute from a Mac (see [agent onboarding](agent-onboarding.md)). Check the home screen in light, dark and tinted modes, because a preview at 1024 px hides problems that show at 60 pt.

## Pitfalls we hit

- **A malformed document gives no detail.** `ictool` reports only "The data couldn't be read because it isn't in the correct format" and exit with status 255. Run `check-app-icon.py` first, because it names the problem.
- **No dark fill means a black icon.** Without a `"appearance": "dark"` fill specialization, the Dark rendition paints the background black and fills enclosed shapes (such as the inside of a dashed circle) with the light colour. The check requires a dark fill for this reason.
- **Glass gives an edge a hard rim.** A layer with `glass: true` gets a lit rim on all its edges, which ruins a shape meant to fade out. Leave faded shapes out of glass, as the template does with `sweep`.
- **There is no angular gradient.** The format offers `linear-gradient` layer fills and `automatic-gradient` backgrounds, not conic gradients. Fake a sweep with a linear fade that has alpha stops and `plus-lighter` blending.
- **macOS previews show the SVGs wrong.** Finder, Quick Look and NSImage render these white-on-transparent layers as solid black. Judge the icon by the `ictool` renders, not by file previews.
- **Keep one icon source.** Don't add an `AppIcon.appiconset` next to the document. The fallback PNGs for iOS 17 already come from the `.icon`.

## For an app created from the template

A new app keeps the blueprint sheet until it has its own mark. Replace the layers in `Assets/` and their entries in `icon.json`, keep a light and a dark fill, run the check, and look at the previews. Whether new apps get a per-app placeholder (such as their initial on the sheet) is still being decided. This page will be updated once that is settled.
