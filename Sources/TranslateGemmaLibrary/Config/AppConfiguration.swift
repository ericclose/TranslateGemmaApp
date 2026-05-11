import Foundation
import Hub
import os

/// Centralized Resource Manager: Coordinates model paths, Metallib location, and logging configuration.
public enum AppConfiguration {
    
    /// Unified subsystem name for logging
    public static let subsystem = "com.innovation.TranslateGemmaApp"
    
    private static let hubPathKey = "com.innovation.TranslateGemmaApp.customHubPath"
    
    /// Gets the currently active Hub root path.
    public static var currentHubPath: URL {
        if let savedPath = UserDefaults.standard.string(forKey: hubPathKey) {
            return URL(fileURLWithPath: savedPath)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".cache/huggingface/hub")
    }
    
    /// Unified HubApi instance ensuring global cache path consistency.
    /// Supports dynamic path switching (e.g., moving to an external drive).
    public static private(set) var hub: HubApi = createHubApi()
    
    private static func createHubApi() -> HubApi {
        let path = currentHubPath
        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return HubApi(downloadBase: path)
    }
    
    /// Updates the unified Hub path and reinitializes HubApi.
    public static func updateHubPath(_ newPath: URL) {
        UserDefaults.standard.set(newPath.path, forKey: hubPathKey)
        hub = HubApi(downloadBase: newPath)
    }
    
    /// Resets to the default path (~/.cache/huggingface/hub).
    public static func resetHubPath() {
        UserDefaults.standard.removeObject(forKey: hubPathKey)
        hub = createHubApi()
    }
    
    /// Gets the recommended path for MLX Metal shader libraries.
    /// Follows MLX core search conventions.
    public static func getMetallibURL() -> URL? {
        // 1. Prefer mlx-swift_Cmlx.bundle (SPM standard path)
        if let bundleURL = Bundle.main.url(forResource: "mlx-swift_Cmlx", withExtension: "bundle"),
           let bundle = Bundle(url: bundleURL),
           let url = bundle.url(forResource: "default", withExtension: "metallib") {
            return url
        }
        
        // 2. Look in the Resources root directory
        if let url = Bundle.main.url(forResource: "default", withExtension: "metallib") {
            return url
        }
        
        // 3. Iterate through all loaded bundles as a fallback
        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: "default", withExtension: "metallib") {
                return url
            }
        }
        
        return nil
    }
    
    /// Thoroughly checks if a model is fully downloaded, supporting both legacy and modern layouts.
    public static func isModelFullyDownloaded(modelId: String) -> Bool {
        let path = getLocalModelPath(modelId: modelId)
        
        let essentialFiles = [
            "config.json",
            "tokenizer.json"
        ]
        
        // 1. Check basic configuration files
        for file in essentialFiles {
            let fileURL = path.appendingPathComponent(file)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                return false
            }
        }
        
        // 2. Check weight files (safetensors or index)
        let safetensors = path.appendingPathComponent("model.safetensors")
        let index = path.appendingPathComponent("model.safetensors.index.json")
        
        return FileManager.default.fileExists(atPath: safetensors.path) || 
               FileManager.default.fileExists(atPath: index.path)
    }
    
    /// Gets the actual local path of a model, checking both legacy and modern layouts.
    /// In modern layout, it resolves to the latest snapshot directory.
    public static func getLocalModelPath(modelId: String) -> URL {
        let hubPath = currentHubPath
        
        // 1. Check for Modern layout: models--author--repo
        let modernId = "models--" + modelId.replacingOccurrences(of: "/", with: "--")
        let modernRepoPath = hubPath.appendingPathComponent(modernId)
        let snapshotsPath = modernRepoPath.appendingPathComponent("snapshots")
        
        if FileManager.default.fileExists(atPath: snapshotsPath.path),
           let snapshots = try? FileManager.default.contentsOfDirectory(atPath: snapshotsPath.path),
           let latestSnapshot = snapshots.sorted().last {
            return snapshotsPath.appendingPathComponent(latestSnapshot)
        }
        
        // 2. Check for Legacy layout: models/author/repo
        let legacyPath = hubPath.appendingPathComponent("models").appendingPathComponent(modelId)
        if FileManager.default.fileExists(atPath: legacyPath.path) {
            return legacyPath
        }
        
        // Fallback to library default
        return hub.localRepoLocation(Hub.Repo(id: modelId))
    }
}

/// Standardized logger factory.
public enum AppLogger {
    public static func service(_ category: String) -> Logger {
        Logger(subsystem: AppConfiguration.subsystem, category: category)
    }
}
