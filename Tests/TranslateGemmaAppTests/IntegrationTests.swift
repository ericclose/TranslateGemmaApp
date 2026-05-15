import XCTest
@testable import TranslateGemmaKit

final class IntegrationTests: XCTestCase {
    
    let modelId = "mlx-community/translategemma-4b-it-4bit"
    
    func testExtraLongTextTranslation() async throws {
        let service = await TranslationService()
        try await service.loadModel(modelId: modelId)
        
        let repeatedSentence = "Hello, how are you? I hope you are doing well today. "
        // Around 2650 characters, triggering TextSplitter
        let longText = String(repeating: repeatedSentence, count: 50) 
        
        let result = try await service.translate(text: longText, sourceLang: "English", targetLang: "Chinese (Simplified)")
        
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.count > 200, "Translation result should be substantially long")
        print("Long translation output length: \\(result.count)")
    }
    
    func testMarkdownFileTranslation() async throws {
        let controller = TranslationController()
        let service = await TranslationService()
        
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test.md")
        let mdContent = """
        ---
        title: Test
        ---
        # Heading 1
        This is a test paragraph.
        """
        try mdContent.write(to: tempFile, atomically: true, encoding: .utf8)
        
        controller.addFiles([tempFile], defaultTargetLang: "Chinese (Simplified)")
        await controller.runBatch(translationService: service, selectedModelId: modelId)
        
        let outputURL = tempFile.deletingLastPathComponent().appendingPathComponent("test.zh.md")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path), "Output file should be created")
        
        if let translatedContent = try? String(contentsOf: outputURL) {
            XCTAssertTrue(translatedContent.contains("---"))
            XCTAssertTrue(translatedContent.contains("title: Test"))
            XCTAssertTrue(translatedContent.contains("#"))
        } else {
            XCTFail("Could not read output file")
        }
        
        try? FileManager.default.removeItem(at: tempFile)
        try? FileManager.default.removeItem(at: outputURL)
    }
    
    func testTranslationControllerStateUpdates() async throws {
        let controller = TranslationController()
        let service = await TranslationService()
        
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("ui_test.srt")
        let srtContent = """
        1
        00:00:01,000 --> 00:00:02,000
        Hello world!
        """
        try srtContent.write(to: tempFile, atomically: true, encoding: .utf8)
        
        controller.addFiles([tempFile], defaultTargetLang: "Chinese (Simplified)")
        XCTAssertEqual(controller.tasks.count, 1)
        XCTAssertEqual(controller.tasks[0].status, .pending)
        
        await controller.runBatch(translationService: service, selectedModelId: modelId)
        
        if case .completed = controller.tasks[0].status {
            XCTAssertTrue(true)
        } else {
            XCTFail("Task status should be completed, but was \\(controller.tasks[0].status)")
        }
        
        try? FileManager.default.removeItem(at: tempFile)
        let outPath = tempFile.deletingLastPathComponent().appendingPathComponent("ui_test.zh.srt")
        try? FileManager.default.removeItem(at: outPath)
    }
    
    func testTxtFileTranslation() async throws {
        let controller = TranslationController()
        let service = await TranslationService()
        
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        let txtContent = "Hello. This is a text file that should not be empty after translation. The pipeline should correctly yield chunks and write them properly."
        try txtContent.write(to: tempFile, atomically: true, encoding: .utf8)
        
        controller.addFiles([tempFile], defaultTargetLang: "Chinese (Simplified)")
        await controller.runBatch(translationService: service, selectedModelId: modelId)
        
        let outputURL = tempFile.deletingLastPathComponent().appendingPathComponent("test.zh.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path), "TXT output file should be created")
        
        if let translatedContent = try? String(contentsOf: outputURL) {
            XCTAssertFalse(translatedContent.isEmpty, "TXT file output should NOT be empty")
            print("TXT translation output length: \\(translatedContent.count)")
        } else {
            XCTFail("Could not read TXT output file")
        }
        
        try? FileManager.default.removeItem(at: tempFile)
        try? FileManager.default.removeItem(at: outputURL)
    }
}
