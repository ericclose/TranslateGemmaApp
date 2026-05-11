import SwiftUI
import UniformTypeIdentifiers
import TranslateGemmaLibrary
import os

private let logger = Logger(subsystem: "com.innovation.TranslateGemmaApp", category: "UI")

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
            // Native Window Background
            VisualEffectView(material: .windowBackground, blendingMode: .withinWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 20) {
                    Text("TranslateGemma")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    
                    Spacer()
                    
                    // Model Selector
                    let downloadedModels = modelManager.models.filter { $0.isDownloaded }
                    if !downloadedModels.isEmpty {
                        Picker("Model", selection: $selectedModelId) {
                            ForEach(downloadedModels) { model in
                                Text(model.name).tag(model.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 220)
                    }
                    
                    Divider().frame(height: 16)
                    
                    // Storage Path Icon
                    Button(action: { modelManager.selectCustomHubPath() }) {
                        Image(systemName: "internaldrive")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .help("Storage: \(modelManager.currentHubPath)")
                    
                    // Dashboard Icon
                    Button(action: { showModelDashboard = true }) {
                        Image(systemName: "cpu")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .help("Model Dashboard")
                }
                .padding(.horizontal, 20)
                .frame(height: 52)
                .background(VisualEffectView(material: .titlebar, blendingMode: .withinWindow))
                
                Divider()
                
                // Content Area
                HStack(spacing: 0) {
                    // Source Card
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(importedFileURL != nil ? importedFileURL!.lastPathComponent : "Auto Detect")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: importFile) {
                                Image(systemName: "doc.badge.plus")
                            }
                            .buttonStyle(.plain)
                            .help("Import File")
                            
                            if !inputText.isEmpty {
                                Button(action: { inputText = ""; importedFileURL = nil }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        TextEditor(text: $inputText)
                            .font(.system(size: 16))
                            .scrollContentBackground(.hidden)
                            .padding(12)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                    
                    // Target Card
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Picker("", selection: $targetLanguage) {
                                ForEach(languages, id: \.self) { lang in
                                    Text(lang).tag(lang)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                            
                            Spacer()
                            
                            Button(action: copyToClipboard) {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.plain)
                            .help("Copy Results")
                            .disabled(outputText.isEmpty)
                            
                            Button(action: exportFile) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .buttonStyle(.plain)
                            .help("Export Results")
                            .disabled(outputText.isEmpty)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        TextEditor(text: .constant(outputText))
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.02))
                }
                
                Divider()
                
                // Footer Action
                HStack {
                    if translationService.isTranslating {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 8)
                        Text("Processing with AI...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: translateAction) {
                        HStack {
                            Text("Translate")
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        .frame(width: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(translationService.isTranslating || inputText.isEmpty)
                }
                .padding(20)
                .background(VisualEffectView(material: .contentBackground, blendingMode: .withinWindow))
            }
        }
        .frame(minWidth: 850, minHeight: 550)
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
            let modelIdToUse = selectedModelId.isEmpty ? downloaded.first?.id : selectedModelId
            
            guard let modelId = modelIdToUse else {
                showModelDashboard = true
                return
            }
            
            do {
                try await translationService.loadModel(modelId: modelId)
                if let fileURL = importedFileURL {
                    outputText = try await translationController.processFile(url: fileURL, targetLang: targetLanguage) { text in
                        try await translationService.translate(text: text, sourceLang: nil, targetLang: targetLanguage)
                    }
                } else {
                    outputText = try await translationService.translate(text: inputText, sourceLang: nil, targetLang: targetLanguage)
                }
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
    
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
    }
    
    func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.text, .plainText, UTType(filenameExtension: "srt")!, UTType(filenameExtension: "vtt")!, UTType(filenameExtension: "ass")!, UTType("public.markdown") ?? .plainText]
        if panel.runModal() == .OK, let url = panel.url {
            importedFileURL = url
            inputText = (try? String(contentsOf: url)) ?? ""
        }
    }
    
    func exportFile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = importedFileURL != nil ? "translated_" + importedFileURL!.lastPathComponent : "translated.txt"
        if panel.runModal() == .OK, let url = panel.url {
            try? outputText.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

struct ModelDashboardView: View {
    @ObservedObject var modelManager: ModelManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Model Management")
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.name)
                            .font(.body.bold())
                        Text(model.size)
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
                        ProgressView(value: model.downloadProgress)
                            .frame(width: 80)
                    } else {
                        Button("Download") {
                            Task { await modelManager.downloadModel(modelId: model.id) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 8)
            }
            .listStyle(.inset)
        }
        .frame(width: 480, height: 380)
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
