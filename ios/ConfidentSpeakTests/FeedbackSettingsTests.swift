import Testing
import BYOKLLMKit
@testable import ConfidentSpeak

/// `FeedbackSettings` reads/writes `UserDefaults.standard`, so each test
/// captures and restores the prior values to avoid leaking state between
/// test runs (Swift Testing may run these in parallel with other suites).
struct FeedbackSettingsTests {
    private func withRestoredSettings(_ body: () throws -> Void) rethrows {
        let originalProvider = FeedbackSettings.provider
        let originalModel = FeedbackSettings.model
        defer {
            FeedbackSettings.provider = originalProvider
            FeedbackSettings.model = originalModel
        }
        try body()
    }

    @Test func defaultsToOpenRouterWhenNothingStored() throws {
        try withRestoredSettings {
            UserDefaults.standard.removeObject(forKey: "feedback_provider")
            UserDefaults.standard.removeObject(forKey: "feedback_model")
            #expect(FeedbackSettings.provider == .openrouter)
        }
    }

    @Test func providerRoundTrips() throws {
        try withRestoredSettings {
            FeedbackSettings.provider = .anthropic
            #expect(FeedbackSettings.provider == .anthropic)
        }
    }

    @Test func modelFallsBackToProviderExampleWhenUnset() throws {
        try withRestoredSettings {
            UserDefaults.standard.removeObject(forKey: "feedback_model")
            FeedbackSettings.provider = .groq
            #expect(FeedbackSettings.model == LLMProvider.groq.exampleModelID)
        }
    }

    @Test func modelRoundTripsOnceSet() throws {
        try withRestoredSettings {
            FeedbackSettings.model = "openai/gpt-4o"
            #expect(FeedbackSettings.model == "openai/gpt-4o")
        }
    }
}
