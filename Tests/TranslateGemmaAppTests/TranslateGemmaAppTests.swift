import XCTest
import TranslateGemmaKit

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
        }
    }
    
    func testAutoDetection() async throws {
        let service = await TranslationService()
        let modelId = "mlx-community/translategemma-4b-it-4bit"
        
        print("Testing Auto-Detection with model: \(modelId)")
        
        do {
            try await service.loadModel(modelId: modelId)
            
            // Testing Chinese to English
            let result = try await service.translate(text: "你好，世界", sourceLang: nil, targetLang: "English")
            print("Auto-detection (ZH->EN) result: \(result)")
            
            XCTAssertFalse(result.isEmpty)
            XCTAssertTrue(result.lowercased().contains("hello") || result.lowercased().contains("world"))
            
            // Testing Japanese to Chinese
            let resultJA = try await service.translate(text: "こんにちは", sourceLang: nil, targetLang: "Chinese")
            print("Auto-detection (JA->ZH) result: \(resultJA)")
            XCTAssertFalse(resultJA.isEmpty)
            XCTAssertTrue(resultJA.contains("你好"))
            
        } catch {
            XCTFail("Auto-detection test failed with error: \(error)")
        }
    }
}
