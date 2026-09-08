import Foundation
import BYOKLLMKit

/// Generates short, specific qualitative feedback on a practice clip.
/// Wraps OnDeviceKit's `BYOKLLMKit` — `LLMSending`/`LLMService` handle the
/// actual provider call and Keychain-backed key storage, so this type only
/// owns prompt construction.
struct FeedbackEngine {
    let llmService: LLMSending
    let provider: LLMProvider
    let model: String

    init(
        llmService: LLMSending = LLMService.shared,
        provider: LLMProvider = FeedbackSettings.provider,
        model: String = FeedbackSettings.model
    ) {
        self.llmService = llmService
        self.provider = provider
        self.model = model
    }

    /// Whether an API key is present for `provider`, so callers can skip the
    /// LLM step entirely on offline/no-key setups instead of surfacing an error.
    static func isConfigured(provider: LLMProvider = .openrouter, keychain: LLMKeychainStore = .shared) -> Bool {
        keychain.hasKey(for: provider)
    }

    /// Kept short and specific — one drill-worthy observation, not generic praise.
    private let systemPrompt = """
    You are a concise speaking coach. Given objective speech metrics and a \
    transcript, give exactly one specific, actionable piece of feedback in \
    1-2 sentences. Reference the actual numbers. No generic encouragement, \
    no more than one suggestion.
    """

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

        return try await llmService.sendMessage(
            provider: provider.rawValue,
            model: model,
            messages: messages
        )
    }
}
