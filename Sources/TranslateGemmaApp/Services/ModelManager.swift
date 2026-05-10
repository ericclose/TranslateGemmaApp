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
    private let modelsDir: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDir = appSupport.appendingPathComponent("TranslateGemmaApp/Models")
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        
        loadLocalModels()
    }
    
    func fetchCollectionModels() async {
        let modelIds = [
            "mlx-community/translategemma-4b-it-4bit",
            "mlx-community/translategemma-12b-it-4bit",
            "mlx-community/translategemma-27b-it-4bit"
        ]
        
        var fetched: [ModelInfo] = []
        for id in modelIds {
            let isDownloaded = checkIfDownloaded(modelId: id)
            fetched.append(ModelInfo(id: id, name: id.components(separatedBy: "/").last ?? id, size: "Varies", isDownloaded: isDownloaded))
        }
        
        self.models = fetched
    }
    
    func checkIfDownloaded(modelId: String) -> Bool {
        let path = modelsDir.appendingPathComponent(modelId)
        return FileManager.default.fileExists(atPath: path.path)
    }
    
    func downloadModel(modelId: String) async {
        self.isDownloading = true
        
        // Simulate progress
        for i in 1...10 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if let index = self.models.firstIndex(where: { $0.id == modelId }) {
                self.models[index].downloadProgress = Double(i) / 10.0
            }
        }
        
        if let index = self.models.firstIndex(where: { $0.id == modelId }) {
            self.models[index].isDownloaded = true
            self.models[index].downloadProgress = 1.0
        }
        self.isDownloading = false
    }
    
    func revealInFinder(modelId: String) {
        let path = modelsDir.appendingPathComponent(modelId)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path.path)
    }
    
    private func loadLocalModels() {
        // Scan modelsDir for existing models
    }
}
