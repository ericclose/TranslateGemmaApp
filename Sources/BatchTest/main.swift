import Foundation
import TranslateGemmaKit
import MLX

@MainActor
class AutomationTester {
    let sourceDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads/test")
    let exportDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads/test2")
    let reportPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/TranslateGemma_TestReport.md")
    
    let modelId = "mlx-community/translategemma-4b-it-4bit"
    var reportContent = "# TranslateGemma Automation Test Report\n\n"
    
    func run() async {
        print("🚀 Starting Automation Test Suite...")
        reportContent += "Generated on: \(Date())\n\n"
        
        // 1. System & Model Check
        await testModelLoading()
        
        // 2. Plain Text Translation Tests
        await testPlainTextTranslation()
        
        // 3. File Mode Translation Tests (Batch)
        await testFileModeTranslation()
        
        // 4. UI Interaction Logic Tests (Controller/State level)
        await testUIInteractionLogic()
        
        // Finalize
        saveReport()
        print("✅ Automation Test Suite Complete. Report saved to \(reportPath.path)")
    }
    
    func testModelLoading() async {
        reportContent += "## 1. Model Loading Test\n"
        let service = TranslationService()
        do {
            print("--- Loading Model: \(modelId) ---")
            try await service.loadModel(modelId: modelId)
            reportContent += "- ✅ Model loaded successfully: `\(modelId)`\n"
            
            print("--- Prewarming GPU ---")
            try await service.prewarm()
            reportContent += "- ✅ GPU Prewarm successful\n\n"
        } catch {
            reportContent += "- ❌ Model Loading Failed: \(error.localizedDescription)\n\n"
            print("Fatal Error: Model Loading Failed")
        }
    }
    
    func testPlainTextTranslation() async {
        reportContent += "## 2. Plain Text Translation\n"
        let service = TranslationService()
        // Ensure model is loaded (service is a new instance, usually we share it)
        try? await service.loadModel(modelId: modelId)
        
        // En -> Zh
        let enText = "The quick brown fox jumps over the lazy dog."
        do {
            print("--- Translating EN -> ZH ---")
            let zhResult = try await service.translate(text: enText, sourceLang: "English", targetLang: "Chinese (Simplified)")
            reportContent += "### EN -> ZH\n- Input: `\(enText)`\n- Output: `\(zhResult)`\n- Result: \(zhResult.isEmpty ? "❌ Empty" : "✅ Pass")\n\n"
        } catch {
            reportContent += "- ❌ EN -> ZH Failed: \(error.localizedDescription)\n\n"
        }
        
        // Zh -> En
        let zhText = "今天天气不错，我们去公园走走吧。"
        do {
            print("--- Translating ZH -> EN ---")
            let enResult = try await service.translate(text: zhText, sourceLang: "Chinese (Simplified)", targetLang: "English")
            reportContent += "### ZH -> EN\n- Input: `\(zhText)`\n- Output: `\(enResult)`\n- Result: \(enResult.isEmpty ? "❌ Empty" : "✅ Pass")\n\n"
        } catch {
            reportContent += "- ❌ ZH -> EN Failed: \(error.localizedDescription)\n\n"
        }
    }
    
    func testFileModeTranslation() async {
        reportContent += "## 3. File Mode (Batch) Translation\n"
        let controller = TranslationController()
        let service = TranslationService()
        try? await service.loadModel(modelId: modelId)
        
        controller.exportDirectory = exportDir
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: sourceDir, includingPropertiesForKeys: nil)
            print("--- Found \(files.count) files for batch testing ---")
            
            // Add files with auto-detection for source
            controller.addFiles(files, sourceLang: nil, targetLang: "English")
            
            // Customize target for Chinese doc (translate to English)
            if let idx = controller.tasks.firstIndex(where: { $0.fileName.contains("chinese") }) {
                controller.tasks[idx].targetLang = "English"
            }
            // Customize target for English sub (translate to Chinese)
            if let idx = controller.tasks.firstIndex(where: { $0.fileName.contains("english") }) {
                controller.tasks[idx].targetLang = "Chinese (Simplified)"
            }
            
            reportContent += "### Batch Queue Setup\n"
            for task in controller.tasks {
                reportContent += "- File: `\(task.fileName)`, Target: \(task.targetLang)\n"
            }
            
            print("--- Starting Batch Execution ---")
            await controller.runBatch(translationService: service, selectedModelId: modelId)
            
            reportContent += "\n### Results (Exported to \(exportDir.lastPathComponent))\n"
            for task in controller.tasks {
                switch task.status {
                case .completed(let url):
                    let content = (try? String(contentsOf: url)) ?? ""
                    reportContent += "- ✅ `\(task.fileName)` -> `\(url.lastPathComponent)` (\(content.count) chars)\n"
                case .failed(let error):
                    reportContent += "- ❌ `\(task.fileName)` Failed: \(error)\n"
                default:
                    reportContent += "- ⚠️ `\(task.fileName)` Status: \(task.status)\n"
                }
            }
            reportContent += "\n"
        } catch {
            reportContent += "- ❌ Batch File Listing Failed: \(error.localizedDescription)\n\n"
        }
    }
    
    func testUIInteractionLogic() async {
        reportContent += "## 4. UI Interaction & Logic\n"
        let controller = TranslationController()
        
        // Test Selection & Bulk Remove
        let dummyURLs = [
            URL(fileURLWithPath: "/tmp/test1.srt"),
            URL(fileURLWithPath: "/tmp/test2.srt"),
            URL(fileURLWithPath: "/tmp/test3.srt")
        ]
        controller.addFiles(dummyURLs, sourceLang: nil, targetLang: "English")
        let initialCount = controller.tasks.count
        
        let idsToRemove = Set([controller.tasks[0].id, controller.tasks[1].id])
        controller.removeTasks(ids: idsToRemove)
        
        let finalCount = controller.tasks.count
        reportContent += "### Bulk Removal\n- Initial: \(initialCount), Removed: 2, Final: \(finalCount)\n- Result: \(finalCount == initialCount - 2 ? "✅ Pass" : "❌ Fail")\n\n"
        
        // Test Bulk Language Update
        controller.addFiles([URL(fileURLWithPath: "/tmp/test4.srt")], sourceLang: nil, targetLang: "English")
        let newIds = Set(controller.tasks.map { $0.id })
        controller.updateTargetLanguageForTasks(ids: newIds, to: "Japanese")
        
        let allUpdated = controller.tasks.allSatisfy { $0.targetLang == "Japanese" }
        reportContent += "### Bulk Language Update\n- Updated to: Japanese\n- Result: \(allUpdated ? "✅ Pass" : "❌ Fail")\n\n"
    }
    
    func saveReport() {
        try? reportContent.write(to: reportPath, atomically: true, encoding: .utf8)
    }
}

Task { @MainActor in
    // Metal Shader Fix: Set library path if running from terminal
    // We try to locate the metallib in the build artifacts if possible, 
    // but MLX usually handles this if built correctly.
    // If it fails, we will see it in the output.
    
    let tester = AutomationTester()
    await tester.run()
    exit(0)
}

RunLoop.main.run()
