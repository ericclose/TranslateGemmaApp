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

public class TranslationService: ObservableObject {
    @Published public var isTranslating = false
    @Published public var progress: Double = 0
    
    private var modelContainer: ModelContainer?
    private var currentModelId: String?
    
    public init() {}
    
    public func loadModel(modelId: String) async throws {
        // Use the modern API to set memory limits
        MLX.Memory.cacheLimit = 8 * 1024 * 1024 * 1024 // 8GB
        
        logToFile("--- Loading Model: \(modelId) ---")
        
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
    
    public func translate(text: String, sourceLang: String?, targetLang: String) async throws -> String {
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
            logToFile("Starting generation with prompt length: \(prompt.count)")
            // explicitly set repetitionPenalty to nil to avoid broadcast issues with Gemma models
            // and add maxTokens to prevent runaway generation
            let parameters = GenerateParameters(maxTokens: 2048, repetitionPenalty: nil)
            
            logToFile("Calling container.generate...")
            let stream = try await container.generate(input: input, parameters: parameters)
            
            logToFile("Iterating stream...")
            for try await generation in stream {
                if case .chunk(let text) = generation {
                    outputText += text
                }
            }
            logToFile("Translation finished. Result length: \(outputText.count)")
        } catch {
            logToFile("CRITICAL ERROR during generation: \(error.localizedDescription)")
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
    
    private func logToFile(_ message: String) {
        let logPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/TranslateGemma_Debug.log")
        let timestamp = Date().description
        let fullMessage = "[\(timestamp)] \(message)\n"
        
        if let data = fullMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logPath)
            }
        }
        print(message)
    }
}
