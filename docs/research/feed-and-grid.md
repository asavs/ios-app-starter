# Vertical feeds and image grids

Checked 2026-10-31. Research only; no module, package dependency or app feature is proposed for release. The starter minimum is iOS 17.0. A means Apple documentation, HIG or WWDC; B means inspected open-source implementation. Recommendations below are design proposals, with no compiled or device-tested implementation behind them.

## Recommendation

Wait for an app to request a photo grid or paging feed before building a module. iOS 17 already supplies the layout and paging primitives. Image loading has the most reusable work: thumbnail decoding, request sharing, cancellation and bounded caching. If a real app needs that work, start with a small image loader. Extract a grid or pager only after its interactions and accessibility requirements are clear.

Keep video playback policy separate from page layout. A lazy stack does not by itself bound retained players, buffers or image tasks. A future feed needs explicit resource ownership, accessible playback controls and an app decision about autoplay. It also needs measurements on the minimum supported OS and a phone; a successful build with the latest SDK cannot establish those behaviors.

## Photo grid

### Layout and iOS 26

`LazyVGrid` (iOS 14) creates cells as needed. `Grid` and `GridLayout` (iOS 16) create children eagerly and offer stronger alignment across rows and columns; `GridLayout` also works with `AnyLayout`. Apple recommends starting with `Grid` and switching when profiling shows eager creation is too costly. A large photo library is a good candidate for `ScrollView` plus `LazyVGrid`; a short, bounded set can use `Grid`. Laziness does not free images held elsewhere by the app. ([LazyVGrid, A](https://developer.apple.com/documentation/swiftui/lazyvgrid), [Grid, A](https://developer.apple.com/documentation/swiftui/grid), [GridLayout, A](https://developer.apple.com/documentation/swiftui/gridlayout))

The iOS 26 changes relevant here are improved scrolling performance, deferred loading for nested lazy stacks and the new scroll-edge treatment. WWDC25 also introduces spatial layout for visionOS. These are not a reason to replace the iOS 17 photo-grid design: no replacement photo-grid container was identified in these sources. `scrollEdgeEffectStyle(_:for:)` itself requires iOS 26. ([What's new in SwiftUI, WWDC25, A](https://developer.apple.com/videos/play/wwdc2025/256/), [scroll edge style, A](https://developer.apple.com/documentation/swiftui/view/scrolledgeeffectstyle(_:for:)))

Use `GridItem(.adaptive(minimum:maximum:))` to fit columns to available width, including iPad window resizing. The minimum is a layout value, not an automatic Dynamic Type rule. For tiles with captions, scale it with `@ScaledMetric` (iOS 14), allow multiline text and consider one column at accessibility sizes. For an image-only contact sheet, enlarged captions or a separate list presentation may serve people better than uniformly enlarging every tile. Choose through testing; do not clamp Dynamic Type to preserve the column count. ([adaptive grid items, A](https://developer.apple.com/documentation/swiftui/griditem/size-swift.enum/adaptive(minimum:maximum:)), [ScaledMetric, A](https://developer.apple.com/documentation/swiftui/scaledmetric))

### Thumbnails and interaction

An aspect-fill thumbnail uses a resizable image, `.aspectRatio(contentMode: .fill)`, a bounded frame and `.clipped()`. Define `.contentShape(Rectangle())` on the bounded cell for hit testing as well. Clipping controls drawing; the explicit interaction shape keeps taps within the intended tile. Request thumbnail pixels for that frame and display scale rather than downloading full-resolution images solely to shrink them during rendering. ([clipped, A](https://developer.apple.com/documentation/swiftui/view/clipped(antialiased:)), [contentShape, A](https://developer.apple.com/documentation/swiftui/view/contentshape(_:eofill:)))

`LazyVGrid` has no selection binding. Keep selected stable item IDs in app state, and make each cell an accessible button with a visible checkmark and the selected accessibility trait. A Select/Done mode should distinguish opening a photo from selecting it; selection must survive cell recreation and data reordering. Announce a useful selected count after a batch action. `List(selection:)` supports a single ID or a set, but that selection system is not inherited by a lazy grid. ([LazyVGrid, A](https://developer.apple.com/documentation/swiftui/lazyvgrid), [List selection, A](https://developer.apple.com/documentation/swiftui/list))

For Photos-style two-finger pan selection, UIKit exposes `collectionView(_:shouldBeginMultipleSelectionInteractionAt:)` from iOS 13. SwiftUI does not expose that collection-view delegate on `LazyVGrid`. If the app needs the native gesture and selection behavior, evaluate a `UICollectionView` wrapper before implementing drag selection with cell geometry and competing scroll gestures. A custom gesture must still have a tap and VoiceOver alternative. ([multiple selection interaction, A](https://developer.apple.com/documentation/uikit/uicollectionviewdelegate/collectionview(_:shouldbeginmultipleselectioninteractionat:)))

`contextMenu(menuItems:preview:)` and `draggable(_:)` are available from iOS 16. Use context menus for secondary actions and expose equivalent accessible actions; essential operations need a discoverable control. A single draggable `Transferable` value does not provide a grid-wide multi-item selection drag contract. Multiple selection, multi-item export, reordering and dropping are separate requirements. Export work must not block the main actor. The iOS 16 `dropDestination(for:action:isTargeted:)` remains a baseline option; the current docs mark it deprecated in iOS 27.2 in favor of a `DropSession` action overload. That later replacement needs its own availability check if adopted. ([context menu, A](https://developer.apple.com/documentation/swiftui/view/contextmenu(menuitems:preview:)), [draggable, A](https://developer.apple.com/documentation/swiftui/view/draggable(_:)), [drop destination, A](https://developer.apple.com/documentation/swiftui/view/dropdestination(for:action:istargeted:)))

## Full-screen paging feed

### iOS 17 baseline and later APIs

Use a vertical `ScrollView` containing `LazyVStack(spacing: 0)`, stable page IDs and `.scrollTargetLayout()`. Size each page with `.containerRelativeFrame([.horizontal, .vertical])`, apply `.scrollTargetBehavior(.paging)` to the scroll view, and bind `.scrollPosition(id:)` to the current item. All of these are iOS 17 APIs. Paging settles on multiples of the scroll container's size; view-aligned scrolling instead aligns to marked views. The target layout lets a lazy container describe targets that have not been created yet. ([scroll target behavior, A](https://developer.apple.com/documentation/swiftui/view/scrolltargetbehavior(_:)), [target layout, A](https://developer.apple.com/documentation/swiftui/view/scrolltargetlayout(isenabled:)), [Beyond scroll views, WWDC23, A](https://developer.apple.com/videos/play/wwdc2023/10159/))

The relative frame subtracts the container's safe-area insets. Decide whether the media extends behind system bars, then give every page the same resulting viewport height. Keep readable captions and controls inside safe areas. Test top and bottom overlays, rotation, iPad resizing, restoration to a non-first item and data insertion; fixed screen dimensions or extra stack spacing can break page alignment. ([containerRelativeFrame, A](https://developer.apple.com/documentation/swiftui/view/containerrelativeframe(_:alignment:)))

The iOS 17 ID binding reports the topmost target as scrolling proceeds. It is not an end-of-deceleration event or proof that a page is fully visible. Do not start audio for every transient ID or use each cell's `onAppear` as proof of visibility. On iOS 17, use a small, measured visibility calculation if the product requires playback only after a page occupies the viewport, and cancel obsolete starts when the candidate changes. ([scrollPosition(id:anchor:), A](https://developer.apple.com/documentation/swiftui/view/scrollposition(id:anchor:)))

| API | First iOS | Use in a feed |
| --- | --- | --- |
| `scrollTransition` | 17 | Optional visual effects as a page enters or leaves; never alter layout size inside the effect. |
| `ScrollPosition` type | 18 | Richer position by ID, offset or edge; distinct from the iOS 17 ID-binding modifier. |
| `onScrollVisibilityChange` | 18 | Per-view visibility threshold; Apple's WWDC24 example starts and pauses video with it. |
| `onScrollTargetVisibilityChange` | 18 | Set of visible target IDs; coordinate centrally to choose one active player. |
| `onScrollPhaseChange` | 18 | Pause or commit playback decisions based on interaction/deceleration/idle state. |
| `accessibilityScrollStatus` | 26 | Customize the spoken description of the current scroll position. |

Availability and contracts: [scroll transition, A](https://developer.apple.com/documentation/swiftui/view/scrolltransition(_:axis:transition:)), [ScrollPosition, A](https://developer.apple.com/documentation/swiftui/scrollposition), [visibility, A](https://developer.apple.com/documentation/swiftui/view/onscrollvisibilitychange(threshold:_:)), [target visibility, A](https://developer.apple.com/documentation/swiftui/view/onscrolltargetvisibilitychange(idtype:threshold:_:)), [phase, A](https://developer.apple.com/documentation/swiftui/view/onscrollphasechange(_:)), [scroll status, A](https://developer.apple.com/documentation/swiftui/view/accessibilityscrollstatus(_:isenabled:)), [What's new in SwiftUI, WWDC24, A](https://developer.apple.com/videos/play/wwdc2024/10144/).

### Playback, preloading and resource limits

Start with AVKit's `VideoPlayer` (iOS 14) for system playback controls. A custom edge-to-edge presentation may need a UIKit host for `AVPlayerLayer` and `videoGravity = .resizeAspectFill`. Aspect fill preserves the ratio but crops the edges; offer fit when cropping would hide meaningful content. A custom player also takes responsibility for play/pause, mute, progress, errors, captions and accessibility. Prefer system controls until the product requires otherwise. ([VideoPlayer, A](https://developer.apple.com/documentation/avkit/videoplayer), [video gravity, A](https://developer.apple.com/documentation/avfoundation/avplayerlayer/videogravity), [Playing video HIG, A](https://developer.apple.com/design/human-interface-guidelines/playing-video))

Proposed starting budget: one active player and at most one prepared neighbor on each side. Three is a tunable budget, not an Apple decoder guarantee. Keep ownership in a coordinator, pause the previous page before starting the next, cancel superseded asset loads, remove observers and detach items beyond the window. A cell appearing or disappearing must not create an unbounded player history. Pause when the scene is inactive, another presentation covers the feed or an interruption requires it. The app owns the audio-session category, silent-switch behavior and whether any background playback is appropriate; see [background audio research](background-audio.md).

Preload only a short next-item window. `AVPlayerItem.preferredForwardBufferDuration` (iOS 10) is a preference: zero lets AVFoundation choose, a low value risks stalls and a high value consumes more resources. `preroll(atRate:completionHandler:)` (iOS 6) prepares playback at the current time, requires a ready player and a current rate of zero, and can fail or be interrupted. Leave `automaticallyWaitsToMinimizeStalling` at its default true unless measured startup requirements justify changing it. These APIs do not promise an instant first frame or a fixed allocation. ([buffer duration, A](https://developer.apple.com/documentation/avfoundation/avplayeritem/preferredforwardbufferduration), [preroll, A](https://developer.apple.com/documentation/avfoundation/avplayer/preroll(atrate:completionhandler:)), [stall avoidance, A](https://developer.apple.com/documentation/avfoundation/avplayer/automaticallywaitstominimizestalling))

Use appropriately sized media variants. `preferredMaximumResolution` (iOS 11) is an HLS-specific preference, not a universal way to resize an MP4 decode. A network buffer is not an offline video cache; persistent downloads, DRM and cache eviction need separate app requirements. ([maximum resolution, A](https://developer.apple.com/documentation/avfoundation/avplayeritem/preferredmaximumresolution))

Measure retained decoded images, player items and peak memory during long fast-scroll sessions, not just the count of visible views. Limit thumbnail and video prefetch on constrained networks and under Low Power Mode, and release idle resources on memory pressure. WWDC25's power example identifies upfront video-thumbnail loading as unnecessary work and demonstrates lazy loading as the remedy. Use Instruments and on-device power measurements to choose budgets; this research establishes no battery advantage for HLS versus MP4. ([Profile and optimize power usage in your app, WWDC25, A](https://developer.apple.com/videos/play/wwdc2025/226/))

### Reduce Motion and VoiceOver

Read `accessibilityReduceMotion` (iOS 13). Keep user-controlled scrolling usable, remove decorative scale/parallax/3D `scrollTransition` effects and avoid animated programmatic jumps when the setting is on. Reduce Motion is separate from media autoplay permission. Read `UIAccessibility.isVideoAutoplayEnabled` (iOS 13), respond when settings change, and provide an app autoplay preference and an always-available pause control. ([Reduce Motion, A](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion), [video autoplay preference, A](https://developer.apple.com/documentation/uikit/uiaccessibility/isvideoautoplayenabled))

Recommended feed policy: default to paused media while VoiceOver is running and let the person start it. `accessibilityVoiceOverEnabled` is available from iOS 15. This policy prevents speech and page audio competing; it is a product recommendation, not an OS requirement that VoiceOver disables video. Keep the page's caption, playback state and controls in a coherent reading order, hide offscreen page controls from accessibility, and provide named next/previous actions or buttons as an alternative to a swipe-only interface. ([VoiceOver environment value, A](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityvoiceoverenabled), [accessibility scroll action, A](https://developer.apple.com/documentation/swiftui/view/accessibilityscrollaction(_:)))

First test the native three-finger scroll announcements: SwiftUI documents a default page-position announcement. From iOS 26, `accessibilityScrollStatus` can supply a meaningful description such as the clip title and position. On iOS 17, a custom scroll implementation can use UIKit's `.pageScrolled` notification after a completed accessibility scroll. Avoid posting a duplicate announcement on every ID change while a finger is moving, and do not claim a finite total for an endless feed. Page position should be distinct from a live playback-time announcement. ([scroll status, A](https://developer.apple.com/documentation/swiftui/view/accessibilityscrollstatus(_:isenabled:)), [pageScrolled notification, A](https://developer.apple.com/documentation/uikit/uiaccessibility/notification/pagescrolled))

## Image loading and caching

### AsyncImage and a small cache

`AsyncImage` is available from iOS 15 and exposes loading, success and failure phases. It is useful for a few simple remote images. Its iOS 17 API does not expose target-pixel downsampling, a decoded-image cache budget, explicit prefetch or request coalescing. Displaying a smaller frame does not establish a smaller decode. Apple's current documentation explicitly promises transport-protocol image-data caching on iOS 27 and later; do not apply that promise to iOS 17 or assert that earlier versions can never use any underlying cache. The request initializer and `asyncImageURLSession(_:)` customization are also iOS 27 additions. ([AsyncImage, A](https://developer.apple.com/documentation/swiftui/asyncimage), [session customization, A](https://developer.apple.com/documentation/swiftui/view/asyncimageurlsession(_:)))

A small loader would separate downloaded bytes from decoded thumbnails. Use a dedicated `URLSession`/`URLCache` for HTTP semantics and an `NSCache` for disposable decoded images. `NSCache` supports concurrent access and may evict under pressure; its cost limit is not a strict resident-memory ceiling. Set byte costs, explicitly purge on memory warnings and bound in-flight work as well. Use an actor or another isolated coordinator for the request registry; the cache's thread safety does not make compound lookup/start/cancel operations atomic. ([NSCache, A](https://developer.apple.com/documentation/foundation/nscache), [totalCostLimit, A](https://developer.apple.com/documentation/foundation/nscache/totalcostlimit), [URLCache, A](https://developer.apple.com/documentation/foundation/urlcache))

Cache keys need asset identity or URL, revision, target pixel dimensions and processing mode. Include an account namespace when media is private, and clear it at sign-out. Coalesce identical work, but cancel a shared download only after its final consumer leaves. Cancel per-cell interest as the requested ID changes; discard late results that belong to a previous cell. Keep prefetch smaller and lower priority than visible work. These are proposed requirements, not behavior supplied by `NSCache`.

### Downsampling with ImageIO

Decode to the required pixel size before storing the thumbnail. Create a `CGImageSource` with `kCGImageSourceShouldCache: false`, then use `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceCreateThumbnailFromImageAlways`, `kCGImageSourceCreateThumbnailWithTransform`, `kCGImageSourceShouldCacheImmediately` and an explicit `kCGImageSourceThumbnailMaxPixelSize`. The transform honors image orientation. Without the maximum-pixel-size option, the thumbnail can be as large as the original. These functions and options predate iOS 17. Perform bounded decoding away from UI work. ([thumbnail creation, A](https://developer.apple.com/documentation/imageio/cgimagesourcecreatethumbnailatindex(_:_:_:)), [source caching, A](https://developer.apple.com/documentation/imageio/kcgimagesourceshouldcache), [immediate decoding, A](https://developer.apple.com/documentation/imageio/kcgimagesourceshouldcacheimmediately), [pixel limit, A](https://developer.apple.com/documentation/imageio/kcgimagesourcethumbnailmaxpixelsize))

Convert points to pixels using the display scale. For aspect fill, size the decode to cover both destination dimensions after orientation: `max(targetWidth / sourceWidth, targetHeight / sourceHeight)` gives the required scale, capped at one. Multiply the source's larger dimension by that scale for the ImageIO maximum. Using only the target's larger dimension can undersample an unusually wide image cropped into a square. A server-generated cropped thumbnail often avoids fetching and decoding that wasted area entirely.

For a rough 8-bit RGBA estimate, a 4,000 by 3,000 image needs 48,000,000 bytes before extra buffers; a 300 by 300 image needs 360,000. Compressed download size does not describe decoded memory. Apple's WWDC18 slides explain the decode/downsample distinction and include the ImageIO approach; the old video page now redirects, but the slides remain hosted by Apple. HDR and other formats can cost more than this four-byte estimate. ([Image and Graphics Best Practices, WWDC18 slides, A](https://devstreaming-cdn.apple.com/videos/wwdc/2018/219mybpx95zm9x/219/219_image_and_graphics_best_practices.pdf))

### What Nuke and Kingfisher do

No dependency is adopted. These are versioned examples, not a recommendation to copy source or inherit their cache budgets.

| Library inspected | iOS 17 fit | Useful implementation choices |
| --- | --- | --- |
| Nuke 13.0.0, MIT | Package minimum iOS 15 | Pipeline coalesces work; a shared operation cancels only when all consumers cancel. Memory images use an LRU cache with a cost budget and memory-warning clearing. Configuration separates the normal HTTP cache from an optional aggressive disk data cache. |
| Kingfisher 8.0.0, MIT | Package minimum iOS 13 | Memory storage wraps `NSCache` with expiration. The image pipeline supports memory/disk caching and prefetching; its downsampler builds a thumbnail directly from encoded data with ImageIO instead of first rendering the full bitmap. |

Nuke evidence: [package minimum, B](https://github.com/kean/Nuke/blob/13.0.0/Package.swift), [pipeline configuration, B](https://github.com/kean/Nuke/blob/13.0.0/Sources/Nuke/Pipeline/ImagePipeline%2BConfiguration.swift), [image cache, B](https://github.com/kean/Nuke/blob/13.0.0/Sources/Nuke/Caching/ImageCache.swift), [license, B](https://github.com/kean/Nuke/blob/13.0.0/LICENSE). Kingfisher evidence: [package minimum, B](https://github.com/onevcat/Kingfisher/blob/8.0.0/Package.swift), [memory storage, B](https://github.com/onevcat/Kingfisher/blob/8.0.0/Sources/Cache/MemoryStorage.swift), [downsampling, B](https://github.com/onevcat/Kingfisher/blob/8.0.0/Sources/Image/Image.swift), [project capabilities, B](https://github.com/onevcat/Kingfisher/tree/8.0.0), [license, B](https://github.com/onevcat/Kingfisher/blob/8.0.0/LICENSE).

A small cache can implement these few needs. Once an app needs progressive decoding, animated formats, many processors or extensive disk-cache policy, compare that maintenance cost with a current library release and audit its license and concurrency behavior again.

## HIG and infinite scrolling

The Collections HIG favors familiar row or grid arrangements for image-based content, adequate spacing and predictable layout changes. Text-heavy results may work better as a list. Do not reorder the collection under someone's finger or VoiceOver focus when another batch arrives. ([Collections HIG, A](https://developer.apple.com/design/human-interface-guidelines/collections))

The Scroll views HIG asks for standard scrolling gestures, an indication that more content exists and care with nested scroll views on the same axis. Page-by-page scrolling is appropriate when content benefits from it. Preserve keyboard and assistive scrolling; a hidden scroll indicator needs some other discoverable way to move through content. ([Scroll views HIG, A](https://developer.apple.com/design/human-interface-guidelines/scroll-views))

The Playing video HIG favors the familiar system player and preserving video aspect ratio. The Accessibility HIG calls for larger text, captions, discoverable start/stop controls and an option to avoid autoplay; Reduce Motion should reduce automatic and repetitive effects. A feed must leave those controls readable over arbitrary imagery and provide touch targets of at least 44 by 44 points on iOS. ([Playing video HIG, A](https://developer.apple.com/design/human-interface-guidelines/playing-video), [Accessibility HIG, A](https://developer.apple.com/design/human-interface-guidelines/accessibility))

For endless content, use a bounded pagination request with a cursor and deduplicate it; a near-end cell can trigger early on iOS 17 because lazy loading prepares views ahead of display. Do not make that trigger the only way to continue. Proposed accessible behavior:

- Keep a reachable Load more control with loading, retry and end-of-results states. Disable duplicate requests while one is in flight.
- Preserve stable IDs and the current focused item when appending. Announce a concise result count after an explicit load; avoid unsolicited announcements for every background prefetch.
- Supply meaningful image labels and a position within the loaded results. Do not invent a total for an unbounded source. Keep captions and actions separately reachable.
- Make controls after the results reachable without endlessly moving them away. Provide a way back to a known position, and preserve it when returning from detail.

These pagination policies apply the HIG's navigation and accessibility principles; they are not a documented automatic SwiftUI infinite-scroll feature. Verify them with VoiceOver rather than assuming append-only data updates preserve focus.

## Possible module boundary

| Candidate export, only after an app asks | Responsibility | What stays in the app |
| --- | --- | --- |
| Image loader, request key, thumbnail downsampler and remote-image phases | Bounded fetch/decode, disposable memory cache, optional HTTP byte cache, shared requests, cancellation and injectable transport | Asset URLs, authentication, account identity, persistence requirements and cache-clearing policy |
| Adaptive photo grid with a cell builder and a selected-ID binding | Layout and selection presentation; caller supplies cell content, menus and drag representations | Asset models, selection actions, editing, permissions and Photos integration |
| Paging container with current-ID binding and page builder | Viewport layout, paging, next/previous access, reduced-motion behavior and page-position reporting | Ranking, pagination, navigation, captions, likes, sharing, moderation and analytics |
| Separately owned playback coordinator with a fake player interface | Bounded player reuse, attachment, preparation, lifecycle and policy enforcement | Media variants, audio session, autoplay choice, downloads, DRM and any background mode |

An image cache should work without a grid or video dependency. A pager should accept still content and work without AVFoundation. Do not promise public names or ship any of these products before there is an implementation consumer. If one is added, follow [module packaging and release rules](../modules.md).

## Verification required before implementation ships

This research ran on Windows with Python 3.13.14 and web/source inspection. No Swift was compiled, no UI was exercised and no power or memory budget was measured. The following remain implementation acceptance work:

- Grid: minimum and accessibility Dynamic Type sizes, narrow iPad windows, aspect-fill hit regions, selection across scrolling/reordering, context-menu alternatives and any drag requirement.
- Pager: iOS 17 and newer-runtime lanes, safe areas, first and restored pages, fast reversals, insertion/removal of the active ID, rotation and keyboard/VoiceOver next/previous navigation.
- Playback: fake-player tests for one active item, bounded ownership, interrupted preload and stale completions; UI tests through the main path with screenshots; phone checks for audio interruptions, captions, settings changes, Low Power Mode and power consumption.
- Loader: fixture tests for orientation and aspect-fill resolution, cache variants, shared-request cancellation, failures/retry and memory-pressure eviction; a long-scroll memory trace to catch retained buffers and tasks.
- Accessibility: real VoiceOver reading order and focus across page changes and pagination, no duplicate page announcements, no competing autoplay audio, pause controls and Reduce Motion behavior.

Library release compatibility, network/media formats and any future OS-specific workarounds must be checked again when an app actually asks for the feature.
