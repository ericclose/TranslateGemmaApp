import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import Tokenizers
import HuggingFace
import os

private let logger = AppLogger.service("TranslationService")

@MainActor
public class TranslationService: ObservableObject {
    @Published public var isTranslating = false
    @Published public var progress: Double = 0
    
    private var modelContainer: ModelContainer?
    private var currentModelId: String?
    
    public init() {}
    
    public func loadModel(modelId: String) async throws {
        logger.info("🏗️ TranslationService: Entering loadModel for \(modelId, privacy: .public)")
        
        await MainActor.run { self.isTranslating = true }
        defer { Task { @MainActor in self.isTranslating = false } }
        
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        MLX.Memory.cacheLimit = Int(Double(physicalMemory) * 0.6)
        
        logger.info("--- Loading Model: \(modelId, privacy: .public) ---")
        
        if currentModelId == modelId && modelContainer != nil { 
            logger.info("Model \(modelId, privacy: .public) already loaded")
            return 
        }
        
        do {
            let configuration = ModelConfiguration(id: modelId)
            
            // Offline-first loading
            let container = try await Task.detached(priority: .high) {
                try await #huggingFaceLoadModelContainer(configuration: configuration)
            }.value
            
            await MainActor.run {
                self.modelContainer = container
                self.currentModelId = modelId
            }
        } catch {
            let errorMsg = "Failed to load model \(modelId): \(error.localizedDescription)"
            logger.error("\(errorMsg, privacy: .public)")
            throw error
        }
    }
    
    public func translate(text: String, sourceLang: String?, targetLang: String) async throws -> String {
        await MainActor.run { self.isTranslating = true }
        defer { Task { @MainActor in self.isTranslating = false } }
        
        guard let container = modelContainer else {
            logger.error("Attempted to translate without model loaded")
            throw NSError(domain: "TranslationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }
        
        if let metallibURL = AppConfiguration.getMetallibURL() {
            logger.debug("Active metallib URL: \(metallibURL.path, privacy: .public)")
        }
        
        let sourceCode = getLanguageCode(sourceLang)
        let targetCode = getLanguageCode(targetLang)
        
        let sCode = sourceCode ?? "auto"
        let tCode = targetCode ?? "zh"
        
        logger.info("Using language codes: \(sCode, privacy: .public) -> \(tCode, privacy: .public)")
        
        // Gemma 3 TranslateGemma requires a specific structured content format
        let content: [String: Any] = [
            "type": "text",
            "text": text,
            "source_lang_code": sCode,
            "target_lang_code": tCode
        ]
        
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": text
            ]
        ]
        
        let structuredMessages: [[String: Any]] = [
            [
                "role": "user",
                "content": [content]
            ]
        ]
        
        let input: LMInput
        do {
            logger.info("TranslateGemma: Preparing structured input...")
            input = try await container.prepare(input: UserInput(messages: structuredMessages))
        } catch {
            logger.info("TranslateGemma: Structured input failed, trying plain text fallback...")
            input = try await container.prepare(input: UserInput(messages: messages))
        }
        
        var outputText = ""
        
        do {
            let parameters = GenerateParameters(maxTokens: 1024, repetitionPenalty: nil)
            logger.info("TranslateGemma: Calling container.generate...")
            // Generation must happen off-main-thread
            let stream = try await Task.detached(priority: .userInitiated) {
                try await container.generate(input: input, parameters: parameters)
            }.value
            
            logger.info("TranslateGemma: Iterating stream...")
            for try await generation in stream {
                if case .chunk(let text) = generation {
                    let stopSequences = ["<end_of_turn>", "<eos>", "<|endoftext|>", "</s>"]
                    if stopSequences.contains(where: { text.contains($0) }) {
                        break
                    }
                    
                    outputText += text
                    
                    if outputText.count > 10000 {
                        break
                    }
                }
            }
        } catch {
            logger.error("Generation error: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        
        return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func formatPrompt(text: String, sourceLang: String?, targetLang: String) -> String {
        if let source = sourceLang {
            return "Translate the following from \(source) to \(targetLang):\n\(text)"
        } else {
            return "Translate the following to \(targetLang):\n\(text)"
        }
    }
    
    private func getLanguageCode(_ language: String?) -> String? {
        guard let language = language, language != "Auto" else { return nil }
        
        let mapping = [
            "English": "en",
            "Chinese": "zh",
            "Japanese": "ja",
            "French": "fr",
            "German": "de",
            "Spanish": "es",
            "Korean": "ko",
            "Russian": "ru"
        ]
        
        return mapping[language] ?? language.lowercased()
    }
    
    private func log(message: String, type: OSLogType = .default) {
        logger.log(level: type, "\(message, privacy: .public)")
    }
}
