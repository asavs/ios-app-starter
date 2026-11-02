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
        static let timer = "timer"
        static let settings = "settings"

        /// The tab bar button for a tab.
        static func button(_ tab: String) -> String { "tabs.\(tab)" }
    }

    /// The welcome screen (`ContentView`).
    enum Welcome {
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
