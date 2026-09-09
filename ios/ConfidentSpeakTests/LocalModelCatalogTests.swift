import Testing
import Foundation
import BYOKLLMKit
@testable import ConfidentSpeak

/// Covers the curated on-device model catalog and the local-vs-cloud routing
/// switch in `FeedbackSettings`/`FeedbackEngine`. Uses `UserDefaults.standard`
/// via `FeedbackSettings.localModelID`, so the suite runs serially like
/// `FeedbackSettingsTests` to avoid parallel write races.
@Suite(.serialized)
@MainActor
struct LocalModelCatalogTests {

    @Test func catalogHasUniqueIDsAndSensibleKinds() {
        let service = LocalModelService.shared
        let catalog = service.catalog

        #expect(!catalog.isEmpty)
        #expect(Set(catalog.map(\.id)).count == catalog.count)
        #expect(catalog.contains { $0.kind == .appleFoundation })
        #expect(catalog.filter { $0.kind == .gguf }.count >= 5)
    }

    @Test func everyGGUFEntryPointsAtAHuggingFaceURL() {
        let service = LocalModelService.shared
        for model in service.catalog where model.kind == .gguf {
            #expect(model.downloadURL.hasPrefix("https://huggingface.co/"), "\(model.id) missing HF url")
            #expect(model.downloadURL.hasSuffix(".gguf"), "\(model.id) url is not a .gguf file")
            #expect(model.sizeBytes > 0)
        }
        let apple = service.catalog.first { $0.kind == .appleFoundation }
        #expect(apple?.downloadURL ?? "non-empty" == "")
        #expect(apple?.sizeBytes == 0)
    }

    @Test func recommendedModelIDsAlwaysResolveToTheCatalog() {
        let service = LocalModelService.shared
        for ramGB in [1, 4, 6, 8, 16] {
            let recommended = service.recommendedModelID(ramGB: ramGB)
            #expect(service.model(withID: recommended) != nil, "recommended \(recommended) not in catalog")
        }
    }

    @Test func localModelIDRoundTripsThroughFeedbackSettings() {
        let original = FeedbackSettings.localModelID
        defer { FeedbackSettings.localModelID = original }

        #expect(FeedbackSettings.localModelID == nil)
        FeedbackSettings.localModelID = "llama-3.2-3b"
        #expect(FeedbackSettings.localModelID == "llama-3.2-3b")
        FeedbackSettings.localModelID = nil
        #expect(FeedbackSettings.localModelID == nil)
    }

    @Test func feedbackEngineRecognizesLocalMode() {
        let engine = FeedbackEngine(localModelID: "apple-foundation")
        #expect(engine.usesLocalModel == true)
        #expect(engine.localModelID == "apple-foundation")
    }

    @Test func feedbackEngineDefaultsToCloudWhenNoLocalModel() {
        // Default localModelID reads FeedbackSettings.localModelID (nil in tests).
        let engine = FeedbackEngine()
        #expect(engine.usesLocalModel == false)
        #expect(engine.localModelID == nil)
    }

    @Test func cloudFeedbackStillSendsThroughLLMSending() async throws {
        let mock = MockLLMSendingForLocalTests()
        let engine = FeedbackEngine(llmService: mock, provider: .openrouter, model: "openai/gpt-4o-mini")
        let day = ProgramContent.days[0]
        let metrics = SpeechMetrics(wordsPerMinute: 120, fillerWordCount: 0, pauseCount: 0, longestPauseSeconds: 0)

        _ = try await engine.generateFeedback(day: day, transcript: "hello", metrics: metrics)

        #expect(mock.capturedProvider == "openrouter")
        #expect((mock.capturedMessages ?? []).count == 2)
    }
}

private final class MockLLMSendingForLocalTests: LLMSending, @unchecked Sendable {
    var capturedProvider: String?
    var capturedMessages: [LLMMessage]?

    func sendMessage(provider: String, model: String, messages: [LLMMessage]) async throws -> String {
        capturedProvider = provider
        capturedMessages = messages
        return "ok"
    }
}