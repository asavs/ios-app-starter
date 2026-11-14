import Foundation

/// The app's accessibility identifiers: the views set them and the UI tests look them up, from one
/// place. Compiled into both targets from StarterApp/Shared. Identifiers are for automation; the
/// labels VoiceOver reads are the views' own. `scripts/check-ui-identifiers.py` fails a build whose
/// app views or UI tests spell an identifier as a literal instead.
///
/// Replace these with the app's own screens; the modules' identifiers are in `ModuleIdentifiers`.
enum Identifiers {
    /// `StarterTab` raw values, and the tab bar buttons TabShell draws for them.
    enum Tabs {
        static let welcome = "welcome"
        static let library = "library"
        static let notes = "notes"
        static let timer = "timer"
        static let settings = "settings"

        /// The tab bar button for a tab.
        static func button(_ tab: String) -> String { "tabs.\(tab)" }
    }

    /// Settings' chooser of tabs (`TabChoicesView`); `tab` is a `StarterTab` raw value.
    enum TabChoices {
        /// The row in Settings that opens the chooser.
        static let open = "settings.tabs"

        static func hide(_ tab: String) -> String { "tabChoices.hide.\(tab)" }
        static func show(_ tab: String) -> String { "tabChoices.show.\(tab)" }
        /// A feature's row in onboarding's Choose your tabs step (`TabChoicesStep`).
        static func onboarding(_ tab: String) -> String { "tabChoices.onboarding.\(tab)" }
        /// That step's identifier, so `ModuleIdentifiers.Onboarding.step` finds it.
        static let onboardingStep = "tabs"
    }

    /// The Notes tab (`NotesView`, `NoteEditorView` and the Library item picker).
    enum Notes {
        static let add = "notes.add"
        static let empty = "notes.empty"
        static let noResults = "notes.noResults"
        /// The confirmation dialog's Delete button.
        static let deleteConfirm = "notes.delete.confirm"
        /// Each row, saved or an unsaved new draft: `notes.row.<note id>`.
        static let rowPrefix = "notes.row."
        static func row(_ id: String) -> String { "\(rowPrefix)\(id)" }

        enum Editor {
            static let title = "notes.editor.title"
            static let body = "notes.editor.body"
            static let save = "notes.editor.save"
            static let done = "notes.editor.done"
            /// The unsaved-changes dialog's Discard button.
            static let discard = "notes.editor.discard"
            /// The failed-save alert's Try Again button.
            static let retry = "notes.editor.retry"
            static let addReference = "notes.editor.addReference"
            /// Each Library item the note refers to: `notes.reference.<item id>`.
            static let referencePrefix = "notes.reference."
            static func reference(_ itemID: String) -> String { "\(referencePrefix)\(itemID)" }
        }

        enum Picker {
            /// Each Library item offered: `notes.picker.item.<item id>`.
            static let itemPrefix = "notes.picker.item."
            static func item(_ id: String) -> String { "\(itemPrefix)\(id)" }
            static let done = "notes.picker.done"
        }
    }

    /// The Library tab (`LibraryView` and `LibraryItemView`); the grid, its cells and the Add menu
    /// are the Attachments module's (`ModuleIdentifiers.Attachments`).
    enum Library {
        /// The empty state, before anything is collected.
        static let empty = "library.empty"
        /// The no-results state of a search.
        static let noResults = "library.noResults"
        /// The confirmation dialog's Delete button.
        static let deleteConfirm = "library.delete.confirm"

        enum Detail {
            static let title = "library.detail.title"
            static let preview = "library.detail.preview"
            static let share = "library.detail.share"
            /// The notice shown when the original file is missing.
            static let missing = "library.detail.missing"
            static let delete = "library.detail.delete"
        }
    }

    /// Home's sections (`HomeSections` and its parts); `tab` is a `StarterTab` raw value.
    enum Home {
        /// Each section's header: `home.section.<tab>`; Shortcuts is `home.section.welcome`.
        static let sectionPrefix = "home.section."
        static func section(_ tab: String) -> String { "\(sectionPrefix)\(tab)" }
        static func seeAll(_ tab: String) -> String { "home.seeAll.\(tab)" }
        /// A shortcut row that switches to a chosen tab.
        static let shortcutPrefix = "home.shortcut."
        static func shortcut(_ tab: String) -> String { "\(shortcutPrefix)\(tab)" }
        static let notesEmpty = "home.notes.empty"
        static let writeNote = "home.notes.write"
        /// Each recent note: `home.note.<note id>`.
        static let notePrefix = "home.note."
        static func note(_ id: String) -> String { "\(notePrefix)\(id)" }
        static let libraryEmpty = "home.library.empty"
        static let openLibrary = "home.library.open"
        /// Each recent Library item: `home.item.<item id>`.
        static let itemPrefix = "home.item."
        static func item(_ id: String) -> String { "\(itemPrefix)\(id)" }
    }

