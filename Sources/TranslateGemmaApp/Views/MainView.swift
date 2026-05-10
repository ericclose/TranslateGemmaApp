import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @StateObject var modelManager = ModelManager()
    @StateObject var translationService = TranslationService()
    
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var targetLanguage: String = "Chinese"
    @State private var showModelDashboard = false
    @State private var isProcessingFile = false
    
    let languages = ["Chinese", "English", "Japanese", "Korean", "French", "German", "Spanish"]
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("TranslateGemma")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                    
                    Spacer()
                    
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
                            Text("Source (Auto)")
                                .font(.caption).bold()
                                .foregroundColor(.secondary)
                            Spacer()
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
                Button(action: translate) {
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
        .onAppear {
            Task {
                await modelManager.fetchCollectionModels()
                if modelManager.models.filter({ $0.isDownloaded }).isEmpty {
                    showModelDashboard = true
                }
            }
        }
    }
    
    func translate() {
        Task {
            // Check for downloaded model
            guard let model = modelManager.models.first(where: { $0.isDownloaded }) else {
                showModelDashboard = true
                return
            }
            
            do {
                try await translationService.loadModel(modelId: model.id)
                outputText = try await translationService.translate(text: inputText, sourceLang: nil, targetLang: targetLanguage)
            } catch {
                print("Translation error: \(error)")
            }
        }
    }
    
    func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.text, .plainText, UTType(filenameExtension: "srt")!, UTType(filenameExtension: "vtt")!, UTType(filenameExtension: "ass")!, UTType("public.markdown") ?? .plainText]
        if panel.runModal() == .OK {
            if let url = panel.url {
                inputText = (try? String(contentsOf: url)) ?? ""
            }
        }
    }
    
    func exportFile() {
        let panel = NSSavePanel()
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
