import Foundation
import Combine
import BYOKLLMKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var provider: LLMProvider = FeedbackSettings.provider
    @Published var apiKey: String = ""
    @Published var model: String = FeedbackSettings.model

    // On-device mode
    @Published var isLocal: Bool = FeedbackSettings.localModelID != nil
    @Published var selectedLocalModelID: String? = FeedbackSettings.localModelID
    @Published private(set) var localModels: [LocalModel] = []
    @Published private(set) var downloadedIDs: Set<String> = []
    @Published private(set) var downloadProgress: [String: Double] = [:]
    @Published private(set) var appleFoundationStatus = "Unavailable"

    @Published private(set) var statusMessage: String?
    @Published private(set) var hasStoredKey: Bool = false

    private let keychain: LLMKeychainStore
    private let localService: LocalModelService
    private var cancellables: Set<AnyCancellable> = []

    init(keychain: LLMKeychainStore = .shared, localService: LocalModelService = .shared) {
        self.keychain = keychain
        self.localService = localService
        refreshKeyStatus()
        refreshLocalState()

        // Mirror live download progress / install state from LocalModelService.
        localService.objectWillChange
            .sink { [weak self] in
                Task { @MainActor [weak self] in self?.refreshLocalState() }
            }
            .store(in: &cancellables)
    }

    func refreshKeyStatus() {
        hasStoredKey = keychain.hasKey(for: provider)
    }

    /// Reloads provider/model from storage — used on appear so a pick made in
    /// `OpenRouterModelPickerView` (which writes `FeedbackSettings` directly)
    /// is reflected as soon as the Settings screen is shown again.
    func reloadFromStorage() {
        isLocal = FeedbackSettings.localModelID != nil
        selectedLocalModelID = FeedbackSettings.localModelID
        provider = FeedbackSettings.provider
        model = FeedbackSettings.model
        refreshKeyStatus()
        refreshLocalState()
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

    // MARK: - On-device mode

    func toggleLocal(_ enable: Bool) {
        isLocal = enable
        if enable {
            let ramGB = max(1, Int(ProcessInfo.processInfo.physicalMemory / 1_000_000_000))
            let defaultID = selectedLocalModelID ?? localService.recommendedModelID(ramGB: ramGB)
            selectLocalModel(defaultID)
        } else {
            FeedbackSettings.localModelID = nil
            selectedLocalModelID = nil
        }
    }

    func selectLocalModel(_ id: String) {
        selectedLocalModelID = id
        FeedbackSettings.localModelID = id
    }

    func startDownload(_ model: LocalModel) {
        localService.startDownload(model)
    }

    func cancelDownload(_ id: String) {
        localService.cancelDownload(id)
    }

    func deleteModel(_ id: String) {
        localService.deleteModel(id)
        if selectedLocalModelID == id {
            FeedbackSettings.localModelID = nil
            selectedLocalModelID = nil
        }
    }

    func isInstalled(_ id: String) -> Bool {
        downloadedIDs.contains(id)
    }

    func isDownloading(_ id: String) -> Bool {
        downloadProgress[id] != nil
    }

    func progress(for id: String) -> Double {
        downloadProgress[id] ?? 0
    }

    private func refreshLocalState() {
        localModels = localService.catalog
        downloadedIDs = localService.downloadedIDs
        downloadProgress = localService.downloadProgress
        if #available(iOS 26, *) {
            appleFoundationStatus = AppleFoundationEngine.statusLabel
        } else {
            appleFoundationStatus = "Requires iOS 26"
        }
    }
}