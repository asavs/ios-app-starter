# Give your app its own icon

Your app's icon is `StarterApp/StarterApp/AppIcon.icon`. Edit it in Icon Composer on a Mac, or edit its artwork and settings by hand on any platform; CI renders previews you can view from Windows. For a distinct placeholder while you build, use [the personalization command](#for-an-app-created-from-the-template).

The `.icon` document is the only icon source. There is no asset catalog icon, PNG or icon generator; Xcode compiles the icons and PNG fallbacks from the document.

## Placeholder artwork and license

The placeholder is Apple's Icon Composer demo icon, three overlapping circles, copied byte for byte from the *Icon Composer Demo Project* in the iOS 27 Icon Templates on [Apple Design Resources](https://developer.apple.com/design/resources/). It is Apple's reference for a correctly built document.

Behind it sits Apple's app icon guide grid (three concentric circles and two diagonals), the same grid Xcode shows for a missing icon. `Assets/0.grid.svg` is Apple's unchanged `appicongrid.ios.svg` from Icon Composer's bundle (`IconComposerKit.framework`). `Assets/0.grid-dark.svg` changes only the stroke to white so the lines stay visible in dark, tinted and clear appearances, following Apple's Dark Mode advice to provide separate assets when one cannot serve both.

The grid is the only addition: a fourth group at the back of `icon.json`, with glass off, choosing its file per appearance through `image-name-specializations`. Keep it while positioning your layers, then delete it and its group.

