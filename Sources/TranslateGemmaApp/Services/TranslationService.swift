import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import Tokenizers
import Hub
import HuggingFace
import os

private let logger = Logger(subsystem: "com.translategemma.app", category: "TranslationService")

class TranslationService: ObservableObject {
    @Published var isTranslating = false
    @Published var progress: Double = 0
    
    private var modelContainer: ModelContainer?
    private var currentModelId: String?
    
    init() {
        // Limit GPU cache to prevent out-of-memory crashes or system freezes
        // Even with 32GB, MLX can sometimes be too aggressive
        MLX.GPU.set(cacheLimit: 8 * 1024 * 1024 * 1024) // 8GB cache limit
    }
    
    func loadModel(modelId: String) async throws {
        if currentModelId == modelId && modelContainer != nil { 
            logger.info("Model \(modelId) already loaded")
            return 
        }
        
        logger.info("Loading model: \(modelId)")
        let configuration = ModelConfiguration(id: modelId)
        
        do {
            logger.info("Calling #huggingFaceLoadModelContainer...")
            let container = try await #huggingFaceLoadModelContainer(configuration: configuration)
            await MainActor.run {
                self.modelContainer = container
                self.currentModelId = modelId
            }
            logger.info("Model loaded successfully: \(modelId)")
        } catch {
            logger.error("Failed to load model \(modelId): \(error.localizedDescription)")
            print("Failed to load model: \(error)")
            throw error
        }
    }
    
    func translate(text: String, sourceLang: String?, targetLang: String) async throws -> String {
        guard let container = modelContainer else {
            logger.error("Attempted to translate without model loaded")
            throw NSError(domain: "TranslationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }
        
        logger.info("Starting translation for: \(text.prefix(50))...")
        
        let prompt = formatPrompt(text: text, sourceLang: sourceLang, targetLang: targetLang)
        
        logger.info("Preparing input...")
        let input: LMInput
        do {
            // Use the built-in template system instead of manual tags
            // This is safer for Gemma 2 models which have complex templates
            let messages = [["role": "user", "content": prompt]]
            input = try await container.prepare(input: UserInput(messages: messages))
        } catch {
            logger.error("Failed to prepare input: \(error.localizedDescription)")
            throw error
        }
        
        await MainActor.run { self.isTranslating = true }
        var outputText = ""
        
        do {
            logger.info("Starting generation...")
            // explicitly set repetitionPenalty to nil to avoid broadcast issues with Gemma models
            // and add maxTokens to prevent runaway generation
            let parameters = GenerateParameters(maxTokens: 2048, repetitionPenalty: nil)
            let stream = try await container.generate(input: input, parameters: parameters)
            
            for try await generation in stream {
                if case .chunk(let text) = generation {
                    outputText += text
                }
            }
            logger.info("Translation finished. Length: \(outputText.count)")
        } catch {
            logger.error("Translation error during generation: \(error.localizedDescription)")
            print("Translation error: \(error)")
            await MainActor.run { self.isTranslating = false }
            throw error
        }
        
        await MainActor.run { self.isTranslating = false }
        return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func formatPrompt(text: String, sourceLang: String?, targetLang: String) -> String {
        if let source = sourceLang {
            return "Translate the following from \(source) to \(targetLang):\n\(text)"
        } else {
            return "Translate the following to \(targetLang):\n\(text)"
        }
    }
}
