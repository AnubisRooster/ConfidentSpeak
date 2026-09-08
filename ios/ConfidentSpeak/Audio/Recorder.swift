import Foundation
import AVFoundation

/// Wraps AVAudioRecorder for short practice-clip recording.
/// Candidate for promotion into OnDeviceKit once proven here —
/// CompyPal/therAIpist could reuse this for voice input later.
@MainActor
final class Recorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var currentDuration: TimeInterval = 0
    @Published var lastError: RecorderError?

    private var audioRecorder: AVAudioRecorder?
    private var durationTimer: Timer?
    private(set) var lastRecordingURL: URL?

    enum RecorderError: LocalizedError {
        case permissionDenied
        case sessionConfigurationFailed
        case recordingFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Microphone access is required to record practice clips."
            case .sessionConfigurationFailed:
                return "Could not configure the audio session."
            case .recordingFailed:
                return "Recording failed to start."
            }
        }
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() async {
        guard await requestPermission() else {
            lastError = .permissionDenied
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            lastError = .sessionConfigurationFailed
            return
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            guard recorder.record() else {
                lastError = .recordingFailed
                return
            }
            audioRecorder = recorder
            lastRecordingURL = fileURL
            isRecording = true
            currentDuration = 0
            startDurationTimer()
        } catch {
            lastError = .recordingFailed
        }
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        stopDurationTimer()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        return lastRecordingURL
    }

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.audioRecorder else { return }
            Task { @MainActor in
                self.currentDuration = recorder.currentTime
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
}

extension Recorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Task { @MainActor in
                self.lastError = .recordingFailed
            }
        }
    }
}
