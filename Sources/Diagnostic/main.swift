import Foundation
import TranslateGemmaLibrary
import HuggingFace

@main
struct Diagnostic {
    static func main() async {
        print("--- TranslateGemma Path Debug ---")
        let modelId = "mlx-community/translategemma-4b-it-4bit"
        
        let manager = await ModelManager()
        let hubPath = URL(fileURLWithPath: manager.currentHubPath)
        
        // 1. Legacy path
        let legacyPath = hubPath.appendingPathComponent("models").appendingPathComponent(modelId)
        print("Legacy Path: \(legacyPath.path)")
        print("Exists: \(FileManager.default.fileExists(atPath: legacyPath.path))")
        
        // 2. Modern path
        let modernId = "models--" + modelId.replacingOccurrences(of: "/", with: "--")
        let modernPath = hubPath.appendingPathComponent(modernId)
        print("Modern Path: \(modernPath.path)")
        print("Exists: \(FileManager.default.fileExists(atPath: modernPath.path))")
        
        print("--- End Path Debug ---")
    }
}
