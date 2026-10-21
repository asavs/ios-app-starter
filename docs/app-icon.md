# App icon

The app icon is one Icon Composer document, `StarterApp/StarterApp/AppIcon.icon`. It is the only icon source: there is no asset catalog icon, no PNG and no generator.

The template's placeholder is Apple's own Icon Composer demo icon (three overlapping circles) on Apple's app icon guide grid, the grid with three concentric circles and two diagonals that Xcode shows for a missing icon and Icon Composer overlays while you edit. The demo is copied unchanged from the *Icon Composer Demo Project* in the iOS 27 Icon Templates on [Apple Design Resources](https://developer.apple.com/design/resources/). It is Apple's reference for a correctly built document, so it is kept byte for byte rather than redrawn. The grid, `Assets/0.grid.svg`, is Apple's `appicongrid.ios.svg` from Icon Composer's bundle (`IconComposerKit.framework`), also unchanged. `Assets/0.grid-dark.svg` is the same file with only the stroke colour changed to white, because black lines vanish in the dark, tinted and clear appearances (Apple's Dark Mode guidance: if an asset looks good in only one mode, provide separate light and dark assets). The only other addition is a fourth group at the back of `icon.json` that shows the grid with glass off, choosing the file per appearance with `image-name-specializations`. Keep the grid while you position your own layers on it, then delete it and its group. It is covered by the Apple Design Resources license, kept in [`third_party/apple-icon-composer-demo/`](../third_party/apple-icon-composer-demo/): use it for mock-ups while you build, and replace it with your own icon before you ship. It uses iOS 27 refraction, so it needs Xcode 27 (or Icon Composer 27) to build or render; Xcode 26 fails with "Could not open “AppIcon.icon”". CI builds with Xcode 27. You can edit it on a Mac in Icon Composer, or by hand on any platform, and review it from Windows through the previews that CI renders on each run.

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

- **Layers** are flat, opaque artwork on a transparent square canvas (1024 × 1024 for iPhone, iPad and Mac; Apple's demo layers are 512 × 512 and scale). They carry no shading, shadow, blur or transparency: Apple's guide says to set those in Icon Composer. Name them with numbers that increase from back to front.
- **Groups** in `icon.json` stack the layers, front first; use at most four. Each group sets the material that the system draws: `specular`, `shadow` (`neutral` or `layer-color`, with `opacity`), `translucency`, `blur-material`, `lighting` (`individual` or `combined`) and, from iOS 27, `refractivity` (`enabled`, `depth`, `strength`, with `"features": ["refractivity"]` at the top level). Any of these can vary by appearance with a `-specializations` list, as the demo does for shadows and translucency in dark mode.
- **Layer settings** within a group: `image-name` (a file under `Assets/`), `name`, `glass` (Liquid Glass; on unless set to `false`), `opacity`, `blend-mode` and an optional `fill` that recolours the layer: `automatic` (the SVG's own colour), `none`, a `solid` colour or a `linear-gradient`. The demo uses `fill-specializations` to give each layer grey fills in the tinted appearance.
- **The background** is either one `fill` for every appearance (the demo uses Icon Composer's `system-light` preset, which adapts to dark mode) or `fill-specializations`: one entry without `appearance` for light mode and one with `"appearance": "dark"`, for example `automatic-gradient` colours.
- **`supported-platforms`** is `{"squares": "shared"}` for iPhone, iPad and Mac; the demo adds `"circles": ["watchOS"]`.

XcodeGen picks the document up from the target's sources as an icon resource, so `project.yml` needs no entry beyond `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`. `actool` compiles the document into the iOS 26 layered icon and into the `AppIcon60x60@2x.png` and `AppIcon76x76@2x~ipad.png` fallbacks for the iOS 17 minimum. The TestFlight release checks that those fallbacks exist in the built app.

## From Windows, start to upload

No Mac and nothing extra to install in the repository: draw with a tool you already have, put the files in `AppIcon.icon`, and let CI and TestFlight do the rest.

**1. Draw it.** Apple's [App Icon Template for Figma](https://www.figma.com/community/file/1645923469870515372/app-icon-template-ios-ipados-and-watchos-27) runs in the browser and has the grid and canvas; Inkscape, Affinity or Illustrator work too. Use a 1024 × 1024 canvas, keep the main shape centred, and don't draw the rounded corners, shadows or glass: the system adds them.

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

  The system still tints it and draws the clear look, but a flat image has no separate dark version and no glass depth.
- *Layers (Liquid Glass).* Export each layer as its own SVG on the full 1024 × 1024 frame, numbered from back to front (`1.background-shape.svg`, `2.symbol.svg`, …). In Figma, export the frame once per layer with the other layers hidden. Replace the files in `Assets/`, then edit `icon.json`: keep one group per layer (at most four), point each `image-name` at your files, and set the background `fill` and any per-appearance colours. The template's own `icon.json` is a working example of every setting; [What is in the document](#what-is-in-the-document) explains them.

Either way, delete `third_party/apple-icon-composer-demo/` once Apple's demo is gone.

**3. Check it.** `python scripts/check-app-icon.py` names a missing file, a stray file or a missing background.

**4. See it.** Push a branch and open a pull request. The iOS workflow renders previews with Icon Composer under `icon/` in the `ios-test-results-starter` artifact (`gh run download <run-id> -n ios-test-results-starter -D build/ci-results`).

**5. Ship it.** After the pull request merges, `python scripts/deliver_testflight.py --configuration starter` builds the app with the icon and uploads it ([TestFlight delivery](testflight-delivery.md)). The release refuses a build without a compiled icon. Check it on the home screen in light, dark and tinted modes.

## Editing it

### In Icon Composer (Mac)

Icon Composer is bundled with Xcode 26 and later at `Xcode.app/Contents/Applications/Icon Composer.app`, and is also available as a separate download. Open `AppIcon.icon`, edit it, save, and commit `icon.json` together with any changed `Assets/`. The demo was saved by Icon Composer, so a save produces a diff of only what you changed. Apple's templates for Figma, Sketch, Photoshop and Illustrator on [Apple Design Resources](https://developer.apple.com/design/resources/) have the current grid and canvas for drawing layers; Icon Composer can also overlay that grid while you edit.

### By hand (any platform)

1. Draw or edit the layer as an SVG on a square `viewBox` (1024 × 1024), opaque, and put it in `Assets/`. Keep the main shape centred, because the system rounds the corners. Convert text to outlines.
2. Add a layer to a group in `icon.json` whose `image-name` is the file name. Every file in `Assets/` must belong to a layer.
3. Keep the keys sorted and written with `" : "` between key and value, as Icon Composer writes them, so that a later save from Icon Composer produces a small diff.
4. Run the check:

   ```bash
   python3 scripts/check-app-icon.py
   ```

   It reports a missing or unreferenced asset, invalid JSON, an empty group or a missing background (a `fill`, or both a light and a dark fill specialization), and names the fix for each problem. It runs on Windows, Linux and macOS, and the portable CI job runs it on every pull request.

## Seeing the result

**On a Mac with Xcode 27**, render the previews:

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

**On the phone**, `scripts/run-on-device.sh` installs a build in about a minute from a Mac with Xcode 27 (see [agent onboarding](agent-onboarding.md)); without a Mac, or with Xcode 26, use a TestFlight build from CI. Check the home screen in light, dark and tinted modes, because a preview at 1024 px hides problems that show at 60 pt.

## Pitfalls we hit

- **A malformed document gives no detail.** `ictool` reports only "The data couldn't be read because it isn't in the correct format" and exit with status 255. Run `check-app-icon.py` first, because it names the problem.
- **No dark fill means a black icon.** Without a `"appearance": "dark"` fill specialization, the Dark rendition paints the background black and fills enclosed shapes (such as the inside of a dashed circle) with the light colour. The check requires a dark fill for this reason.
- **Per-appearance files need the default listed too.** A layer that changes its file by appearance must list the default as an entry without `appearance` inside `image-name-specializations`, with no separate `image-name`. With `image-name` plus dark-only specializations, `ictool` ignores the dark file.
- **Keep features in every appearance.** Apple's guide asks for the same core features in default, dark, clear and tinted. Render all six (`Default`, `Dark`, `TintedLight`, `TintedDark`, `ClearLight`, `ClearDark`) before committing; a black or very dark layer disappears in all but the first.
- **A solid layer fill fills every shape.** A `solid` or gradient `fill` recolours the whole layer, including the inside of circles drawn with `fill:none`, so a line drawing becomes discs. To show line art in another colour, change the stroke colour in the SVG instead.
- **Glass gives an edge a hard rim.** A layer with Liquid Glass gets a lit rim on all its edges, which ruins a shape meant to fade out. Apple's guide says the same from the other side: prefer clearly defined edges, and avoid soft or feathered ones.
- **There is no angular gradient.** The format offers `linear-gradient` layer fills and `automatic-gradient` backgrounds, not conic gradients.
- **Refraction needs Xcode 27.** `refractivity` is an iOS 27 setting. Icon Composer 1.6 and `actool` from Xcode 26 refuse the whole document (`actool` crashes with "attempt to insert nil object"). On Xcode 26.6 the trigger is the top-level `"features": ["refractivity"]`: without it the same document compiles. `scripts/run-on-device.sh` stops before building when the icon mentions `refractivity` and the selected Xcode is older than 27. To build locally with Xcode 26, remove `refractivity` from `features` and from each group, and accept the iOS 26 look; otherwise install Xcode 27.
- **macOS previews can show SVG layers wrong.** Finder, Quick Look and NSImage rendered white-on-transparent layers as solid black. Judge the icon by the `ictool` renders, not by file previews.
- **Keep one icon source.** Don't add an `AppIcon.appiconset` next to the document. The fallback PNGs for iOS 17 already come from the `.icon`.

## For an app created from the template

A new app gets its own placeholder: the same discs on the guide grid, with its own colours and arrangement. Run this once after setting the app identity, on any platform:

```bash
python3 scripts/personalize-icon.py
```

It rewrites only `icon.json`: each disc gets a random colour (a dimmer one for dark mode; Apple's grey tinted variants stay), and the three discs are re-arranged at Apple's 154-point spacing along one of the grid's guide lines (vertical, horizontal or diagonal), in a random order and stacking. Apple's SVGs are not changed; positions are group `position` translations. It prints its seed: run it again for another look, or pass `--seed <n>` to repeat one. Then run the check and look at the previews as above.

Replace the placeholder with your real icon before the first App Store submission: on Windows follow [From Windows, start to upload](#from-windows-start-to-upload); on a Mac, Icon Composer does the same. Delete `third_party/apple-icon-composer-demo/` once the demo is gone.
