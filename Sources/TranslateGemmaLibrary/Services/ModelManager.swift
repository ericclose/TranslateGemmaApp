import Foundation
import Hub
import Combine
import AppKit

public struct ModelInfo: Identifiable {
    public let id: String
    public let name: String
    public let size: String
    public var isDownloaded: Bool = false
    public var downloadProgress: Double = 0
}

@MainActor
public class ModelManager: ObservableObject {
    @Published public var models: [ModelInfo] = []
    @Published public var isDownloading = false
    
    private let hub = HubApi()
    
    public init() {
        Task {
            await fetchCollectionModels()
        }
    }
    
    public func fetchCollectionModels() async {
        let modelSpecs = [
            ("mlx-community/translategemma-4b-it-4bit", "2.6 GB"),
            ("mlx-community/translategemma-12b-it-4bit", "7.5 GB"),
            ("mlx-community/translategemma-27b-it-4bit", "16.2 GB")
        ]
        
        var fetched: [ModelInfo] = []
        for (id, size) in modelSpecs {
            let isDownloaded = checkIfDownloaded(modelId: id)
            fetched.append(ModelInfo(id: id, name: id.components(separatedBy: "/").last ?? id, size: size, isDownloaded: isDownloaded))
        }
        
        self.models = fetched
    }
    
    public func getModelDirectory(modelId: String) -> URL {
        let repo = Hub.Repo(id: modelId)
        return hub.localRepoLocation(repo)
    }
    
    public func checkIfDownloaded(modelId: String) -> Bool {
        let repo = Hub.Repo(id: modelId)
        let path = hub.localRepoLocation(repo)
        
        // Check for config.json
        let configPath = path.appendingPathComponent("config.json")
        guard FileManager.default.fileExists(atPath: configPath.path) else { return false }
        
        // Check for model weights (safetensors or index)
        // We look for either model.safetensors or model.safetensors.index.json 
        // as a proxy for the weights being present.
        let safetensorsPath = path.appendingPathComponent("model.safetensors")
        let indexLoaderPath = path.appendingPathComponent("model.safetensors.index.json")
        
        // For a more robust check, we could verify all shards, but this is a good start
        return FileManager.default.fileExists(atPath: safetensorsPath.path) || 
               FileManager.default.fileExists(atPath: indexLoaderPath.path)
    }
    
    public func downloadModel(modelId: String) async {
        self.isDownloading = true
        
        do {
            let repo = Hub.Repo(id: modelId)
            
            _ = try await hub.snapshot(
                from: repo,
                progressHandler: { progress in
                    DispatchQueue.main.async {
                        if let index = self.models.firstIndex(where: { $0.id == modelId }) {
                            self.models[index].downloadProgress = progress.fractionCompleted
                        }
                    }
                }
            )
            
            if let index = self.models.firstIndex(where: { $0.id == modelId }) {
                self.models[index].isDownloaded = true
                self.models[index].downloadProgress = 1.0
            }
        } catch {
            print("Download failed: \(error)")
        }
        
        self.isDownloading = false
    }
    
    public func revealInFinder(modelId: String) {
        let repo = Hub.Repo(id: modelId)
        let path = hub.localRepoLocation(repo)
        
        if FileManager.default.fileExists(atPath: path.path) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path.path)
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            NSWorkspace.shared.open(appSupport)
        }
    }
    
    public func importLocalModel(modelId: String) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "请选择包含模型文件（config.json等）的文件夹"
        
        if panel.runModal() == .OK, let url = panel.url {
            // Verify if it looks like a model directory
            let configPath = url.appendingPathComponent("config.json")
            if FileManager.default.fileExists(atPath: configPath.path) {
                // Here we would ideally save a security-scoped bookmark, 
                // but for now, let's just symlink it or copy it into the sandbox
                // if the user wants to avoid re-downloading.
                
                let repo = Hub.Repo(id: modelId)
                let destination = hub.localRepoLocation(repo)
                
                try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                
                // Try to create a symbolic link (may fail depending on sandbox, 
                // but usually works if user selected the source)
                do {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: url)
                    
                    if let index = self.models.firstIndex(where: { $0.id == modelId }) {
                        self.models[index].isDownloaded = true
                    }
                } catch {
                    print("Failed to link local model: \(error)")
                }
            }
        }
    }
}
