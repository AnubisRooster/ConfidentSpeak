import Testing
import Foundation
import BYOKLLMKit
@testable import ConfidentSpeak

/// Covers `OpenRouterModel` decoding and the free / text+speech prioritisation
/// that `OpenRouterModelService` applies to the OpenRouter catalogue. Fixtures
/// are decoded from local JSON — no network calls run in tests.
private func makeModels() throws -> [OpenRouterModel] {
    let json = """
    {
      "data": [
        {
          "id": "qwen/qwen2.5-omni-7b",
          "name": "Qwen2.5 Omni 7B",
          "pricing": { "prompt": "0", "completion": "0" },
          "context_length": 32768,
          "architecture": {
            "modality": "text+audio->text+audio",
            "input_modalities": ["text", "audio"],
            "output_modalities": ["text", "audio"]
          }
        },
        {
          "id": "meta-llama/llama-3.3-70b-instruct:free",
          "name": "Llama 3.3 70B Instruct (free)",
          "pricing": { "prompt": "0", "completion": "0" },
          "context_length": 131072,
          "architecture": {
            "modality": "text->text",
            "input_modalities": ["text"],
            "output_modalities": ["text"]
          }
        },
        {
          "id": "openai/gpt-4o-mini",
          "name": "GPT-4o mini",
          "pricing": { "prompt": "0.00015", "completion": "0.0006" },
          "context_length": 128000
        },
        {
          "id": "stabilityai/stable-diffusion-xl",
          "name": "Stable Diffusion XL",
          "pricing": { "prompt": "0", "completion": "0" },
          "context_length": 100000,
          "architecture": {
            "modality": "text->image",
            "input_modalities": ["text"],
            "output_modalities": ["image"]
          }
        },
        {
          "id": "qwen/qwen2.5-coder-32b-instruct",
          "name": "Qwen2.5 Coder 32B",
          "pricing": { "prompt": "0", "completion": "0" },
          "context_length": 32768,
          "architecture": {
            "modality": "text->text",
            "input_modalities": ["text"],
            "output_modalities": ["text"]
          }
        },
        {
          "id": "openai/gpt-4o-mini-tts",
          "name": "GPT-4o mini TTS",
          "pricing": { "prompt": "0.00002", "completion": "0" },
          "context_length": 16000,
          "architecture": {
            "modality": "text->audio",
            "input_modalities": ["text"],
            "output_modalities": ["audio"]
          }
        },
        {
          "id": "google/lyria-mini-1b",
          "name": "Google Lyria Mini 1B",
          "pricing": { "prompt": "0", "completion": "0" },
          "context_length": 32000,
          "architecture": {
            "modality": "text->audio",
            "input_modalities": ["text"],
            "output_modalities": ["audio"]
          }
        }
      ]
    }
    """
    let response = try JSONDecoder().decode(ModelsResponseFixture.self, from: Data(json.utf8))
    return response.data
}

/// Test-only mirror of the private `ModelsResponse` wire type.
private struct ModelsResponseFixture: Codable {
    let data: [OpenRouterModel]
}

/// Translation of `OpenRouterModelService.sort` applied the same way the
/// service does: drop non-presentable models first, then free beats paid,
/// text+speech beats text-only, then largest context.
private func priorityOrder(_ list: [OpenRouterModel]) -> [OpenRouterModel] {
    list.filter(\.isPresentable).sorted { lhs, rhs in
        if lhs.isFree != rhs.isFree { return lhs.isFree }
        let l = lhs.isTextAndSpeech
        let r = rhs.isTextAndSpeech
        if l != r { return l }
        return lhs.contextLength > rhs.contextLength
    }
}

struct OpenRouterModelServiceTests {

    @Test func decodesAllFixtures() throws {
        let models = try makeModels()
        #expect(models.count == 7)
        #expect(models[0].id == "qwen/qwen2.5-omni-7b")
        // Entry without `architecture` keeps working.
        #expect(models[2].name == "GPT-4o mini")
        #expect(models[2].contextLength == 128000)
    }

    @Test func freeDetectionUsesLiteralZeroPricing() throws {
        let models = try makeModels()
        #expect(models[0].isFree)   // omni, 0/0
        #expect(models[1].isFree)   // llama, 0/0
        #expect(models[4].isFree)   // coder, 0/0
        #expect(!models[2].isFree)  // gpt-4o-mini paid
        #expect(!models[5].isFree)  // tts paid
    }

    @Test func pricingDecodeFailureNeverLooksFree() throws {
        let json = """
        { "data": [
          { "id": "x/y", "name": "Broken pricing", "pricing": { "prompt": 5, "completion": 0 }, "context_length": 1000 }
        ] }
        """
        let response = try JSONDecoder().decode(ModelsResponseFixture.self, from: Data(json.utf8))
        let model = response.data[0]
        #expect(model.pricing.prompt == "unknown")
        #expect(!model.isFree)
    }

    @Test func textAndSpeechDetection() throws {
        let models = try makeModels()
        #expect(models[0].supportsText && models[0].supportsSpeech && models[0].isTextAndSpeech)
        #expect(models[1].supportsText && !models[1].supportsSpeech && !models[1].isTextAndSpeech)
        // No architecture reported → assumed text-capable, not speech.
        #expect(models[2].supportsText && !models[2].supportsSpeech)
        // TTS-only model is speech but not text-out capable.
        #expect(!models[5].supportsText && models[5].supportsSpeech)
    }

    @Test func presentableExcludesImageGenCodingTTSAndMusicModels() throws {
        let models = try makeModels()
        let presentable = models.filter(\.isPresentable).map(\.id)
        #expect(presentable.contains("qwen/qwen2.5-omni-7b"))
        #expect(presentable.contains("meta-llama/llama-3.3-70b-instruct:free"))
        #expect(presentable.contains("openai/gpt-4o-mini"))
        #expect(!presentable.contains("stabilityai/stable-diffusion-xl"))
        #expect(!presentable.contains("qwen/qwen2.5-coder-32b-instruct"))
        #expect(!presentable.contains("openai/gpt-4o-mini-tts"))
        // Google Lyria is a music/lyrics generator — never a speaking coach.
        #expect(!presentable.contains("google/lyria-mini-1b"))
    }

    @Test func prioritisesFreeThenTextAndSpeechThenContext() throws {
        let sorted = try priorityOrder(makeModels())
        #expect(sorted[0].id == "qwen/qwen2.5-omni-7b")       // free + text/speech
        #expect(sorted[1].id == "meta-llama/llama-3.3-70b-instruct:free") // free + text only, biggest free context
        #expect(sorted[2].id == "openai/gpt-4o-mini")          // first paid entry
        #expect(sorted[2].isFree == false)
    }
}