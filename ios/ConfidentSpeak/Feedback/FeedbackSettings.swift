import Foundation
import BYOKLLMKit

/// Persists the user's chosen LLM provider/model for `FeedbackEngine`, so the
/// Settings screen and the recording pipeline agree on what to call. Backed
/// by `UserDefaults` — non-sensitive configuration only; the API key itself
/// lives in `LLMKeychainStore`.
enum FeedbackSettings {
    private static let providerKey = "feedback_provider"
    private static let modelKey = "feedback_model"
    private static let localModelKey = "feedback_local_model"

    /// Non-nil puts the coach-feedback step into fully-on-device mode using the
    /// selected on-device model (`apple-foundation` or a downloaded GGUF id).
    /// Nil uses `provider`/`model` and the cloud LLM service.
    static var localModelID: String? {
        get { UserDefaults.standard.string(forKey: localModelKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: localModelKey)
            } else {
                UserDefaults.standard.removeObject(forKey: localModelKey)
            }
        }
    }

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
