import Foundation
import BYOKLLMKit

/// Persists the user's chosen LLM provider/model for `FeedbackEngine`, so the
/// Settings screen and the recording pipeline agree on what to call. Backed
/// by `UserDefaults` — non-sensitive configuration only; the API key itself
/// lives in `LLMKeychainStore`.
enum FeedbackSettings {
    private static let providerKey = "feedback_provider"
    private static let modelKey = "feedback_model"

    static var provider: LLMProvider {
        get {
            UserDefaults.standard.string(forKey: providerKey)
                .flatMap(LLMProvider.init(rawValue:)) ?? .openrouter
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: providerKey) }
    }

    /// Falls back to the current provider's example model when nothing has
    /// been saved yet, so `FeedbackEngine` always has a usable default.
    static var model: String {
        get {
            let stored = UserDefaults.standard.string(forKey: modelKey)
            return (stored?.isEmpty == false ? stored : nil) ?? provider.exampleModelID
        }
        set { UserDefaults.standard.set(newValue, forKey: modelKey) }
    }
}
