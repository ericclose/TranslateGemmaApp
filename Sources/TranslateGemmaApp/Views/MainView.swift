import SwiftUI
import UniformTypeIdentifiers
import TranslateGemmaLibrary

struct MainView: View {
    @StateObject var modelManager = ModelManager()
    @StateObject var translationService = TranslationService()
    let translationController = TranslationController()
    
    @AppStorage("selectedModelId") private var selectedModelId: String = ""
    
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var targetLanguage: String = "Chinese"
    @State private var showModelDashboard = false
    @State private var importedFileURL: URL? = nil
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert = false
    
    let languages = ["Chinese", "English", "Japanese", "Korean", "French", "German", "Spanish"]
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack(spacing: 15) {
                    Text("TranslateGemma")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                    
                    Spacer()
                    
                    // Model Selector
                    let downloadedModels = modelManager.models.filter { $0.isDownloaded }
                    if !downloadedModels.isEmpty {
                        Picker("", selection: $selectedModelId) {
                            ForEach(downloadedModels) { model in
                                Text(model.name).tag(model.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }
                    
                    Button(action: { showModelDashboard = true }) {
                        Image(systemName: "cpu")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .help("Model Dashboard")
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Main Interface
                HStack(spacing: 15) {
                    // Input Area
                    VStack(alignment: .leading) {
                        HStack {
                            Text(importedFileURL != nil ? "Source (\(importedFileURL!.lastPathComponent))" : "Source (Auto)")
                                .font(.caption).bold()
                                .foregroundColor(.secondary)
                            Spacer()
                            if importedFileURL != nil {
                                Button("Clear") {
                                    importedFileURL = nil
                                    inputText = ""
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.red)
                                .font(.caption)
                            }
                            Button("Import File") {
                                importFile()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        TextEditor(text: $inputText)
                            .padding(10)
                            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    }
                    
                    VStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.blue)
                        
                        Picker("", selection: $targetLanguage) {
                            ForEach(languages, id: \.self) { lang in
                                Text(lang).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    
                    // Output Area
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Target (\(targetLanguage))")
                                .font(.caption).bold()
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Export") {
                                exportFile()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(outputText.isEmpty)
                        }
                        
                        TextEditor(text: .constant(outputText))
                            .padding(10)
                            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    }
                }
                .padding(.horizontal)
                
                // Bottom Action
                Button(action: translateAction) {
                    HStack {
                        if translationService.isTranslating {
                            ProgressView().controlSize(.small)
                                .padding(.trailing, 5)
                        }
                        Text(translationService.isTranslating ? "Translating..." : "Translate")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .shadow(radius: 5)
                }
                .padding(.horizontal)
                .padding(.bottom)
                .disabled(translationService.isTranslating || inputText.isEmpty)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .sheet(isPresented: $showModelDashboard) {
            ModelDashboardView(modelManager: modelManager)
        }
        .alert("Error", isPresented: $showErrorAlert, presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { message in
            Text(message)
        }
        .onAppear {
            Task {
                await modelManager.fetchCollectionModels()
                let downloaded = modelManager.models.filter { $0.isDownloaded }
                
                if downloaded.isEmpty {
                    showModelDashboard = true
                } else if selectedModelId.isEmpty || !downloaded.contains(where: { $0.id == selectedModelId }) {
                    selectedModelId = downloaded.first?.id ?? ""
                }
            }
        }
    }
    
    func translateAction() {
        Task {
            let downloaded = modelManager.models.filter { $0.isDownloaded }
            
            let modelIdToUse: String
            if !selectedModelId.isEmpty && downloaded.contains(where: { $0.id == selectedModelId }) {
                modelIdToUse = selectedModelId
            } else if let first = downloaded.first {
                modelIdToUse = first.id
                selectedModelId = first.id
            } else {
                showModelDashboard = true
                return
            }
            
            do {
                try await translationService.loadModel(modelId: modelIdToUse)
                
                if let fileURL = importedFileURL {
                    // Use TranslationController for file-based processing
                    outputText = try await translationController.processFile(url: fileURL, targetLang: targetLanguage) { text in
                        try await translationService.translate(text: text, sourceLang: nil, targetLang: targetLanguage)
                    }
                } else {
                    // Just translate the editor text
                    outputText = try await translationService.translate(text: inputText, sourceLang: nil, targetLang: targetLanguage)
                }
            } catch {
                print("Translation error: \(error)")
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
    
    func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.text, .plainText, UTType(filenameExtension: "srt")!, UTType(filenameExtension: "vtt")!, UTType(filenameExtension: "ass")!, UTType("public.markdown") ?? .plainText]
        if panel.runModal() == .OK {
            if let url = panel.url {
                importedFileURL = url
                inputText = (try? String(contentsOf: url)) ?? ""
            }
        }
    }
    
    func exportFile() {
        let panel = NSSavePanel()
        // Suggest filename based on import or extension
        if let originalURL = importedFileURL {
            panel.nameFieldStringValue = "translated_" + originalURL.lastPathComponent
        } else {
            panel.nameFieldStringValue = "translated.txt"
        }
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                try? outputText.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

struct ModelDashboardView: View {
    @ObservedObject var modelManager: ModelManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Model Dashboard")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(VisualEffectView(material: .titlebar, blendingMode: .withinWindow))
            
            Divider()
            
            List(modelManager.models) { model in
                HStack {
                    VStack(alignment: .leading) {
                        Text(model.name)
                            .font(.body).bold()
                        Text("Size: \(model.size)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if model.isDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        Button(action: { modelManager.revealInFinder(modelId: model.id) }) {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.plain)
                    } else if modelManager.isDownloading && model.downloadProgress > 0 && model.downloadProgress < 1 {
                        VStack(alignment: .trailing) {
                            ProgressView(value: model.downloadProgress)
                                .frame(width: 100)
                            Text("\(Int(model.downloadProgress * 100))%")
                                .font(.caption2)
                        }
                    } else {
                        Button("Download") {
                            Task {
                                await modelManager.downloadModel(modelId: model.id)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button(action: { modelManager.importLocalModel(modelId: model.id) }) {
                            Image(systemName: "square.and.arrow.down.on.square")
                                .help("Import local directory")
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 5)
                    }
                }
                .padding(.vertical, 5)
            }
            .listStyle(.inset)
        }
        .frame(width: 500, height: 400)
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
