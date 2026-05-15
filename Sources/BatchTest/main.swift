import Foundation
import TranslateGemmaKit

@MainActor
func run() async {
    let testDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads/test")
    
    print("Testing translation for all .srt files in \\(testDir.path)...")
    
    if !FileManager.default.fileExists(atPath: testDir.path) {
        print("Directory does not exist. Creating and generating dummy srt...")
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        let dummySRT1 = """
        1
        00:00:01,000 --> 00:00:02,000
        This is a test subtitle.
        
        2
        00:00:03,000 --> 00:00:05,000
        We are verifying batch processing.
        """
        
        let dummySRT2 = """
        1
        00:00:01,000 --> 00:00:02,000
        Second file is loaded correctly.
        """
        
        try? dummySRT1.write(to: testDir.appendingPathComponent("file1.srt"), atomically: true, encoding: .utf8)
        try? dummySRT2.write(to: testDir.appendingPathComponent("file2.srt"), atomically: true, encoding: .utf8)
    }
    
    do {
        let files = try FileManager.default.contentsOfDirectory(at: testDir, includingPropertiesForKeys: nil)
        let srtFiles = files.filter { $0.pathExtension.lowercased() == "srt" }
        
        guard !srtFiles.isEmpty else {
            print("No .srt files found in \\(testDir.path)")
            return
        }
        
        let controller = TranslationController()
        let service = TranslationService()
        
        controller.addFiles(srtFiles, defaultTargetLang: "Chinese (Simplified)")
        
        print("Starting batch translation for \\(srtFiles.count) files using default 4B model...")
        
        let modelId = "mlx-community/translategemma-4b-it-4bit"
        await controller.runBatch(translationService: service, selectedModelId: modelId)
        
        print("Batch processing complete.")
        
        // Verify results
        for task in controller.tasks {
            if case .completed(let outputURL) = task.status {
                print("Task \(task.fileName) completed successfully -> \(outputURL.lastPathComponent)")
                
                if let content = try? String(contentsOf: outputURL) {
                    if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        print("❌ ERROR: Output file \(outputURL.lastPathComponent) is EMPTY!")
                    } else {
                        print("✅ Output file \(outputURL.lastPathComponent) contains \(content.count) characters.")
                    }
                } else {
                    print("❌ ERROR: Could not read output file \(outputURL.lastPathComponent)")
                }
            } else {
                print("❌ ERROR: Task \(task.fileName) did not complete: \(task.status)")
            }
        }
    } catch {
        print("Failed to run test: \\(error)")
    }
}

Task {
    await run()
    exit(0)
}

RunLoop.main.run()
