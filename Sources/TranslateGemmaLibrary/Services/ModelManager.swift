import Foundation
import HuggingFace
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
    @Published public var downloadingModelId: String? = nil
    @Published public var currentHubPath: String = AppConfiguration.currentHubPath.path
    
    private let logger = AppLogger.service("ModelManager")
    private var hubClient: HubClient { AppConfiguration.hubClient }
    
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
        return AppConfiguration.getLocalModelPath(modelId: modelId)
    }
    
    public func checkIfDownloaded(modelId: String) -> Bool {
        return AppConfiguration.isModelFullyDownloaded(modelId: modelId)
    }
    
    private var downloadTask: Task<Void, Never>?
    
    // For testing purposes
    internal var downloadSnapshotProvider: ((Repo.ID, @escaping @Sendable (Progress) -> Void) async throws -> URL)? = nil
    
    public func downloadModel(modelId: String) async {
        self.isDownloading = true
        self.downloadingModelId = modelId
        
        downloadTask = Task {
            do {
                let repoId = Repo.ID(rawValue: modelId)!
                
                let downloader: (Repo.ID, @escaping @Sendable (Progress) -> Void) async throws -> URL = downloadSnapshotProvider ?? { [hubClient] repo, progress in
                    try await hubClient.downloadSnapshot(of: repo, progressHandler: progress)
                }
                
                _ = try await downloader(repoId) { p in
                    Task { @MainActor in
                        if let index = self.models.firstIndex(where: { $0.id == modelId }) {
                            self.models[index].downloadProgress = p.fractionCompleted
                        }
                    }
                }
                
                if !Task.isCancelled {
                    if let index = self.models.firstIndex(where: { $0.id == modelId }) {
                        self.models[index].isDownloaded = true
                        self.models[index].downloadProgress = 1.0
                    }
                }
            } catch {
                if !Task.isCancelled {
                    logger.error("Download failed for \(modelId): \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                self.isDownloading = false
                self.downloadingModelId = nil
                self.downloadTask = nil
            }
        }
    }
    
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        self.isDownloading = false
        self.downloadingModelId = nil
        
        // Reset progress for any model that was downloading
        for i in 0..<models.count {
            if !models[i].isDownloaded {
                models[i].downloadProgress = 0
            }
        }
    }
    
    public func revealInFinder(modelId: String) {
        let path = AppConfiguration.getLocalModelPath(modelId: modelId)
        
        if FileManager.default.fileExists(atPath: path.path) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path.path)
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            NSWorkspace.shared.open(appSupport)
        }
    }
    
    public func deleteModel(modelId: String) {
        let hubPath = AppConfiguration.currentHubPath
        
        // Use unified modern ID helper from AppConfiguration
        let modernId = AppConfiguration.getModernHubId(modelId: modelId)
        let modernRepoPath = hubPath.appendingPathComponent(modernId)
        let legacyPath = hubPath.appendingPathComponent("models").appendingPathComponent(modelId)
        let lockPath = hubPath.appendingPathComponent(".locks").appendingPathComponent(modernId)
        
        let pathsToDelete = [modernRepoPath, legacyPath, lockPath]
        
        for path in pathsToDelete {
            do {
                if FileManager.default.fileExists(atPath: path.path) {
                    try FileManager.default.removeItem(at: path)
                    logger.info("Deleted model resource at: \(path.path)")
                }
            } catch {
                logger.error("Failed to delete model resource at \(path.path): \(error.localizedDescription)")
            }
        }
        
        if let index = self.models.firstIndex(where: { $0.id == modelId }) {
            self.models[index].isDownloaded = false
            self.models[index].downloadProgress = 0
        }
    }
    
    public func selectCustomHubPath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Please select the Hugging Face Hub storage directory"
        panel.prompt = "Select Directory"
        
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
