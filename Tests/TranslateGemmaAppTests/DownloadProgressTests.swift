import XCTest
import HuggingFace
@testable import TranslateGemmaLibrary

final class DownloadProgressTests: XCTestCase {
    
    @MainActor
    func testDownloadProgressUpdates() async throws {
        let manager = ModelManager()
        
        // 1. Initial state check
        await manager.fetchCollectionModels()
        let modelId = "mlx-community/translategemma-4b-it-4bit"
        
        guard let index = manager.models.firstIndex(where: { $0.id == modelId }) else {
            XCTFail("Model not found in collection")
            return
        }
        
        // Reset state for test
        manager.models[index].isDownloaded = false
        manager.models[index].downloadProgress = 0
        
        // 2. Setup mock downloader
        let progressSteps: [Double] = [0.1, 0.3, 0.5, 0.8, 1.0]
        
        manager.downloadSnapshotProvider = { repoId, progressHandler in
            for step in progressSteps {
                let p = Progress(totalUnitCount: 100)
                p.completedUnitCount = Int64(step * 100)
                
                // Simulate the progress callback (which usually happens on background thread)
                progressHandler(p)
                
                // Simulate network delay
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            return URL(fileURLWithPath: "/tmp/fake-model-path")
        }
        
        // 3. Start download and monitor
        await manager.downloadModel(modelId: modelId)
        
        XCTAssertTrue(manager.isDownloading, "Manager should report downloading")
        XCTAssertEqual(manager.downloadingModelId, modelId, "Should track downloading model ID")
        
        var observedProgress: [Double] = []
        var iterations = 0
        
        // Monitor the progress updates for up to 2 seconds
        while manager.isDownloading && iterations < 100 {
            if let model = manager.models.first(where: { $0.id == modelId }) {
                let current = model.downloadProgress
                if observedProgress.last != current && current > 0 {
                    observedProgress.append(current)
                    print("Observed progress: \(Int(current * 100))%")
                }
            }
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
            iterations += 1
        }
        
        // 4. Verify results
        XCTAssertFalse(manager.isDownloading, "Download should have finished")
        XCTAssertNil(manager.downloadingModelId, "Downloading ID should be reset")
        
        print("Final observed progress sequence: \(observedProgress)")
        
        XCTAssertTrue(observedProgress.count >= 3, "Progress should update incrementally, not jump to end")
        XCTAssertTrue(observedProgress.contains(0.5), "Progress should have hit 50% mark")
        
        if let finalModel = manager.models.first(where: { $0.id == modelId }) {
            XCTAssertEqual(finalModel.downloadProgress, 1.0, "Final progress should be 100%")
            XCTAssertTrue(finalModel.isDownloaded, "Model should be marked as downloaded")
        }
    }
}
