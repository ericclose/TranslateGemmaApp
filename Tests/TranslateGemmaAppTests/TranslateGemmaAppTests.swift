import XCTest
import TranslateGemmaLibrary

final class TranslateGemmaAppTests: XCTestCase {
    func testTranslation() async throws {
        let service = await TranslationService()
        let modelId = "mlx-community/translategemma-4b-it-4bit"
        
        print("Testing with model: \(modelId)")
        
        do {
            try await service.loadModel(modelId: modelId)
            print("Model loaded")
            
            let result = try await service.translate(text: "Hello", sourceLang: "English", targetLang: "Chinese")
            print("Translation result: \(result)")
            
            XCTAssertFalse(result.isEmpty)
        } catch {
            XCTFail("Translation failed with error: \(error)")
        }
    }
}
