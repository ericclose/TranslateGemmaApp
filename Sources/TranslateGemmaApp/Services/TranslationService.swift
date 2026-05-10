import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import Tokenizers
import Hub
import HuggingFace

@MainActor
class TranslationService: ObservableObject {
    @Published var isTranslating = false
    @Published var progress: Double = 0
    
    private var modelContainer: ModelContainer?
    private var currentModelId: String?
    
    init() {}
    
    func loadModel(modelId: String) async throws {
        if currentModelId == modelId && modelContainer != nil { return }
        
        let configuration = ModelConfiguration(id: modelId)
        
        // Use the MLXHuggingFace macro to load the container
        self.modelContainer = try await #huggingFaceLoadModelContainer(configuration: configuration)
        self.currentModelId = modelId
    }
    
    func translate(text: String, sourceLang: String?, targetLang: String) async throws -> String {
        guard let container = modelContainer else {
            throw NSError(domain: "TranslationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }
        
        let prompt = formatPrompt(text: text, sourceLang: sourceLang, targetLang: targetLang)
        let input = try await container.prepare(input: UserInput(prompt: .text(prompt)))
        
        self.isTranslating = true
        var outputText = ""
        
        do {
            let stream = try await container.generate(input: input, parameters: GenerateParameters())
            for try await generation in stream {
                if case .chunk(let text) = generation {
                    outputText += text
                }
            }
        } catch {
            print("Translation error: \(error)")
        }
        
        self.isTranslating = false
        return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func formatPrompt(text: String, sourceLang: String?, targetLang: String) -> String {
        let instruction: String
        if let source = sourceLang {
            instruction = "Translate the following from \(source) to \(targetLang):"
        } else {
            instruction = "Translate the following to \(targetLang):"
        }
        
        return """
        <start_of_turn>user
        \(instruction)
        \(text)<end_of_turn>
        <start_of_turn>model
        """
    }
}
