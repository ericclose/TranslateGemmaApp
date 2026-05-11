import Foundation
import TranslateGemmaLibrary
import HuggingFace
import Combine

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
        let startTime = Date()
        var cancellables = Set<AnyCancellable>()
        
        await MainActor.run {
            manager.$models
                .receive(on: RunLoop.main)
                .sink { models in
                    guard let model = models.first(where: { $0.id == modelId }) else { return }
                    // 脚本层只管显示
                    if model.completedSize > 0 {
                        print(String(format: "[%.1fs] %.2f%% (%lld bytes)", 
                                     Date().timeIntervalSince(startTime), 
                                     model.downloadProgress * 100,
                                     model.completedSize))
                    }
                }
                .store(in: &cancellables)
        }
        
        await manager.downloadModel(modelId: modelId)
        print("✅ Finished.")
    }
}
