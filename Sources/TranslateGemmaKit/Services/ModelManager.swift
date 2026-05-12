import Foundation
import HuggingFace
import Observation
import AppKit
import SwiftUI

@Observable
@MainActor
public class ModelManager {
    public var models: [ModelInfo] = []
    public var isDownloading = false
    public var isConnecting = false
    public var downloadingModelId: String? = nil
    public var currentHubPath: String = AppConfiguration.currentHubPath.path
    
    private let logger = AppLogger.service("ModelManager")
    private var hubClient: HubClient { AppConfiguration.hubClient }
    
    public init() {
        Task {
            await fetchCollectionModels()
        }
    }
    
    public func fetchCollectionModels() async {
        let modelSpecs = [
            ("mlx-community/translategemma-4b-it-4bit", "2.2 GB"),
            ("mlx-community/translategemma-12b-it-4bit", "6.7 GB"),
            ("mlx-community/translategemma-27b-it-4bit", "15.2 GB")
        ]
        
        // Fast UI refresh: clear existing status or show immediate check
        var fetched: [ModelInfo] = []
        for (id, size) in modelSpecs {
            let isDownloaded = checkIfDownloaded(modelId: id)
            fetched.append(ModelInfo(id: id, name: id.components(separatedBy: "/").last ?? id, size: size, isDownloaded: isDownloaded))
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            self.models = fetched
        }
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
            await MainActor.run { self.isConnecting = true }
            
            do {
                guard let repoId = Repo.ID(rawValue: modelId) else {
                    self.logger.error("Invalid Model ID: \(modelId)")
                    return
                }
                
                let downloader: (Repo.ID, @escaping @Sendable (Progress) -> Void) async throws -> URL = downloadSnapshotProvider ?? { [hubClient] repo, progress in
                    try await hubClient.downloadSnapshot(of: repo, progressHandler: progress)
                }
                
                // --- PROGRESS SELF-HEALING SNIFFER ---
                let sniffer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    AppConfiguration.downloadSession.getAllTasks { tasks in
                        for task in tasks {
                            let count = task.countOfBytesReceived
                            let total = task.countOfBytesExpectedToReceive
                            
                            if count > 0 && (total > 10_000_000 || total == -1) {
                                Task { @MainActor in
                                    if let index = self.models.firstIndex(where: { $0.id == modelId }) {
                                        if count > self.models[index].completedSize {
                                            self.models[index].completedSize = count
                                            if total > 0 { self.models[index].totalSize = total }
                                            self.models[index].downloadProgress = total > 0 ? Double(count) / Double(total) : self.models[index].downloadProgress
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                _ = try await downloader(repoId) { p in
                    if p.completedUnitCount > 0 {
                        Task { @MainActor in self.isConnecting = false }
                    }
                    
                    let fraction = p.fractionCompleted
                    let completed = p.completedUnitCount
                    let total = p.totalUnitCount
                    
                    Task { @MainActor in
                        if let index = self.models.firstIndex(where: { $0.id == modelId }) {
                            if completed > self.models[index].completedSize {
                                self.models[index].completedSize = completed
                                self.models[index].totalSize = total
                                self.models[index].downloadProgress = fraction
                            }
                        }
                    }
                }
                sniffer.invalidate()
                
                if !Task.isCancelled {
                    if let index = self.models.firstIndex(where: { $0.id == modelId }) {
                        self.models[index].isDownloaded = true
                        self.models[index].downloadProgress = 1.0
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.logger.error("Download failed for \(modelId): \(error)")
                }
            }
            
            await MainActor.run {
                self.isDownloading = false
                self.isConnecting = false
                self.downloadingModelId = nil
                self.downloadTask = nil
            }
        }
        
        await downloadTask?.value
    }
    
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        self.isDownloading = false
        self.downloadingModelId = nil
        
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
        }
    }
    
    public func deleteModel(modelId: String) {
        let hubPath = AppConfiguration.currentHubPath
        let modernId = AppConfiguration.getModernHubId(modelId: modelId)
        let modernRepoPath = hubPath.appendingPathComponent(modernId)
        let legacyPath = hubPath.appendingPathComponent("models").appendingPathComponent(modelId)
        let lockPath = hubPath.appendingPathComponent(".locks").appendingPathComponent(modernId)
        
        let pathsToDelete = [modernRepoPath, legacyPath, lockPath]
        
        for path in pathsToDelete {
            try? FileManager.default.removeItem(at: path)
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
        if panel.runModal() == .OK, let url = panel.url {
            AppConfiguration.updateHubPath(url)
            self.currentHubPath = url.path
            Task { await fetchCollectionModels() }
        }
    }
    
    public func resetToDefaultHubPath() {
        AppConfiguration.resetHubPath()
        self.currentHubPath = AppConfiguration.currentHubPath.path
        Task { await fetchCollectionModels() }
    }
}
