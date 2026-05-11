import Foundation
import Hub
import os

/// 中央化资源管理器：统筹模型路径、Metallib 定位以及日志配置
public enum AppConfiguration {
    
    /// 统一的子系统名称
    public static let subsystem = "com.innovation.TranslateGemmaApp"
    
    private static let hubPathKey = "com.innovation.TranslateGemmaApp.customHubPath"
    
    /// 获取当前生效的 Hub 根路径
    public static var currentHubPath: URL {
        if let savedPath = UserDefaults.standard.string(forKey: hubPathKey) {
            return URL(fileURLWithPath: savedPath)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".cache/huggingface/hub")
    }
    
    /// 统一的 HubApi 实例，确保缓存路径全局一致
    /// 支持动态切换路径（如移动到外置硬盘）
    public static private(set) var hub: HubApi = createHubApi()
    
    private static func createHubApi() -> HubApi {
        let path = currentHubPath
        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return HubApi(downloadBase: path)
    }
    
    /// 更新统一的 Hub 路径并重新初始化 HubApi
    public static func updateHubPath(_ newPath: URL) {
        UserDefaults.standard.set(newPath.path, forKey: hubPathKey)
        hub = HubApi(downloadBase: newPath)
    }
    
    /// 重置为默认路径 (~/.cache/huggingface/hub)
    public static func resetHubPath() {
        UserDefaults.standard.removeObject(forKey: hubPathKey)
        hub = createHubApi()
    }
    
    /// 获取 MLX Metal 着色器库的推荐路径
    /// 遵循 MLX 核心的搜索约定
    public static func getMetallibURL() -> URL? {
        // 1. 优先查找 mlx-swift_Cmlx.bundle (SPM 标准路径)
        if let bundleURL = Bundle.main.url(forResource: "mlx-swift_Cmlx", withExtension: "bundle"),
           let bundle = Bundle(url: bundleURL),
           let url = bundle.url(forResource: "default", withExtension: "metallib") {
            return url
        }
        
        // 2. 查找 Resources 根目录
        if let url = Bundle.main.url(forResource: "default", withExtension: "metallib") {
            return url
        }
        
        // 3. 遍历所有已加载的 Bundle (备选方案)
        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: "default", withExtension: "metallib") {
                return url
            }
        }
        
        return nil
    }
    
    /// 彻底检查模型是否完整下载
    public static func isModelFullyDownloaded(modelId: String) -> Bool {
        let repo = Hub.Repo(id: modelId)
        let path = hub.localRepoLocation(repo)
        
        let essentialFiles = [
            "config.json",
            "tokenizer.json"
        ]
        
        // 1. 检查基础配置文件
        for file in essentialFiles {
            let fileURL = path.appendingPathComponent(file)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                return false
            }
        }
        
        // 2. 检查权重文件 (safetensors 或 index)
        let safetensors = path.appendingPathComponent("model.safetensors")
        let index = path.appendingPathComponent("model.safetensors.index.json")
        
        return FileManager.default.fileExists(atPath: safetensors.path) || 
               FileManager.default.fileExists(atPath: index.path)
    }
}

/// 标准化日志器工厂
public enum AppLogger {
    public static func service(_ category: String) -> Logger {
        Logger(subsystem: AppConfiguration.subsystem, category: category)
    }
}
