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
    @Published public var currentHubPath: String = AppConfiguration.currentHubPath.path
    
    private var hub: HubApi { AppConfiguration.hub }
    
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
        return AppConfiguration.isModelFullyDownloaded(modelId: modelId)
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
    
    public func selectCustomHubPath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "请选择 Hugging Face Hub 的统一存储目录（例如 ~/.cache/huggingface/hub 或外置盘路径）"
        panel.prompt = "选择目录"
        
        if panel.runModal() == .OK, let url = panel.url {
            AppConfiguration.updateHubPath(url)
            self.currentHubPath = url.path
            Task {
                await fetchCollectionModels()
            }
        }
    }
    
    public func resetToDefaultHubPath() {
        AppConfiguration.resetHubPath()
        self.currentHubPath = AppConfiguration.currentHubPath.path
        Task {
            await fetchCollectionModels()
        }
    }
    
}
