import Foundation
import BYOKLLMKit
import LocalLLMKit

/// Generates short, specific qualitative feedback on a practice clip.
/// Wraps OnDeviceKit's `BYOKLLMKit` — `LLMSending`/`LLMService` handle the
/// actual provider call and Keychain-backed key storage, so this type only
/// owns prompt construction and the cloud-vs-on-device routing.
struct FeedbackEngine {
    let llmService: LLMSending
    let provider: LLMProvider
    let model: String
    /// When non-nil, feedback runs fully on-device via a GGUF model
    /// (`LocalLLMEngine`) or Apple Intelligence (`AppleFoundationEngine`).
    /// Falls back to the cloud path if the model isn't installed.
    let localModelID: String?

    init(
        llmService: LLMSending = LLMService.shared,
        provider: LLMProvider = FeedbackSettings.provider,
        model: String = FeedbackSettings.model,
        localModelID: String? = FeedbackSettings.localModelID
    ) {
        self.llmService = llmService
        self.provider = provider
        self.model = model
        self.localModelID = localModelID
    }

    var usesLocalModel: Bool { localModelID != nil }

    /// Whether an API key is present for `provider`, so callers can skip the
    /// LLM step entirely on offline/no-key setups instead of surfacing an error.
    /// In on-device mode this instead checks that the chosen local model is
    /// actually available (downloaded GGUF, or Apple Intelligence on iOS 26+).
    @MainActor
    static func isConfigured(provider: LLMProvider = .openrouter, keychain: LLMKeychainStore = .shared) -> Bool {
        keychain.hasKey(for: provider)
    }

    @MainActor
    func isConfigured() -> Bool {
        guard let localModelID, let localModel = LocalModelService.shared.model(withID: localModelID) else {
            return Self.isConfigured(provider: provider, keychain: .shared)
        }
        switch localModel.kind {
        case .appleFoundation:
            return appleFoundationModelAvailable()
        case .gguf:
            return LocalModelService.shared.isDownloaded(localModelID)
        }
    }

    /// Scores the performance 0-10 and adds one drill-worthy observation.
    private let systemPrompt = """
    You are a concise speaking coach. Given objective speech metrics and a \
    transcript, rate the drill performance and give concrete feedback in \
    exactly this format:

    Score: <N>/10
    Strengths: <one sentence referencing the actual numbers>
    Improvement: <exactly one specific, actionable suggestion>

    Keep each line to one sentence. No generic encouragement, no extra text.
    """

    @MainActor
    func generateFeedback(
        day: ProgramDay,
        transcript: String,
        metrics: SpeechMetrics
    ) async throws -> String {
        let userPrompt = """
        Lesson: \(day.title)
        Transcript: "\(transcript)"

        Metrics:
        - Words per minute: \(Int(metrics.wordsPerMinute))
        - Filler words used: \(metrics.fillerWordCount)
        - Pauses over 0.5s: \(metrics.pauseCount)
        - Longest pause: \(String(format: "%.1f", metrics.longestPauseSeconds))s
        """

        let messages = [
            LLMMessage(role: "system", content: systemPrompt),
            LLMMessage(role: "user", content: userPrompt),
        ]

        if let localModelID,
           let localModel = LocalModelService.shared.model(withID: localModelID) {
            return try await generateLocalFeedback(
                model: localModel,
                messages: messages
            )
        }

        return try await llmService.sendMessage(
            provider: provider.rawValue,
            model: model,
            messages: messages
        )
    }

    // MARK: - Score extraction

    /// Pulls a "Score: N/10" (or bare "N/10") rating out of free-form LLM
    /// feedback so the UI can show a badge. Tolerant of small-model drift.
    static func parseScore(from feedback: String) -> Int? {
        let pattern = #"\b(\d{1,2})\s*/\s*10\b"#
        guard let range = feedback.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        guard let number = Int(feedback[range].split(separator: "/")[0].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        return min(max(number, 1), 10)
    }

    // MARK: - On-device inference

    @MainActor
    private func generateLocalFeedback(
        model: LocalModel,
        messages: [LLMMessage]
    ) async throws -> String {
        switch model.kind {
        case .appleFoundation:
            if #available(iOS 26, *) {
                // AppleFoundationEngine.generate() itself validates that Apple
                // Intelligence is available and throws AppleFoundationError
                // with a user-facing reason if it is not.
                return try await AppleFoundationEngine.generate(
                    systemPrompt: systemPrompt,
                    messages: messages
                )
            }
            throw AppleFoundationError.unavailable("Requires iOS 26 with Apple Intelligence enabled.")

        case .gguf:
            let engine = LocalLLMEngine.shared
            await engine.loadModel(id: model.id, url: LocalModelService.shared.modelFilePath(id: model.id))
            return try await engine.generate(modelID: model.id, messages: messages)
        }
    }
}