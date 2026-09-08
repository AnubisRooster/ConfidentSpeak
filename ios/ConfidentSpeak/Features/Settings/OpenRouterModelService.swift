import Foundation
import BYOKLLMKit

// MARK: - OpenRouter model catalogue

/// Modality metadata OpenRouter reports for each model. The free catalogue
/// endpoint omits `architecture` for some older entries, so every accessor
/// must tolerate it being nil.
struct OpenRouterArchitecture: Codable, Hashable {
    let modality: String?
    let inputModalities: [String]?
    let outputModalities: [String]?

    enum CodingKeys: String, CodingKey {
        case modality
        case inputModalities = "input_modalities"
        case outputModalities = "output_modalities"
    }
}

struct OpenRouterModel: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let pricing: ModelPricing
    let contextLength: Int
    let architecture: OpenRouterArchitecture?

    /// A model is free when both prompt and completion cost strings are "0".
    var isFree: Bool { pricing.prompt == "0" && pricing.completion == "0" }

    /// The portion after the slash, used for compact display (e.g. "gpt-4o-mini").
    var shortName: String { id.components(separatedBy: "/").last ?? id }

    /// Whether the model can take text in and produce a text answer. Entries
    /// without an `architecture` payload are assumed text-capable so older
    /// catalogue rows keep working.
    var supportsText: Bool {
        let arch = architecture
        let input = (arch?.inputModalities ?? []).map { $0.lowercased() }
        let output = (arch?.outputModalities ?? []).map { $0.lowercased() }
        let mod = (arch?.modality ?? "").lowercased()
        if input.isEmpty && output.isEmpty {
            return mod.contains("text") || mod.isEmpty
        }
        return (input.isEmpty || input.contains("text")) && (output.isEmpty || output.contains("text"))
    }

    /// Whether the model has a speech modality (audio in or out) — omni
    /// models accept and produce audio, TTS-only models output it.
    var supportsSpeech: Bool {
        let arch = architecture
        let input = (arch?.inputModalities ?? []).map { $0.lowercased() }
        let output = (arch?.outputModalities ?? []).map { $0.lowercased() }
        let mod = (arch?.modality ?? "").lowercased()
        return input.contains("audio")
            || output.contains("audio")
            || input.contains("speech")
            || output.contains("speech")
            || mod.contains("audio")
            || mod.contains("speech")
    }

    /// Combines both capabilities — these land at the top of the free list.
    var isTextAndSpeech: Bool { supportsText && supportsSpeech }

    /// Whether this model is worth surfacing in the picker. Every surfaced
    /// model must be text-capable (the feedback call is chat completions);
    /// speech adds value, but audio/video/image-generation-only models,
    /// coding-specialised models, and music/lyrics models (e.g. Google Lyria)
    /// would just confuse the list.
    var isPresentable: Bool {
        guard supportsText else { return false }
        let out = (architecture?.outputModalities ?? []).map { $0.lowercased() }
        let mod = (architecture?.modality ?? "").lowercased()
        if out.contains("image") || out.contains("video") { return false }
        if mod == "image" || mod.hasPrefix("image") { return false }
        let codingKeywords = ["coder", "code-", "codestral", "codellama", "codegemma",
                              "deepcoder", "codegeex", "codeium", "-r1-"]
        if codingKeywords.contains(where: { id.lowercased().contains($0) }) { return false }
        let musicKeywords = ["lyria", "musicgen", "song", "music", "lyrics"]
        if musicKeywords.contains(where: { id.lowercased().contains($0) }) { return false }
        return true
    }

    enum CodingKeys: String, CodingKey {
        case id, name, pricing, architecture
        case contextLength = "context_length"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? id
        // A pricing decode failure must never silently look free (isFree checks
        // for the literal string "0") — that could present a paid model as free
        // and cost a BYOK user money with no warning. Fall back to a value
        // that's unambiguously not "0".
        pricing = (try? c.decode(ModelPricing.self, forKey: .pricing)) ?? ModelPricing(prompt: "unknown", completion: "unknown")
        contextLength = (try? c.decode(Int.self, forKey: .contextLength)) ?? 0
        architecture = (try? c.decode(OpenRouterArchitecture.self, forKey: .architecture))
    }
}

struct ModelPricing: Codable, Hashable {
    let prompt: String
    let completion: String
}

private struct ModelsResponse: Codable {
    let data: [OpenRouterModel]
}

// MARK: - Service

/// Fetches and caches the OpenRouter model catalogue, prioritising free
/// models and, within the free list, those that handle both text and speech.
@MainActor
final class OpenRouterModelService: ObservableObject {

    @Published private(set) var models: [OpenRouterModel] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private let keychain: LLMKeychainStore
    private let cacheKey     = "or_models_cache_v1"
    private let timestampKey = "or_models_timestamp_v1"
    private let maxAge: TimeInterval = 86_400  // 24 h

    init(keychain: LLMKeychainStore = .shared) {
        self.keychain = keychain
        loadCache()
    }

    // MARK: Sorted views

    /// Free models first, then text+speech capable, then by context length.
    var freeModels: [OpenRouterModel] {
        models.filter(\.isFree)
    }

    var paidModels: [OpenRouterModel] {
        models.filter { !$0.isFree }
    }

    /// The model the user currently has selected, if it's still in the catalogue.
    func displayModel(for selectedID: String) -> OpenRouterModel? {
        models.first { $0.id == selectedID }
    }

    // MARK: Fetch

    /// Resolves the OpenRouter key from the Keychain (single source of truth)
    /// and refreshes only if the cache is empty or older than `maxAge`.
    func refreshIfNeeded() async {
        await refreshIfNeeded(apiKey: keychain.get(for: .openrouter) ?? "")
    }

    func refresh() async {
        await refresh(apiKey: keychain.get(for: .openrouter) ?? "")
    }

    func refreshIfNeeded(apiKey: String) async {
        let age = Date().timeIntervalSince1970 - UserDefaults.standard.double(forKey: timestampKey)
        guard models.isEmpty || age > maxAge else { return }
        await refresh(apiKey: apiKey)
    }

    func refresh(apiKey: String) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        // The models endpoint is public, but include the key when present so
        // user-specific availability is reflected.
        var req = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/models")!)
        if !apiKey.isEmpty {
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                lastError = "Model list request failed (HTTP \(http.statusCode))."
                return
            }
            let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
            models = sort(decoded.data).filter(\.isPresentable)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timestampKey)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Helpers

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode(ModelsResponse.self, from: data) else { return }
        models = sort(decoded.data).filter(\.isPresentable)
    }

    /// Free beats paid, text+speech beats text-only, then biggest context wins.
    private func sort(_ list: [OpenRouterModel]) -> [OpenRouterModel] {
        list.sorted { lhs, rhs in
            if lhs.isFree != rhs.isFree { return lhs.isFree }
            let lhsSpeech = lhs.isTextAndSpeech
            let rhsSpeech = rhs.isTextAndSpeech
            if lhsSpeech != rhsSpeech { return lhsSpeech }
            return lhs.contextLength > rhs.contextLength
        }
    }
}