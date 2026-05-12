import Foundation
import TranslateGemmaKit
import HuggingFace

@main
struct LiveDownloadTest {
    static func main() async {
        let modelId = "mlx-community/translategemma-4b-it-4bit"
        print("🚀 Starting DIAGNOSTIC Download Test for \(modelId)")
        
        let manager = ModelManager()
        
        print("🗑️ Cleaning up for fresh start...")
        let repoDirName = "models--" + modelId.replacingOccurrences(of: "/", with: "--")
        let repoPath = AppConfiguration.currentHubPath.appendingPathComponent(repoDirName)
        try? FileManager.default.removeItem(at: repoPath)
        
        await manager.fetchCollectionModels()
        
        print("⏳ Preparing download...")
        
        // In a script, we can't easily observe changes with @Observable without a run loop
        // So we'll just check periodically or just run the download.
        
        await manager.downloadModel(modelId: modelId)
        print("✅ Finished.")
    }
}
