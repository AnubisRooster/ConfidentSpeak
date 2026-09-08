import Foundation
import Speech

/// On-device transcription only — no audio leaves the device for this step,
/// consistent with the on-device-first approach across CompyPal/therAIpist.
/// Candidate for promotion into OnDeviceKit alongside Recorder.swift.
final class Transcriber {

    struct Result {
        let text: String
        /// Start times of each recognized segment, used by SpeechMetrics
        /// to detect pauses between words.
        let segmentTimestamps: [(text: String, start: TimeInterval, duration: TimeInterval)]
    }

    enum TranscriberError: LocalizedError {
        case permissionDenied
        case recognizerUnavailable
        case onDeviceRecognitionUnavailable
        case transcriptionFailed(Error)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Speech recognition access is required to transcribe practice clips."
            case .recognizerUnavailable:
                return "Speech recognizer is unavailable for this locale."
            case .onDeviceRecognitionUnavailable:
                return "On-device recognition isn't supported on this device."
            case .transcriptionFailed(let error):
                return "Transcription failed: \(error.localizedDescription)"
            }
        }
    }

    private let recognizer: SFSpeechRecognizer?

    init(locale: Locale = Locale(identifier: "en-US")) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func transcribe(fileURL: URL) async throws -> Result {
        guard await Self.requestPermission() else {
            throw TranscriberError.permissionDenied
        }
        guard let recognizer, recognizer.isAvailable else {
            throw TranscriberError.recognizerUnavailable
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw TranscriberError.onDeviceRecognitionUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: TranscriberError.transcriptionFailed(error))
                    return
                }
                guard let result, result.isFinal else { return }

                let segments = result.bestTranscription.segments.map {
                    (text: $0.substring, start: $0.timestamp, duration: $0.duration)
                }
                continuation.resume(returning: Result(
                    text: result.bestTranscription.formattedString,
                    segmentTimestamps: segments
                ))
            }
        }
    }
}