    /// The welcome screen (`ContentView`): Home with tabs, the greeting without.
    enum Welcome {
        /// The greeting, in a build without tabs.
        static let header = "welcome.header"
        static let card = "welcome.card"
        static let modulesVersion = "welcome.modulesVersion"
        static let buildGoals = "welcome.buildGoals"
        /// The gear button, when Settings isn't a tab.
        static let settings = "settings.open"
        static let replayTour = "onboarding.replay"
    }

    /// The template's own rows in Settings (`StarterSettingsView`).
    enum Settings {
        static let onboardingReset = "settings.onboarding.reset"
        static let tipsReset = "settings.tips.reset"
        /// The example secret row's key.
        static let exampleSecretKey = "example.apiKey"
    }

    /// The Timer tab (`StarterTimerView` and its parts).
    enum Timer {
        static let plan = "timer.plan"
        static let ring = "timer.ring"
        static let step = "timer.step"
        static let primary = "timer.primary"
        static let skip = "timer.skip"
        static let reset = "timer.reset"
        static let presets = "timer.presets"
        static let edit = "timer.edit"
        /// The Live Activity count shown under `-sessionActivity.readout`.
        static let activityCount = "timer.activityCount"

        enum Edit {
            static let work = "timer.edit.work"
            static let rest = "timer.edit.rest"
            static let rounds = "timer.edit.rounds"
            static let done = "timer.edit.done"
        }

        enum Presets {
            static let done = "timer.presets.done"
            static let save = "timer.presets.save"
            static let name = "timer.presets.name"
            static let attachmentsDone = "timer.presets.attachments.done"

            static func row(_ name: String) -> String { "timer.presets.row.\(name)" }
            /// The swipe action that opens a preset's attachments.
            static func attachments(of name: String) -> String { "\(row(name)).attachments" }
        }
    }
}

/// The module identifiers the template's UI tests use, as docs/modules.md documents them for each
/// module. The modules set them; this mirror exists so the tests have no literals, and
/// `scripts/check-ui-identifiers.py` checks each one against the module sources.
enum ModuleIdentifiers {
    enum Onboarding {
        static let next = "onboarding.next"
        static let skip = "onboarding.skip"

        static func step(_ id: String) -> String { "onboarding.step.\(id)" }
        static func page(_ id: String) -> String { "onboarding.page.\(id)" }
        static func feature(_ id: String) -> String { "onboarding.feature.\(id)" }
        static func choice(_ step: String, _ option: String) -> String { "onboarding.choice.\(step).\(option)" }
        static func permissionFootnote(_ id: String) -> String { "onboarding.permission.\(id).footnote" }
    }

    enum Settings {
        static let appearance = "settings.appearance"
        static let privacy = "settings.privacy"
        static let privacySummary = "settings.privacy.summary"
        static let acknowledgements = "settings.acknowledgements"
        /// Each credit row: `settings.acknowledgements.<id>`.
        static let acknowledgementPrefix = "settings.acknowledgements."
        static let reset = "settings.reset"
        static let resetConfirm = "settings.reset.confirm"
        /// The Cues module's Sounds & Haptics row.
        static let cues = "settings.cues"

        enum Secure {
            static func field(_ key: String) -> String { "settings.secure.\(key).field" }
            static func save(_ key: String) -> String { "settings.secure.\(key).save" }
            static func clear(_ key: String) -> String { "settings.secure.\(key).clear" }
            static func status(_ key: String) -> String { "settings.secure.\(key).status" }
        }
    }

    enum Cues {
        static let sound = "cues.sound"
        static let silentMode = "cues.silentMode"
        static let haptics = "cues.haptics"
    }

    enum Attachments {
        static let add = "attachments.add"
        static let addCamera = "attachments.add.camera"
        static let addPhotos = "attachments.add.photos"
        static let addFiles = "attachments.add.files"
        static let addLink = "attachments.add.link"
        static let linkField = "attachments.link.field"
        static let linkAdd = "attachments.link.add"
        static let linkPreview = "attachments.linkPreview"
        /// Each cell: `attachments.item.<attachment id>`.
        static let itemPrefix = "attachments.item."
    }

    enum SessionActivity {
        static let enabled = "sessionActivity.enabled"
    }
}
