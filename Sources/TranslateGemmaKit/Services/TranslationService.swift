import Foundation
import AppKit
import NaturalLanguage
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
    public var totalTimeTaken: TimeInterval? = nil
    
    private var globalStartTime: Date?
    private var globalTokenCount: Int = 0
    
    private var isBatchSessionActive: Bool = false
    
    private var modelContainer: ModelContainer?
    private var currentModelId: String?
    private let logger = AppLogger.service("TranslationService")
    
    // Auto Unload logic
    private var lastActivityTime = Date()
    private var autoUnloadTimer: Timer?
    private var isBackgrounded = false
    private let unloadThreshold: TimeInterval = 10 * 60 // 10 minutes
    
    public init() {
        setupAutoUnloadTimer()
        setupNotificationObservers()
    }
    
    public func recordActivity() {
        self.lastActivityTime = Date()
        self.logger.debug("Activity recorded at \(self.lastActivityTime)")
    }
    
    public func setBackgrounded(_ backgrounded: Bool) {
        isBackgrounded = backgrounded
        logger.debug("App backgrounded: \(backgrounded)")
        if backgrounded {
            // Check immediately when going to background
            checkAutoUnload()
        }
    }
    
    private func setupAutoUnloadTimer() {
        autoUnloadTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAutoUnload()
            }
        }
    }
    
    private func setupNotificationObservers() {
        #if os(macOS)
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.setBackgrounded(true)
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.setBackgrounded(false)
                self?.recordActivity()
            }
        }
        #endif
    }
    
    private func checkAutoUnload() {
        guard modelContainer != nil, !isTranslating else { return }
        
        let idleTime = Date().timeIntervalSince(lastActivityTime)
        
        if idleTime >= unloadThreshold || self.isBackgrounded {
            logger.info("Auto unloading model due to \(self.isBackgrounded ? "background state" : "inactivity (\(Int(idleTime))s)")")
            unloadModel()
        }
    }
    
    public func unloadModel() {
        modelContainer = nil
        currentModelId = nil
        MLX.Memory.clearCache()
        logger.info("Model unloaded and cache cleared.")
    }
    
    public func loadModel(modelId: String) async throws {
        self.isTranslating = true
        defer { self.isTranslating = false }
        
        // Startup: Set a conservative memory limit to avoid high idle usage.
        // The limit will be dynamically increased to 95% during active translation.
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        MLX.Memory.cacheLimit = Int(Double(physicalMemory) * 0.5)
        
        if currentModelId == modelId && modelContainer != nil { return }
        
        let configuration = ModelConfiguration(id: modelId)
        let container = try await Task.detached(priority: .high) {
            try await #huggingFaceLoadModelContainer(configuration: configuration)
        }.value
        
        self.modelContainer = container
        self.currentModelId = modelId
    }
    
    public func prewarm() async throws {
        guard let container = modelContainer else { return }
        
        // Performance: Trigger a small generation to warm up the GPU and compile kernels
        let content: [String: Sendable] = [
            "type": "text",
            "source_lang_code": "en",
            "target_lang_code": "zh",
            "text": "hi"
        ]
        let dummyMessages: [[String: Sendable]] = [["role": "user", "content": [content]]]
        let parameters = GenerateParameters(maxTokens: 1, prefillStepSize: 256)
        
        _ = try await Task.detached(priority: .background) {
            let input = try await container.prepare(input: UserInput(messages: dummyMessages as [[String: Any]]))
            return try await container.generate(input: input, parameters: parameters)
        }.value
    }
    
    public func translate(text: String, sourceLang: String?, targetLang: String, onChunk: ((String) throws -> Void)? = nil) async throws -> String {
        recordActivity()
        self.isTranslating = true
        if !isBatchSessionActive {
            self.totalTimeTaken = nil
            self.globalStartTime = Date()
            self.globalTokenCount = 0
        }
        
        // Maximize system resource scheduling during translation
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        MLX.Memory.cacheLimit = Int(Double(physicalMemory) * 0.95)
        
        defer { 
            if !isBatchSessionActive {
                self.isTranslating = false
                if let startTime = self.globalStartTime {
                    let totalElapsed = Date().timeIntervalSince(startTime)
                    self.totalTimeTaken = totalElapsed
                }
                // Return to conservative memory usage after translation is complete
                MLX.Memory.cacheLimit = Int(Double(physicalMemory) * 0.5)
                MLX.Memory.clearCache()
            }
        }
        
        guard let container = modelContainer else {
            throw NSError(domain: "TranslationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }
        
        let chunks = TextSplitter.split(text: text, maxChunkLength: 1500)
        var fullOutput = ""
        
        for chunk in chunks {
            try Task.checkCancellation()
            
            let chunkOutput = try await translateChunk(text: chunk.text, sourceLang: sourceLang, targetLang: targetLang, container: container, onChunk: onChunk)
            fullOutput += chunkOutput + chunk.separator
            
            if !chunk.separator.isEmpty {
                try onChunk?(chunk.separator)
            }
        }
        
        return fullOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func startBatchSession(estimatedTokens: Int) {
        self.isBatchSessionActive = true
        self.totalTimeTaken = nil
        self.globalStartTime = Date()
        self.globalTokenCount = 0
        self.isTranslating = true
    }
    
    
    public func endBatchSession() {
        self.isBatchSessionActive = false
        self.isTranslating = false
        if let startTime = self.globalStartTime {
            let totalElapsed = Date().timeIntervalSince(startTime)
            self.totalTimeTaken = totalElapsed
        }
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        MLX.Memory.cacheLimit = Int(Double(physicalMemory) * 0.5)
        MLX.Memory.clearCache()
    }
    
    private func translateChunk(text: String, sourceLang: String?, targetLang: String, container: ModelContainer, onChunk: ((String) throws -> Void)?) async throws -> String {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        let sLangCode = getLanguageCode(sourceLang) ?? detectLanguageCode(for: text)
        let tLangCode = getLanguageCode(targetLang) ?? "zh"
        
        let content: [String: Sendable] = [
            "type": "text",
            "source_lang_code": sLangCode,
            "target_lang_code": tLangCode,
            "text": text
        ]
        
        let messages: [[String: Sendable]] = [["role": "user", "content": [content]]]
        
        var outputText = ""
        var chunkCount = 0        
        // Performance Optimization: Use prefillStepSize to speed up initial prompt processing.
        let prefillStepSize: Int
        if let modelId = currentModelId {
            if modelId.contains("27b") {
                prefillStepSize = 64
            } else if modelId.contains("12b") {
                prefillStepSize = 128
            } else {
                prefillStepSize = 256
            }
        } else {
            prefillStepSize = 128
        }
        
        let parameters = GenerateParameters(
            maxTokens: 2048,
            repetitionPenalty: nil,
            prefillStepSize: prefillStepSize
        )
        
        let stream = try await Task.detached(priority: .userInitiated) {
            let input = try await container.prepare(input: UserInput(messages: messages as [[String: Any]]))
            return try await container.generate(input: input, parameters: parameters)
        }.value
        
        for try await generation in stream {
            try Task.checkCancellation()
            if case .chunk(let genText) = generation {
                chunkCount += 1
                if chunkCount <= 3 {
                    print("--- DEBUG: Chunk \(chunkCount): [\(genText)] ---")
                }
                self.globalTokenCount += 1

                let stopSequences = ["<end_of_turn>", "<eos>", "<|endoftext|>", "</s>"]
                if stopSequences.contains(where: { genText.contains($0) }) { break }
                outputText += genText
                try onChunk?(genText)
                if outputText.count > 20000 { break }
            }
        }
        
        return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getLanguageCode(_ language: String?) -> String? {
        guard let language = language, language != "Auto" else { return nil }
        return LanguageManager.getCode(for: language)
    }
    
    private func detectLanguageCode(for text: String) -> String {
        return LanguageManager.detectLanguageCode(for: text)
    }
}
