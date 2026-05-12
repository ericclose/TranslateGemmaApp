import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import Tokenizers
import HuggingFace
import Observation
import os

@Observable
@MainActor
public class TranslationService {
    public var isTranslating = false
    public var progress: Double = 0
    
    private var modelContainer: ModelContainer?
    private var currentModelId: String?
    private let logger = AppLogger.service("TranslationService")
    
    public init() {}
    
    public func loadModel(modelId: String) async throws {
        self.isTranslating = true
        defer { self.isTranslating = false }
        
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        MLX.Memory.cacheLimit = Int(Double(physicalMemory) * 0.6)
        
        if currentModelId == modelId && modelContainer != nil { return }
        
        let configuration = ModelConfiguration(id: modelId)
        let container = try await Task.detached(priority: .high) {
            try await #huggingFaceLoadModelContainer(configuration: configuration)
        }.value
        
        self.modelContainer = container
        self.currentModelId = modelId
    }
    
    public func translate(text: String, sourceLang: String?, targetLang: String) async throws -> String {
        self.isTranslating = true
        defer { self.isTranslating = false }
        
        guard let container = modelContainer else {
            throw NSError(domain: "TranslationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }
        
        let sCode = getLanguageCode(sourceLang) ?? "auto"
        let tCode = getLanguageCode(targetLang) ?? "zh"
        
        let content: [String: Any] = [
            "type": "text",
            "text": text,
            "source_lang_code": sCode,
            "target_lang_code": tCode
        ]
        
        let messages: [[String: Any]] = [["role": "user", "content": text]]
        let structuredMessages: [[String: Any]] = [["role": "user", "content": [content]]]
        
        let input: LMInput
        do {
            input = try await container.prepare(input: UserInput(messages: structuredMessages))
        } catch {
            input = try await container.prepare(input: UserInput(messages: messages))
        }
        
        var outputText = ""
        let parameters = GenerateParameters(maxTokens: 1024, repetitionPenalty: nil)
        
        let stream = try await Task.detached(priority: .userInitiated) {
            try await container.generate(input: input, parameters: parameters)
        }.value
        
        for try await generation in stream {
            if case .chunk(let text) = generation {
                let stopSequences = ["<end_of_turn>", "<eos>", "<|endoftext|>", "</s>"]
                if stopSequences.contains(where: { text.contains($0) }) { break }
                outputText += text
                if outputText.count > 10000 { break }
            }
        }
        
        return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getLanguageCode(_ language: String?) -> String? {
        guard let language = language, language != "Auto" else { return nil }
        let mapping = ["English": "en", "Chinese": "zh", "Japanese": "ja", "French": "fr", "German": "de", "Spanish": "es", "Korean": "ko", "Russian": "ru"]
        return mapping[language] ?? language.lowercased()
    }
}
