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
        let dummyMessages: [[String: Any]] = [["role": "user", "content": "hi"]]
        let input = try await container.prepare(input: UserInput(messages: dummyMessages))
        let parameters = GenerateParameters(maxTokens: 1, prefillStepSize: 256)
        
        _ = try await Task.detached(priority: .background) {
            try await container.generate(input: input, parameters: parameters)
        }.value
    }
    
    public func translate(text: String, sourceLang: String?, targetLang: String) async throws -> String {
        recordActivity()
        self.isTranslating = true
        
        // Maximize system resource scheduling during translation
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        MLX.Memory.cacheLimit = Int(Double(physicalMemory) * 0.95)
        
        defer { 
            self.isTranslating = false 
            // Return to conservative memory usage after translation is complete
            MLX.Memory.cacheLimit = Int(Double(physicalMemory) * 0.5)
            MLX.Memory.clearCache()
        }
        
        guard let container = modelContainer else {
            throw NSError(domain: "TranslationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }
        
        let sCode: String
        if let explicitCode = getLanguageCode(sourceLang) {
            sCode = explicitCode
        } else {
            // Automatic Identification using Apple's NaturalLanguage framework
            sCode = detectLanguageCode(for: text)
            logger.info("Auto-detected source language: \(sCode)")
        }
        
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
        
        // Performance Optimization: Use prefillStepSize to speed up initial prompt processing.
        // Smaller steps for larger models (27b) and larger steps for smaller models (4b).
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
            maxTokens: 2048, // Increased from 1024 to allow longer translations
            repetitionPenalty: nil,
            prefillStepSize: prefillStepSize
        )
        
        let stream = try await Task.detached(priority: .userInitiated) {
            try await container.generate(input: input, parameters: parameters)
        }.value
        
        for try await generation in stream {
            if case .chunk(let text) = generation {
                let stopSequences = ["<end_of_turn>", "<eos>", "<|endoftext|>", "</s>"]
                if stopSequences.contains(where: { text.contains($0) }) { break }
                outputText += text
                // Increased limit for output text to match higher maxTokens
                if outputText.count > 20000 { break }
            }
        }
        
        return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getLanguageCode(_ language: String?) -> String? {
        guard let language = language, language != "Auto" else { return nil }
        
        let mapping: [String: String] = [
            "Arabic (Egypt)": "ar_EG",
            "Arabic (Saudi Arabia)": "ar_SA",
            "Bulgarian (Bulgaria)": "bg_BG",
            "Bengali (Bangladesh)": "bn_BD",
            "Bengali (India)": "bn_IN",
            "Catalan (Spain)": "ca_ES",
            "Czech (Czechia)": "cs_CZ",
            "Danish (Denmark)": "da_DK",
            "German (Germany)": "de_DE",
            "Greek (Greece)": "el_GR",
            "Spanish (Mexico)": "es_MX",
            "Estonian (Estonia)": "et_EE",
            "Persian (Farsi)": "fa_IR",
            "Finnish (Finland)": "fi_FI",
            "Filipino (Tagalog)": "fil_PH",
            "French (Canada)": "fr_CA",
            "French (France)": "fr_FR",
            "Gujarati (India)": "gu_IN",
            "Hebrew (Israel)": "he_IL",
            "Hindi (India)": "hi_IN",
            "Croatian (Croatia)": "hr_HR",
            "Hungarian (Hungary)": "hu_HU",
            "Indonesian (Indonesia)": "id_ID",
            "Icelandic (Iceland)": "is_IS",
            "Italian (Italy)": "it_IT",
            "Japanese (Japan)": "ja_JP",
            "Kannada (India)": "kn_IN",
            "Korean (South Korea)": "ko_KR",
            "Lithuanian (Lithuania)": "lt_LT",
            "Latvian (Latvia)": "lv_LV",
            "Malayalam (India)": "ml_IN",
            "Marathi (India)": "mr_IN",
            "Dutch (Netherlands)": "nl_NL",
            "Norwegian (Norway)": "no_NO",
            "Punjabi (India)": "pa_IN",
            "Polish (Poland)": "pl_PL",
            "Portuguese (Brazil)": "pt_BR",
            "Portuguese (Portugal)": "pt_PT",
            "Romanian (Romania)": "ro_RO",
            "Russian (Russia)": "ru_RU",
            "Slovak (Slovakia)": "sk_SK",
            "Slovenian (Slovenia)": "sl_SI",
            "Serbian (Serbia)": "sr_RS",
            "Swedish (Sweden)": "sv_SE",
            "Swahili (Kenya)": "sw_KE",
            "Swahili (Tanzania)": "sw_TZ",
            "Tamil (India)": "ta_IN",
            "Telugu (India)": "te_IN",
            "Thai (Thailand)": "th_TH",
            "Turkish (Turkey)": "tr_TR",
            "Ukrainian (Ukraine)": "uk_UA",
            "Urdu (Pakistan)": "ur_PK",
            "Vietnamese (Vietnam)": "vi_VN",
            "Chinese (Simplified)": "zh_CN",
            "Chinese (Traditional)": "zh_TW",
            "Zulu (South Africa)": "zu_ZA",
            "English": "en"
        ]
        
        return mapping[language] ?? language.lowercased()
    }
    
    private func detectLanguageCode(for text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        // TranslateGemma specifically likes 'zh_CN' or 'zh_TW' for Chinese
        if let languageCode = recognizer.dominantLanguage?.rawValue {
            if languageCode == "zh-Hant" { return "zh_TW" }
            if languageCode.hasPrefix("zh") { return "zh_CN" }
            return languageCode
        }
        
        return "en" // Default fallback
    }
}
