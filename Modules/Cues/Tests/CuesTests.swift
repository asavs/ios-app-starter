import Foundation
import SwiftUI
import Testing
@testable import Cues

@MainActor
struct CuesTests {
    private let suiteName: String
    private let defaults: UserDefaults

    init() throws {
        suiteName = "CuesTests.\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    @Test func preferencesDefaultToSoundThroughSilentModeWithHaptics() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        #expect(CuePreferences(defaults: defaults) == CuePreferences(sound: true, playsInSilentMode: true, haptics: true))
    }

    @Test func preferencesReadStoredValues() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: CuePreferences.soundKey)
        defaults.set(false, forKey: CuePreferences.silentModeKey)
        defaults.set(false, forKey: CuePreferences.hapticsKey)
        #expect(CuePreferences(defaults: defaults) == CuePreferences(sound: false, playsInSilentMode: false, haptics: false))
    }

    @Test(arguments: Cue.allCases)
    func hapticsFollowTheSetting(_ cue: Cue) {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let player = CuePlayer(defaults: defaults) { _, _ in }
        #expect(player.haptic(for: cue) == cue.haptic)
        defaults.set(false, forKey: CuePreferences.hapticsKey)
        #expect(player.haptic(for: cue) == nil)
        defaults.set(false, forKey: CuePreferences.soundKey)
        defaults.set(true, forKey: CuePreferences.hapticsKey)
        #expect(player.haptic(for: cue) == cue.haptic, "Haptics don't depend on sound")
    }

    @Test func settingsViewsConstructWithPublicInitializers() {
        _ = CueSettingsSection()
        _ = CueSettingsSection(defaults: defaults)
        _ = CueSettingsLink()
        _ = CueSettingsLink(defaults: defaults)
    }

    @Test func eachCueHasItsOwnHaptic() {
        #expect(Cue.start.haptic == .start)
        #expect(Cue.phaseChange.haptic == .impact)
        #expect(Cue.finished.haptic == .success)
    }

    @Test func playsWithTheCurrentPreferences() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var played: [(Cue, CuePreferences)] = []
        let player = CuePlayer(defaults: defaults) { played.append(($0, $1)) }
        player.play(.phaseChange)
        defaults.set(false, forKey: CuePreferences.silentModeKey)
        player.play(.finished)
        #expect(played.map(\.0) == [.phaseChange, .finished])
        #expect(played.map(\.1.playsInSilentMode) == [true, false])
    }

    @Test func soundOffPlaysNothing() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: CuePreferences.soundKey)
        var played: [Cue] = []
        CuePlayer(defaults: defaults) { cue, _ in played.append(cue) }.play(.finished)
        #expect(played.isEmpty)
    }

    @Test(arguments: Cue.allCases)
    func cuesAreValidWAV(_ cue: Cue) {
        let wav = cue.wav
        #expect(wav.prefix(4) == Data("RIFF".utf8))
        #expect(wav[8..<16] == Data("WAVEfmt ".utf8))
        let seconds = cue.notes.reduce(0) { $0 + $1.duration }
        let samples = (wav.count - 44) / 2
        #expect(samples == cue.notes.reduce(0) { $0 + Int($1.duration * Double(Tone.sampleRate)) })
        #expect(seconds < 1, "A cue should be short")
    }

    @Test func tonesStartAndEndQuietly() throws {
        let samples = Tone(frequency: 880, duration: 0.2).samples
        #expect(abs(try #require(samples.first)) < 0.01)
        #expect(abs(try #require(samples.last)) < 0.05)
        #expect(samples.allSatisfy { abs($0) <= 0.6 })
    }
}
