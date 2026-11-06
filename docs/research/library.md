# The Library: a collection screen for photos, files and links

Built as the Library tab (2026-11-04, `ios-125.4`): `StarterApp/StarterApp/Library`, see [modules.md](../modules.md#attachments) for what shipped. Research for board task `ios-125.4` (slice 4 of [feature-tabs.md](../design/feature-tabs.md)), written 2026-11-04 by claude-mac. Source grades: A = Apple documentation or the Human Interface Guidelines; B = maintained third-party source; C = forum. The HIG pages were read through their documentation JSON endpoints on 2026-11-04. The schema, ownership rules and file store this screen sits on are in [content-ownership.md](content-ownership.md) and [attachments.md](attachments.md); this document covers the screen itself.

## What the screen is

A tab where a person collects photos, files and links and finds them again: import from Photos, the camera, Files or a typed link; a browsable grid with search; an item's detail with a preview; removal. It owns no new kind of data. A `LibraryItem` holds one `Attachment` value from the store, the same value a Timer preset holds, and the `ContentCoordinator` counts owners across both, so collecting a preset's photo into the Library (or the other way round) shares the file rather than copying it. Notes refer to items by UUID and never own them; deleting an item removes those references and keeps the notes' text, and the coordinator reports how many notes referred to it, which is what the delete confirmation says.

## Layout: a grid, not a list

The HIG's rule for the choice: "Prefer displaying text in a list or table," and "If you have items that vary widely in size — or you need to display a large number of images — consider using a collection instead" ([Lists and tables, A](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables)); "Generally speaking, collections are ideal for showing image-based content," and "Use the standard row or grid layout whenever possible" ([Collections, A](https://developer.apple.com/design/human-interface-guidelines/collections)). A Library is mostly images with a caption, so it is a grid: the Attachments module's `AttachmentGrid`, which already lays out thumbnails in an adaptive grid and switches to one column with the name beside the thumbnail at the accessibility text sizes, "the way Photos and Files lay out" (the module's own doc). Links show as cards under the grid through `LinkPreview`, as the preset screen does today.

The HIG on choosing an item: "Make it easy to choose an item... Use adequate padding around images to keep focus or hover effects easy to see," and the defaults a person expects, "tap to select, touch and hold to edit, and swipe to scroll" ([Collections, A]). The grid's cells select on tap and offer Remove on a long press and as an accessibility action; the Library keeps both and adds the item's detail behind the tap: a navigation push on iPhone, which the Collections page's caution about dynamic layout changes ("avoid changing the layout while people are viewing and interacting with it") argues for over an in-place expansion.

## Search

"If search is important, give it a primary position in your app or view," and "Aim to make your app's content searchable through a single location" ([Searching, A](https://developer.apple.com/design/human-interface-guidelines/searching)). For the Library that is `searchable` on the grid's navigation stack, which iOS places in the navigation bar on an iPhone and in the top bar on an iPad. "Clearly display the current scope of a search. Use a descriptive placeholder text, a scope bar, or a title" ([Searching, A]): the placeholder says what is searched ("Titles and links") and there is no scope bar, since the Library is one collection. The HIG asks for recent searches or suggestions "to help people search faster and type less"; with titles the person wrote themselves, suggestions add little, so the first version has none, and nothing is stored, which also settles the HIG's privacy note about search history. An empty result shows `ContentUnavailableView.search(text:)`, the system's own "No Results for ..." layout (iOS 17, [ContentUnavailableView, A](https://developer.apple.com/documentation/swiftui/contentunavailableview)), and an empty Library shows the module's `EmptyStateView` with the import actions, so neither state is a blank screen.

Matching is on the title and, for links, the address, case and diacritic insensitive, done in memory over the fetched items: the items are the person's own collection, tens to hundreds, and `Attachment` is a Codable value inside the row, not a column a predicate can reach (content-ownership.md).

## Import

The Attachments module's `AttachmentPicker` menu (Photos, Camera, Files, Link) and `AttachmentPickerModel` do the copying into the store and report each new attachment; the Library collects each into a `LibraryItem` through the coordinator, which marks the import in flight before the store adds the file and saves the owner before reporting success, so a crash in between never leaves an owned file to cleanup (content-ownership.md, "Import has the reverse crash window"). A failed import (an unreadable file, a link whose metadata can't be fetched) shows the picker model's failure alert and keeps the Library as it was. The other failure is the save after a successful import: the file is in the store but the owner record didn't save. The research's rule for that case is to keep the bytes and let the person retry or cancel explicitly (content-ownership.md, "Failed saves retain the draft and bytes"), so the Library keeps the attachment aside and offers Try Again and Discard; Discard removes the file, since nothing owns it. Denied Photos or camera permission is the picker's own business (attachments.md): the Photos picker runs out of process and needs none, the camera asks once and shows the module's explanation when denied. The Camera entry only appears where there is a camera, so on a simulator and an iPad without one the menu is shorter; the UI tests use the module's fakes (`-attachments.fakeCamera`, `-attachments.fakePhotos`, `-attachments.fakeLink`) and the phone check covers the real pickers, as the task asks.

## The item's detail

A pushed screen with the thumbnail or link card, the title (editable in place; the title is the Library's own field, the attachment's display name is what the file was called), the kind, size and date, and the actions: preview, share, delete. Preview is the module's `attachmentPreview` (Quick Look for a file, the browser for a link). A file whose original is missing (the store's `fileURL` points at nothing) shows the thumbnail's fallback and an explanation instead of a preview; the item stays, since its metadata is the person's and the research keeps "a missing original" out of automatic cleanup.

## Deletion

Deleting an item is uncommon and can't be undone, which is the HIG's case for a confirmation: "when people take an uncommon destructive action that they can't undo, it's important to display an alert in case they initiated the action accidentally" ([Alerts, A](https://developer.apple.com/design/human-interface-guidelines/alerts)). It is a confirmation dialog rather than an alert, because the person chose Delete themselves and a dialog "offer[s] choices related to an intentional action" with "a Cancel button by default" in SwiftUI ([Action sheets, A](https://developer.apple.com/design/human-interface-guidelines/action-sheets)); the destructive button is styled destructive and sits first, as the same page asks. Its title names the consequence the coordinator computed: "Delete this item?" with the message "Used in 2 notes. Deleting it removes it from those notes. Their text stays." when references exist, and no message when none do ("Provide a message only if necessary"). Button titles are verbs: Delete and Cancel ([Alerts, A]: "Prefer verbs and verb phrases"; "Always use the title 'Cancel'"). The file goes only after the save, and only if no preset still holds the same attachment (content-ownership.md).

## The tab

`library` joins `StarterTab` and `StarterFeature.all` with the symbol `books.vertical`, available when Database and Attachments are compiled in, on by default like the others; the registry (#152) makes a build without the modules show no tab and a deep link to it say so. The Timer's preset attachments screen stays as it is in this slice; moving it to a Library picker is a later change once Notes exist.

## Accessibility and text sizes

The grid already answers the largest text sizes with one column and the name beside the thumbnail; the detail screen is a `Form`; the search field, the picker menu and the confirmation dialog are system controls. Every cell reads as one element with the kind and name (the module's cell does this), the thumbnail is hidden from VoiceOver as decorative, and the delete action is reachable as an accessibility action on the cell as well as from the detail. The pinned auditor runs on the grid, the detail and the dialog before the task closes.

## Text

Every string the screen shows is the app's, in `StarterApp/StarterApp/Localizable.xcstrings`, with the module's own strings ("Remove", "Photo", the picker menu) coming from the Attachments catalog as they do on the preset screen. Titles the person types and file names are shown as written (`Text(verbatim:)`), never looked up.

## Tests

- Unit: searching matches titles and link addresses case-insensitively and returns items in a stable order; collecting goes through the coordinator (the in-flight mark set and cleared); a title edit saves; deleting with references reports the count the dialog shows.
- UI, deterministic on the simulator with the fakes: the empty Library and its import actions (screenshot); add a fake photo and a link, both listed (screenshot); search narrows to one and to none (screenshot of the no-results state); open an item, edit its title, preview the photo in Quick Look (screenshot); delete an item with the confirmation, cancel first (nothing changes), then delete (it goes); relaunch keeps the rest; the largest text size shows one column.
- Phone: the real Photos and camera pickers, Files, sharing, Quick Look with a real document.

## Sources

- [Searching](https://developer.apple.com/design/human-interface-guidelines/searching), HIG (A), read 2026-11-04.
- [Collections](https://developer.apple.com/design/human-interface-guidelines/collections), HIG (A), read 2026-11-04.
- [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables), HIG (A), read 2026-11-04.
- [Action sheets](https://developer.apple.com/design/human-interface-guidelines/action-sheets), HIG (A), read 2026-11-04.
- [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts), HIG (A), read 2026-11-04.
- [ContentUnavailableView](https://developer.apple.com/documentation/swiftui/contentunavailableview), Apple (A).
- [attachments.md](attachments.md) and [content-ownership.md](content-ownership.md), this repository, for the pickers, the store, the schema and the ownership rules.
