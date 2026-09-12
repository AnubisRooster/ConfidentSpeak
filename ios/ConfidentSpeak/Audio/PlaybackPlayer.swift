import Foundation
import AVFoundation

/// Minimal AVAudioPlayer wrapper for replaying recorded practice clips.
/// One clip at a time; toggles between play and stop. On-device only —
/// the playback file is already stored in `Documents/recordings/`.
@MainActor
final class PlaybackPlayer: ObservableObject {
    @Published private(set) var isPlaying = false

    private var player: AVAudioPlayer?
    private var playerDelegate: PlayerDelegate?

    func toggle(url: URL) {
        if isPlaying {
            stop()
            return
        }
        stop()

        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let delegate = PlayerDelegate { [weak self] in
            Task { @MainActor in self?.stop() }
        }
        self.playerDelegate = delegate
        player.delegate = delegate
        self.player = player
        player.play()
        isPlaying = true
    }

    func stop() {
        player?.stop()
        player = nil
        playerDelegate = nil
        isPlaying = false
    }
}

private final class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}