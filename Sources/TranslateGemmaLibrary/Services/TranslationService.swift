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
        // Set cache limit to 60% of physical memory (e.g., ~19GB on a 32GB machine)
        // This allows high-end machines to use their full potential while keeping low-end machines safe.
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        MLX.Memory.cacheLimit = Int(Double(physicalMemory) * 0.6)
        
        logToFile("--- Loading Model: \(modelId) ---")
        
        if currentModelId == modelId && modelContainer != nil { 
            logger.info("Model \(modelId) already loaded")
            return 
        }
        
        logger.info("Loading model: \(modelId)")
        let configuration = ModelConfiguration(id: modelId)
        
        do {
            logger.info("Calling #huggingFaceLoadModelContainer...")
            // Offload from main thread
            let container = try await Task.detached(priority: .userInitiated) {
                try await #huggingFaceLoadModelContainer(configuration: configuration)
            }.value
            
            await MainActor.run {
                self.modelContainer = container
                self.currentModelId = modelId
            }
            logger.info("Model loaded successfully: \(modelId)")
            logToFile("Model loaded successfully: \(modelId)")
        } catch {
            let errorMsg = "Failed to load model \(modelId): \(error.localizedDescription)"
            logger.error("\(errorMsg)")
            logToFile("CRITICAL ERROR: \(errorMsg)")
            throw error
        }
    }
    
    public func translate(text: String, sourceLang: String?, targetLang: String) async throws -> String {
        guard let container = modelContainer else {
            logger.error("Attempted to translate without model loaded")
            throw NSError(domain: "TranslationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }
        
        logger.info("Starting translation for: \(text.prefix(50))...")
        
        // Resource Diagnostic - Look in all possible bundles
        var foundPath: String? = Bundle.main.path(forResource: "default", ofType: "metallib")
        
        if foundPath == nil {
            // Fallback for command line or nested bundles
            for bundle in Bundle.allBundles {
                if let path = bundle.path(forResource: "default", ofType: "metallib") {
                    foundPath = path
                    break
                }
            }
        }

        if let path = foundPath {
            logToFile("Diagnostic: Found default.metallib at \(path)")
        } else {
            logToFile("Diagnostic WARNING: default.metallib NOT found in any bundle")
        }
        
        let sourceCode = getLanguageCode(sourceLang)
        let targetCode = getLanguageCode(targetLang)
        
        let sCode = sourceCode ?? "auto"
        let tCode = targetCode ?? "zh"
        
        logToFile("Using language codes: \(sCode) -> \(tCode)")
        
        // Gemma 3 TranslateGemma requires a specific structured content format
        // Some versions of MLXLLM prefer a single dictionary for content if it's text-only
        let content: [String: Any] = [
            "type": "text",
            "text": text,
            "source_lang_code": sCode,
            "target_lang_code": tCode
        ]
        
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": text // Fallback to plain text if structured content fails
            ]
        ]
        
        // Let's try to prepare with structured content first
        let structuredMessages: [[String: Any]] = [
            [
                "role": "user",
                "content": [content]
            ]
        ]
        
        let input: LMInput
        do {
            NSLog("TranslateGemma: Preparing structured input...")
            input = try await container.prepare(input: UserInput(messages: structuredMessages))
        } catch {
            NSLog("TranslateGemma: Structured input failed, trying plain text fallback...")
            input = try await container.prepare(input: UserInput(messages: messages))
        }
        
        await MainActor.run { self.isTranslating = true }
        var outputText = ""
        
        do {
            logToFile("Starting generation with text length: \(text.count)")
            let parameters = GenerateParameters(maxTokens: 1024, repetitionPenalty: nil)
            
            NSLog("TranslateGemma: Calling container.generate...")
            // Generation must happen off-main-thread
            let stream = try await Task.detached(priority: .userInitiated) {
                try await container.generate(input: input, parameters: parameters)
            }.value
            
            NSLog("TranslateGemma: Iterating stream...")
            for try await generation in stream {
                if case .chunk(let text) = generation {
                    // Gemma 3 manual EOS check - more robust detection
                    let stopSequences = ["<end_of_turn>", "<eos>", "<|endoftext|>", "</s>"]
                    if stopSequences.contains(where: { text.contains($0) }) {
                        logToFile("Detected EOS/Stop sequence in chunk. Breaking.")
                        break
                    }
                    
                    outputText += text
                    
                    // Safety break for extremely long translations
                    if outputText.count > text.count * 10 {
                         if outputText.count > 10000 {
                             logToFile("Safety limit reached. Breaking.")
                             break
                         }
                    }
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
    
    private func logToFile(_ message: String) {
        // Use NSLog for system-level logging
        NSLog("TranslateGemma: %@", message)
        
        // Use a safe sandbox-friendly path for the debug log
        let fileManager = FileManager.default
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let logPath = cachesURL.appendingPathComponent("TranslateGemma_Debug.log")
        
        let timestamp = Date().description
        let fullMessage = "[\(timestamp)] \(message)\n"
        
        if let data = fullMessage.data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: logPath) {
                defer { try? fileHandle.close() }
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
            } else {
                try? data.write(to: logPath, options: .atomic)
            }
        }
    }
}
