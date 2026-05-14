import SwiftUI
import TranslateGemmaKit

@main
struct TranslateGemmaApp: App {
    @State private var modelManager = ModelManager()
    @State private var translationService = TranslationService()
    @State private var systemMonitor = SystemMonitor()
    
    var body: some Scene {
        WindowGroup {
            TranslationView()
                .environment(modelManager)
                .environment(translationService)
                .environment(systemMonitor)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
