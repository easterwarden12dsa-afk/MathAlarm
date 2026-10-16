import Foundation
import AVFoundation
import AudioToolbox

/// Plays the alarm sound inside the app. Uses the `.playback` audio category,
/// which ignores the Silent switch, and keeps playing when the app goes to
/// the background (the app declares the "audio" background mode).
@MainActor
final class AlarmSoundPlayer {
    private var player: AVAudioPlayer?
    private var loadedSound: AlarmSound?
    private var previewStopTask: Task<Void, Never>?
    /// True while the sound *should* be playing (used to resume after a phone call).
    private(set) var shouldPlay = false

    init() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated {
                guard let raw, let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                if type == .ended { self?.resumeIfNeeded() }
            }
        }
    }

    var isPlaying: Bool { player?.isPlaying ?? false }

    /// Media volume (0…1). The in-app sound follows this, not the alarm volume.
    var outputVolume: Float { AVAudioSession.sharedInstance().outputVolume }

    func play(_ sound: AlarmSound) {
        previewStopTask?.cancel()
        previewStopTask = nil
        shouldPlay = true
        activateSession()
        let sound = sound.resolved
        if loadedSound != sound || player == nil {
            guard let url = sound.playbackURL ?? AlarmSound.classic.playbackURL,
                  let newPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
            newPlayer.numberOfLoops = -1
            newPlayer.volume = 1.0
            newPlayer.prepareToPlay()
            player = newPlayer
            loadedSound = sound
        }
        if player?.isPlaying == false { player?.play() }
    }

    func stop() {
        shouldPlay = false
        previewStopTask?.cancel()
        player?.stop()
        player?.currentTime = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Plays a few seconds of a sound in the alarm editor.
    func preview(_ sound: AlarmSound) {
        player?.stop()
        player?.currentTime = 0
        play(sound)
        previewStopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    /// Ends a preview started from the sound picker (does nothing during a ring).
    func stopPreview() {
        guard previewStopTask != nil else { return }
        previewStopTask?.cancel()
        previewStopTask = nil
        stop()
    }

    func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
    }

    private func resumeIfNeeded() {
        guard shouldPlay, let player, !player.isPlaying else { return }
        activateSession()
        player.play()
    }
}
