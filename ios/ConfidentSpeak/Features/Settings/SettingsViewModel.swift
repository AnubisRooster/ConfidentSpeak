import Foundation
import BYOKLLMKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var provider: LLMProvider = FeedbackSettings.provider
    @Published var apiKey: String = ""
    @Published var model: String = FeedbackSettings.model
    @Published private(set) var statusMessage: String?
    @Published private(set) var hasStoredKey: Bool = false

    private let keychain: LLMKeychainStore

    init(keychain: LLMKeychainStore = .shared) {
        self.keychain = keychain
        refreshKeyStatus()
    }

    func refreshKeyStatus() {
        hasStoredKey = keychain.hasKey(for: provider)
    }

    /// Called when the user picks a different provider — each provider has
    /// its own stored key and model, so both need to be reloaded.
    func providerChanged() {
        FeedbackSettings.provider = provider
        model = FeedbackSettings.model
        apiKey = ""
        statusMessage = nil
        refreshKeyStatus()
    }

    func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        keychain.set(trimmed, for: provider)
        apiKey = ""
        statusMessage = "Key saved securely."
        refreshKeyStatus()
    }

    func clearKey() {
        keychain.delete(for: provider)
        statusMessage = "Key removed."
        refreshKeyStatus()
    }

    func saveModel() {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        model = trimmed.isEmpty ? provider.exampleModelID : trimmed
        FeedbackSettings.model = model
        statusMessage = "Model saved."
    }
}
