import Foundation
import Hub
import Combine
import AppKit

struct ModelInfo: Identifiable {
    let id: String
    let name: String
    let size: String
    var isDownloaded: Bool = false
    var downloadProgress: Double = 0
}

@MainActor
class ModelManager: ObservableObject {
    @Published var models: [ModelInfo] = []
    @Published var isDownloading = false
    
    private let hub = HubApi()
    
    init() {
        loadLocalModels()
    }
    
    func fetchCollectionModels() async {
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
    
    func checkIfDownloaded(modelId: String) -> Bool {
        let repo = Hub.Repo(id: modelId)
        let path = hub.localRepoLocation(repo)
        // Check if a major file exists, e.g. config.json
        let configPath = path.appendingPathComponent("config.json")
        return FileManager.default.fileExists(atPath: configPath.path)
    }
    
    func downloadModel(modelId: String) async {
        self.isDownloading = true
        
        do {
            let repo = Hub.Repo(id: modelId)
            
            // Perform real download using HubApi.snapshot
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
    
    func revealInFinder(modelId: String) {
        let repo = Hub.Repo(id: modelId)
        let path = hub.localRepoLocation(repo)
        
        if FileManager.default.fileExists(atPath: path.path) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path.path)
        } else {
            // If not found, open the Application Support directory
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            NSWorkspace.shared.open(appSupport)
        }
    }
    
    private func loadLocalModels() {
        Task {
            await fetchCollectionModels()
        }
    }
}
