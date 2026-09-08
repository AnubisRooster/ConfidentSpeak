import Testing
import BYOKLLMKit
@testable import ConfidentSpeak

private final class MockLLMSending: LLMSending, @unchecked Sendable {
    var capturedProvider: String?
    var capturedModel: String?
    var capturedMessages: [LLMMessage]?
    var stubbedReply = "Slow down slightly on your closing sentence."

    func sendMessage(provider: String, model: String, messages: [LLMMessage]) async throws -> String {
        capturedProvider = provider
        capturedModel = model
        capturedMessages = messages
        return stubbedReply
    }
}

struct FeedbackEngineTests {
    @Test func sendsProviderAndModelThroughToLLMService() async throws {
        let mock = MockLLMSending()
        let engine = FeedbackEngine(llmService: mock, provider: .openrouter, model: "openai/gpt-4o-mini")
        let day = ProgramContent.days[0]
        let metrics = SpeechMetrics(wordsPerMinute: 120, fillerWordCount: 2, pauseCount: 1, longestPauseSeconds: 0.8)

        let reply = try await engine.generateFeedback(day: day, transcript: "Hi, I'm testing.", metrics: metrics)

        #expect(reply == mock.stubbedReply)
        #expect(mock.capturedProvider == "openrouter")
        #expect(mock.capturedModel == "openai/gpt-4o-mini")
        #expect(mock.capturedMessages?.count == 2)
        #expect(mock.capturedMessages?.first?.role == "system")
        #expect(mock.capturedMessages?.last?.content.contains("120") == true)
    }

    @Test func propagatesErrorsFromTheUnderlyingService() async {
        struct Boom: Error {}
        final class FailingLLMSending: LLMSending, @unchecked Sendable {
            func sendMessage(provider: String, model: String, messages: [LLMMessage]) async throws -> String {
                throw Boom()
            }
        }
        let engine = FeedbackEngine(llmService: FailingLLMSending())
        let metrics = SpeechMetrics(wordsPerMinute: 100, fillerWordCount: 0, pauseCount: 0, longestPauseSeconds: 0)

        await #expect(throws: Boom.self) {
            try await engine.generateFeedback(day: ProgramContent.days[0], transcript: "hi", metrics: metrics)
        }
    }
}