The artwork is covered by the Apple Design Resources license in [`third_party/apple-icon-composer-demo/`](../third_party/apple-icon-composer-demo/). Use it for mock-ups and replace it before shipping. Its iOS 27 refraction needs Xcode 27, which CI uses; see [the refraction pitfall](#pitfalls-we-hit).

## What is in the document

An `.icon` document is a folder:

```text
AppIcon.icon/
  icon.json          fills, groups, layers and their effects
  Assets/
    0.grid.svg       Apple's guide grid (1028 × 1028: 1024 plus the line width)
    0.grid-dark.svg  the same grid in white, for dark, tinted and clear
    1.circle.svg     one flat SVG (or PNG) per layer, numbered back to front
    2.circle.svg
    3.circle.svg
```

- **Layers** are flat, opaque artwork on a transparent square canvas (1024 × 1024 for iPhone, iPad and Mac; Apple's demo layers are 512 × 512 and scale). No shading, shadow, blur or transparency: Apple's guide sets those in Icon Composer. Number them from back to front.
- **Groups** in `icon.json` stack the layers, front first, at most four. Each sets the material the system draws: `specular`, `shadow` (`neutral` or `layer-color`, with `opacity`), `translucency`, `blur-material`, `lighting` (`individual` or `combined`) and, from iOS 27, `refractivity` (`enabled`, `depth`, `strength`; Icon Composer 27 also adds a top-level `"features"` list). Any of these can vary by appearance with a `-specializations` list, as the demo does for dark-mode shadows and translucency.
- **Layer settings** within a group: `image-name` (a file under `Assets/`), `name`, `glass` (Liquid Glass; on unless `false`), `opacity`, `blend-mode` and an optional `fill` that recolours the layer: `automatic` (the SVG's own colour), `none`, a `solid` colour or a `linear-gradient`. The demo uses `fill-specializations` for grey fills in the tinted appearance.
- **The background** is either one `fill` for every appearance (the demo uses Icon Composer's `system-light` preset, which adapts to dark mode) or `fill-specializations`: one entry without `appearance` for light mode and one with `"appearance": "dark"`, for example `automatic-gradient` colours.
- **`supported-platforms`** is `{"squares": "shared"}` for iPhone, iPad and Mac; the demo adds `"circles": ["watchOS"]`.

XcodeGen picks the document up from the target's sources, so `project.yml` needs only `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`. `actool` compiles it into the iOS 26 layered icon plus the `AppIcon60x60@2x.png` and `AppIcon76x76@2x~ipad.png` fallbacks for the iOS 17 minimum, and the TestFlight release checks those fallbacks are in the built app.

## From Windows, start to upload

No local Mac or extra tools needed: draw with what you have, put the files in `AppIcon.icon`, and let CI check and render them. TestFlight delivery needs the account setup and approval in [the delivery guide](testflight-delivery.md).

**1. Draw it.** Apple's [App Icon Template for Figma](https://www.figma.com/community/file/1645923469870515372/app-icon-template-ios-ipados-and-watchos-27) runs in the browser and has the grid and canvas; Inkscape, Affinity or Illustrator work too. Use a 1024 × 1024 canvas, keep the main shape centred, and leave out rounded corners, shadows and glass: the system adds them.

**2. Put it in the document.** Choose one route.

- *One flat image (quickest).* Export the whole icon as one opaque 1024 × 1024 PNG. Delete everything in `AppIcon.icon/Assets/`, save your file there as `1.icon.png`, and replace `icon.json` with:

  ```json
  {
    "fill" : "automatic",
    "groups" : [
      {
        "layers" : [
          {
            "glass" : false,
            "image-name" : "1.icon.png",
            "name" : "1.icon"
          }
        ]
      }
    ],
    "supported-platforms" : {
      "squares" : "shared"
    }
  }
  ```

  The system still tints it and draws the clear look, but you get no separate dark version and no glass depth.
- *Layers (Liquid Glass).* Export each layer as its own SVG on the full 1024 × 1024 frame, numbered back to front (`1.background-shape.svg`, `2.symbol.svg`, …); in Figma, export the frame once per layer with the others hidden. Replace the files in `Assets/`, then edit `icon.json`: one group per layer (at most four), each `image-name` pointing at your file, plus the background `fill` and any per-appearance colours. The template's `icon.json` is a working example; [What is in the document](#what-is-in-the-document) explains each setting.

Either way, delete `third_party/apple-icon-composer-demo/` once Apple's demo is gone.

**3. Check it.** `python scripts/check-app-icon.py` names a missing file, a stray file or a missing background.

**4. See it.** Push a branch and open a pull request. The iOS workflow renders previews with Icon Composer under `icon/` in the `ios-test-results-starter` artifact (`gh run download <run-id> -n ios-test-results-starter -D build/ci-results`).

**5. Ship it.** After the pull request merges, `python scripts/deliver_testflight.py --configuration starter` builds the app and uploads it ([TestFlight delivery](testflight-delivery.md)); the release refuses a build without a compiled icon. Check it on the home screen in light, dark and tinted modes.

## Editing it

### In Icon Composer (Mac)

Icon Composer ships with Xcode 26 and later at `Xcode.app/Contents/Applications/Icon Composer.app`, and as a separate download. Open `AppIcon.icon`, edit, save, and commit `icon.json` with any changed `Assets/`. Because Icon Composer saved the demo, your save diffs only what you changed. For drawing layers, Apple's Figma, Sketch, Photoshop and Illustrator templates on [Apple Design Resources](https://developer.apple.com/design/resources/) have the current grid and canvas, and Icon Composer can overlay that grid while you edit.

### By hand (any platform)

1. Draw or edit the layer as an opaque SVG on a square `viewBox` (1024 × 1024) and put it in `Assets/`. Keep the main shape centred, because the system rounds the corners. Convert text to outlines.
2. Add a layer to a group in `icon.json` with the file name as its `image-name`. Every file in `Assets/` must belong to a layer.
3. Keep keys sorted and written with `" : "` between key and value, as Icon Composer writes them, so a later Icon Composer save produces a small diff.
4. Run the check:

   ```bash
   python3 scripts/check-app-icon.py
   ```

   It reports a missing or unreferenced asset, invalid JSON, an empty group or a missing background (a `fill`, or both a light and a dark fill specialization), with the fix for each. It runs on Windows, Linux and macOS, and the portable CI job runs it on every pull request.

## Seeing the result

**On a Mac with Xcode 27**, render the previews:

```bash
python3 scripts/check-app-icon.py --output build/icon
```

This writes `Default-1024.png`, `Dark-1024.png`, `TintedLight-1024.png` and `Default-120.png` (home-screen size, 60 pt @2x) plus `app-icon.json`, a few seconds per render. The script finds `ictool` through `--ictool`, `$ICTOOL`, the selected Xcode's bundled Icon Composer or `/Applications/Icon Composer.app`. For other appearances, call `ictool` directly:

```bash
ICTOOL="$(dirname "$(xcode-select -p)")/Applications/Icon Composer.app/Contents/Executables/ictool"
"$ICTOOL" StarterApp/StarterApp/AppIcon.icon --export-image --output-file build/icon/ClearDark.png \
  --platform iOS --rendition ClearDark --width 1024 --height 1024 --scale 1
```

Icon Composer 1.6 accepts the renditions `Default`, `Dark`, `TintedLight`, `TintedDark`, `ClearLight` and `ClearDark`. `TintedDark` also takes `--tint-color` and `--tint-strength`.

**From Windows**, open a pull request. The `test (starter)` job of the iOS workflow uploads the same four previews under `icon/` in the `ios-test-results-starter` artifact:

```bash
gh run download <run-id> -n ios-test-results-starter -D build/ci-results
```

**On the phone**, `scripts/run-on-device.sh` installs a build in about a minute from a Mac with Xcode 26 or 27 (see [agent onboarding](agent-onboarding.md)); without a Mac, use a TestFlight build from CI. Only an Xcode 27 build shows refraction. Check the home screen in light, dark and tinted modes: a 1024 px preview hides problems that show at 60 pt.

## Pitfalls we hit

- **A malformed document gives no detail.** `ictool` says only "The data couldn't be read because it isn't in the correct format" and exits 255. Run `check-app-icon.py` first; it names the problem.
- **No dark fill means a black icon.** Without a `"appearance": "dark"` fill specialization, the Dark rendition paints the background black and fills enclosed shapes (such as the inside of a dashed circle) with the light colour. That is why the check requires a dark fill.
- **Per-appearance files need the default listed too.** A layer that changes file by appearance must list the default as an entry without `appearance` inside `image-name-specializations`, with no separate `image-name`. With `image-name` plus dark-only specializations, `ictool` ignores the dark file.
- **Keep features in every appearance.** Apple's guide asks for the same core features in default, dark, clear and tinted. Render all six (`Default`, `Dark`, `TintedLight`, `TintedDark`, `ClearLight`, `ClearDark`) before committing; a black or very dark layer disappears in all but the first.
- **A solid layer fill fills every shape.** A `solid` or gradient `fill` recolours the whole layer, including the inside of circles drawn with `fill:none`, so a line drawing becomes discs. To recolour line art, change the stroke colour in the SVG.
- **Glass gives an edge a hard rim.** A Liquid Glass layer gets a lit rim on every edge, which ruins a shape meant to fade out. Apple's guide agrees: prefer clearly defined edges over soft or feathered ones.
- **There is no angular gradient.** The format offers `linear-gradient` layer fills and `automatic-gradient` backgrounds, not conic gradients.
- **Refraction needs Xcode 27.** Icon Composer 27 writes `"features": ["refractivity"]` when a group uses refraction; keep it as saved. Xcode 27 compiles it; Icon Composer 1.6 and Xcode 26's `actool` refuse a document with that list (`actool` crashes with "attempt to insert nil object"). What Xcode 27 draws comes from the groups' own `refractivity` settings: its `ictool` renders all six appearances byte for byte the same with and without the list. On Xcode older than 27, `scripts/test-ios.sh` (the Xcode 16 and 26 compatibility lanes) and `scripts/run-on-device.sh` build without an app icon and say so.
- **macOS previews can show SVG layers wrong.** Finder, Quick Look and NSImage rendered white-on-transparent layers as solid black. Judge the icon by the `ictool` renders.
- **Keep one icon source.** Don't add an `AppIcon.appiconset` next to the document; the iOS 17 fallback PNGs already come from the `.icon`.

## For an app created from the template

Give a new app its own placeholder, the same discs on the guide grid in its own colours and arrangement. Run this once after setting the app identity, on any platform:

```bash
python3 scripts/personalize-icon.py
```

It rewrites only `icon.json`. Each disc gets a random colour (a dimmer one for dark mode; Apple's grey tinted variants stay), and the three discs are re-arranged at Apple's 154-point spacing along one of the grid's guide lines (vertical, horizontal or diagonal), in random order and stacking, using group `position` translations; Apple's SVGs are untouched. It prints its seed: run it again for another look, or pass `--seed <n>` to repeat one. Then run the check and look at the previews as above.

Replace the placeholder with your real icon before the first App Store submission: on Windows follow [From Windows, start to upload](#from-windows-start-to-upload); on a Mac, use Icon Composer. Delete `third_party/apple-icon-composer-demo/` once the demo is gone.
