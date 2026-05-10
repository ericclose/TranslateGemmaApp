import Foundation
import MLX
import MLXLLM
import TranslateGemmaLibrary

@main
struct Diagnostic {
    static func main() async {
        print("--- TranslateGemma Diagnostic Tool ---")
        let service = TranslationService()
        let modelId = "mlx-community/translategemma-4b-it-4bit"
        
        print("1. Initializing GPU...")
        MLX.Memory.cacheLimit = 2 * 1024 * 1024 * 1024 // Use a smaller limit for diagnostic
        
        print("2. Loading Model: \(modelId)...")
        do {
            try await service.loadModel(modelId: modelId)
            print("SUCCESS: Model loaded.")
        } catch {
            print("ERROR during loadModel: \(error)")
            return
        }
        
        print("3. Testing Translation: 'Hello'...")
        do {
            let result = try await service.translate(text: "Hello", sourceLang: "English", targetLang: "Chinese")
            print("SUCCESS: Translation result: '\(result)'")
        } catch {
            print("ERROR during translate: \(error)")
        }
        
        print("--- Diagnostic Finished ---")
    }
}
