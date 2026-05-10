import SwiftUI

struct TranslateGemmaApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
    }
}

TranslateGemmaApp.main()
