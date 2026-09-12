import Foundation
import BYOKLLMKit

/// Drives one practice attempt through the full pipeline described in the
/// scaffold README: record -> transcribe -> compute metrics -> optional LLM
/// feedback -> save `PracticeSession`.
@MainActor
final class RecordingViewModel: ObservableObject {
    enum Stage: Equatable {
        case idle
        case recording
        case transcribing
        case gettingFeedback
        case saved(PracticeSession)
        case failed(String)
    }

    @Published private(set) var stage: Stage = .idle
    @Published var reflectionNote: String = ""
    @Published private(set) var transcript: String?
    @Published private(set) var metrics: SpeechMetrics?
    @Published private(set) var llmFeedback: String?
    /// Relative `Documents/recordings/` filename of the last completed clip.
    @Published private(set) var recordedClipPath: String?

    var recorderError: Recorder.RecorderError? { recorder.lastError }

    /// URL of the last clip for immediate post-record playback, when one exists.
    var playbackURL: URL? {
        RecordingStore.shared.url(forRelativePath: recordedClipPath)
    }

    let day: ProgramDay
    private let database: AppDatabase
    private let recorder: Recorder
    private let transcriber: Transcriber
    private let feedbackEngine: FeedbackEngine

    var isBusy: Bool {
        switch stage {
        case .recording, .transcribing, .gettingFeedback: return true
        case .idle, .saved, .failed: return false
        }
    }

    init(
        day: ProgramDay,
        database: AppDatabase,
        recorder: Recorder? = nil,
        transcriber: Transcriber? = nil,
        feedbackEngine: FeedbackEngine? = nil
    ) {
        self.day = day
        self.database = database
        // Constructed inside the (MainActor-isolated) init body rather than as
        // parameter defaults, since `Recorder` is itself @MainActor-isolated
        // and a default-argument expression isn't guaranteed to share that
        // isolation.
        self.recorder = recorder ?? Recorder()
        self.transcriber = transcriber ?? Transcriber()
        self.feedbackEngine = feedbackEngine ?? FeedbackEngine()
    }

    var isRecording: Bool { recorder.isRecording }
    var currentDuration: TimeInterval { recorder.currentDuration }

    func startRecording() async {
        stage = .recording
        await recorder.startRecording()
        if let error = recorder.lastError {
            stage = .failed(error.localizedDescription)
        }
    }

    func stopRecordingAndAnalyze() async {
        guard let fileURL = recorder.stopRecording() else {
            stage = .failed("Recording could not be saved.")
            return
        }
        let recordingDuration = recorder.currentDuration

        stage = .transcribing
        do {
            let result = try await transcriber.transcribe(fileURL: fileURL)
            transcript = result.text

            let computedMetrics = SpeechMetrics.compute(
                transcript: result.text,
                segments: result.segmentTimestamps,
                totalDurationSeconds: recordingDuration
            )
            metrics = computedMetrics

            var feedback: String?
            if feedbackEngine.isConfigured() {
                stage = .gettingFeedback
                feedback = try? await feedbackEngine.generateFeedback(
                    day: day,
                    transcript: result.text,
                    metrics: computedMetrics
                )
            }
            llmFeedback = feedback

            let clipPath = RecordingStore.shared.persistRecording(from: fileURL)
            recordedClipPath = clipPath

            let session = PracticeSession(
                day: day.id,
                lessonKey: day.lessonKey,
                transcript: result.text,
                wordsPerMinute: computedMetrics.wordsPerMinute,
                fillerWordCount: computedMetrics.fillerWordCount,
                pauseCount: computedMetrics.pauseCount,
                llmFeedback: feedback,
                qualityScore: feedback.flatMap(FeedbackEngine.parseScore),
                reflectionNote: reflectionNote.isEmpty ? nil : reflectionNote,
                recordingDurationSeconds: recordingDuration,
                recordingPath: clipPath,
                completedAt: Date()
            )
            let saved = try await database.save(session)
            stage = .saved(saved)
        } catch {
            stage = .failed(error.localizedDescription)
        }
    }

    /// For days where `ProgramDay.requiresRecording` is false — records only
    /// the reflection note, with no transcript/metrics/LLM step.
    func saveReflectionOnly() async {
        guard !reflectionNote.isEmpty else {
            stage = .failed("Add a short reflection before saving.")
            return
        }
        do {
            let session = PracticeSession(
                day: day.id,
                lessonKey: day.lessonKey,
                reflectionNote: reflectionNote,
                completedAt: Date()
            )
            let saved = try await database.save(session)
            stage = .saved(saved)
        } catch {
            stage = .failed(error.localizedDescription)
        }
    }

    func reset() {
        stage = .idle
        transcript = nil
        metrics = nil
        llmFeedback = nil
        recordedClipPath = nil
        reflectionNote = ""
    }
}
