import AVFoundation

/// Plays generated cues through `AVAudioPlayer`, setting the audio session for each one.
@MainActor
final class CueSpeaker {
    private var players: [Cue: AVAudioPlayer] = [:]

    func play(_ cue: Cue, playsInSilentMode: Bool) {
#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        // A failure leaves the previous category; the cue still plays, perhaps silenced by the switch.
        try? session.setCategory(playsInSilentMode ? .playback : .ambient, options: [.mixWithOthers])
        try? session.setActive(true)
#endif
        guard let player = player(for: cue) else { return }
        player.currentTime = 0
        player.play()
    }

    private func player(for cue: Cue) -> AVAudioPlayer? {
        if let player = players[cue] { return player }
        guard let player = try? AVAudioPlayer(data: cue.wav) else { return nil }
        player.prepareToPlay()
        players[cue] = player
        return player
    }
}
