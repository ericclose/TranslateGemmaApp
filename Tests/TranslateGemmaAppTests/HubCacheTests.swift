import XCTest
import Foundation
import HuggingFace
@testable import TranslateGemmaLibrary

final class HubCacheTests: XCTestCase {
    
    func testModernHubIdGeneration() {
        let modelId = "mlx-community/translategemma-4b-it-4bit"
        let expected = "models--mlx-community--translategemma-4b-it-4bit"
        let actual = AppConfiguration.getModernHubId(modelId: modelId)
        XCTAssertEqual(actual, expected, "Modern Hub ID generation failed")
    }
    
    func testHubClientInitialization() {
        let customPath = FileManager.default.temporaryDirectory.appendingPathComponent("test-hub")
        AppConfiguration.updateHubPath(customPath)
        
        XCTAssertEqual(AppConfiguration.currentHubPath.path, customPath.path, "Hub path update failed")
        XCTAssertNotNil(AppConfiguration.hubClient.cache, "HubClient should have a cache configured")
        
        // Reset to default
        AppConfiguration.resetHubPath()
    }
    
    func testModelPathResolutionModern() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let modelId = "test/model"
        let modernId = AppConfiguration.getModernHubId(modelId: modelId)
        let snapshotsPath = tempDir.appendingPathComponent(modernId).appendingPathComponent("snapshots")
        let snapshotId = "abcdef123456"
        let snapshotDir = snapshotsPath.appendingPathComponent(snapshotId)
        
        try FileManager.default.createDirectory(at: snapshotDir, withIntermediateDirectories: true)
        try "test".write(to: snapshotDir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        
        // Temporarily override hub path
        AppConfiguration.updateHubPath(tempDir)
        defer { AppConfiguration.resetHubPath() }
        
        let resolvedPath = AppConfiguration.getLocalModelPath(modelId: modelId)
        XCTAssertTrue(resolvedPath.path.contains(snapshotId), "Resolved path should contain the snapshot ID")
        XCTAssertTrue(resolvedPath.path.contains(modernId), "Resolved path should contain the modern ID")
    }
    
    func testModelDownloadStatus() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let modelId = "org/model"
        let modernId = AppConfiguration.getModernHubId(modelId: modelId)
        let snapshotDir = tempDir.appendingPathComponent(modernId).appendingPathComponent("snapshots/main")
        try FileManager.default.createDirectory(at: snapshotDir, withIntermediateDirectories: true)
        
        // Mock essential files
        try "{}".write(to: snapshotDir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        try "{}".write(to: snapshotDir.appendingPathComponent("tokenizer.json"), atomically: true, encoding: .utf8)
        try "data".write(to: snapshotDir.appendingPathComponent("model.safetensors"), atomically: true, encoding: .utf8)
        
        AppConfiguration.updateHubPath(tempDir)
        defer { AppConfiguration.resetHubPath() }
        
        XCTAssertTrue(AppConfiguration.isModelFullyDownloaded(modelId: modelId), "Model should be detected as fully downloaded")
    }
}
