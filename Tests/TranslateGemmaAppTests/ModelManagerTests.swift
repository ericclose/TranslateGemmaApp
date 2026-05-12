import XCTest
@testable import TranslateGemmaKit

@MainActor
final class ModelManagerTests: XCTestCase {
    func testFetchModels() async {
        let manager = ModelManager()
        await manager.fetchCollectionModels()
        
        XCTAssertEqual(manager.models.count, 3)
        XCTAssertTrue(manager.models.contains(where: { $0.id == "mlx-community/translategemma-4b-it-4bit" }))
    }
    
    func testModelPathResolution() {
        let modelId = "mlx-community/translategemma-4b-it-4bit"
        let path = AppConfiguration.getLocalModelPath(modelId: modelId)
        
        XCTAssertTrue(path.path.contains("models--mlx-community--translategemma-4b-it-4bit"))
    }
    
    func testHubPathUpdate() {
        let manager = ModelManager()
        let originalPath = manager.currentHubPath
        
        let newURL = FileManager.default.temporaryDirectory.appendingPathComponent("custom_hub")
        manager.currentHubPath = newURL.path
        AppConfiguration.updateHubPath(newURL)
        
        XCTAssertEqual(AppConfiguration.currentHubPath.path, newURL.path)
        
        // Reset
        manager.resetToDefaultHubPath()
        XCTAssertEqual(manager.currentHubPath, AppConfiguration.currentHubPath.path)
    }
}
