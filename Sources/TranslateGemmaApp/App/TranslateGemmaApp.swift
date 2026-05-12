import SwiftUI
import TranslateGemmaKit

@main
struct TranslateGemmaApp: App {
    @State private var modelManager = ModelManager()
    @State private var translationService = TranslationService()
    
    var body: some Scene {
        WindowGroup {
            TranslationView()
                .environment(modelManager)
                .environment(translationService)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
    }
}
