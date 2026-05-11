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
        GeometryReader { geometry in
            ZStack {
                // Responsive Liquid Glass Background
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.white, Color.blue.opacity(0.1), Color.white]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Image("liquid_background", bundle: .module)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .opacity(0.6)
                        .blur(radius: 20)
                    
                    Image("liquid_background", bundle: .module)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width * 1.2)
                        .opacity(0.8)
                }
                .ignoresSafeArea()
                
                VisualEffectView(material: .fullScreenUI, blendingMode: .withinWindow)
                    .opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with Safe Area awareness
                    HeaderView(
                        selectedModelId: $selectedModelId,
                        modelManager: modelManager,
                        showModelDashboard: $showModelDashboard
                    )
                    .padding(.top, max(geometry.safeAreaInsets.top, 20))
                    .padding(.horizontal, 32)
                    
                    Spacer(minLength: 20)
                    
                    // Responsive Content Cards
                    AdaptiveLayout(width: geometry.size.width) {
                        // Source Card
                        TranslationCard(
                            title: importedFileURL != nil ? importedFileURL!.lastPathComponent : "Auto Detect",
                            text: $inputText,
                            isReadOnly: false,
                            placeholder: "Type something...",
                            containerWidth: geometry.size.width,
                            actions: {
                                HStack(spacing: 12) {
                                    Button(action: importFile) {
                                        Image(systemName: "doc.badge.plus")
                                    }
                                    .buttonStyle(GlassButtonStyle())
                                    .help("Import File")
                                    
                                    if !inputText.isEmpty {
                                        Button(action: { inputText = ""; importedFileURL = nil }) {
                                            Image(systemName: "xmark")
                                        }
                                        .buttonStyle(GlassButtonStyle())
                                    }
                                }
                            }
                        )
                        
                        // Target Card
                        TranslationCard(
                            title: targetLanguage,
                            text: .constant(outputText),
                            isReadOnly: true,
                            placeholder: "Translation will appear here",
                            textColor: .blue,
                            containerWidth: geometry.size.width,
                            centerView: {
                                Picker("", selection: $targetLanguage) {
                                    ForEach(languages, id: \.self) { lang in
                                        Text(lang).tag(lang)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 110)
                                .labelsHidden()
                                .background(Capsule().fill(.ultraThinMaterial))
                            },
                            actions: {
                                HStack(spacing: 12) {
                                    Button(action: copyToClipboard) {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .buttonStyle(GlassButtonStyle())
                                    .disabled(outputText.isEmpty)
                                    
                                    Button(action: swapLanguages) {
                                        Image(systemName: "arrow.left.and.right")
                                    }
                                    .buttonStyle(GlassButtonStyle())
                                    
                                    Button(action: exportFile) {
                                        Image(systemName: "square.and.arrow.up")
                                    }
                                    .buttonStyle(GlassButtonStyle())
                                    .disabled(outputText.isEmpty)
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer(minLength: 20)
                    
                    // Floating Translate Button
                    if !inputText.isEmpty {
                        Button(action: translateAction) {
                            HStack(spacing: 8) {
                                if translationService.isTranslating {
                                    ProgressView().controlSize(.small).brightness(1)
                                } else {
                                    Text("Translate")
                                    Image(systemName: "sparkles")
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.8))
                                    .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                            )
                            .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 24))
                    }
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
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
    
    func swapLanguages() {
        let currentTarget = targetLanguage
        if currentTarget == "English" {
            targetLanguage = "Chinese"
        } else {
            targetLanguage = "English"
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

// MARK: - Components

struct AdaptiveLayout<Content: View>: View {
    let width: CGFloat
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack(spacing: 24) {
            content
        }
        .frame(maxWidth: min(width - 64, 1600)) // Max content width of 1600
    }
}

struct HeaderView: View {
    @Binding var selectedModelId: String
    @ObservedObject var modelManager: ModelManager
    @Binding var showModelDashboard: Bool
    
    var body: some View {
        HStack(spacing: 24) {
            Text("TranslateGemma")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary.opacity(0.8))
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: { modelManager.selectCustomHubPath() }) {
                    Image(systemName: "folder")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(CircleGlassButtonStyle())
                .help("Storage: \(modelManager.currentHubPath)")
                
                Button(action: { showModelDashboard = true }) {
                    Image(systemName: "cpu")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(CircleGlassButtonStyle())
                .help("Model Dashboard")
                
                HStack(spacing: 12) {
                    Text("Model")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    let downloadedModels = modelManager.models.filter { $0.isDownloaded }
                    Picker("", selection: $selectedModelId) {
                        if downloadedModels.isEmpty {
                            Text("No Models").tag("")
                        } else {
                            ForEach(downloadedModels) { model in
                                Text(model.name).tag(model.id)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 240) // Increased width to prevent truncation
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
        }
    }
}

struct TranslationCard<Actions: View, Center: View>: View {
    let title: String
    @Binding var text: String
    let isReadOnly: Bool
    let placeholder: String
    var textColor: Color = .primary
    let containerWidth: CGFloat
    @ViewBuilder let centerView: Center
    @ViewBuilder let actions: Actions
    
    init(
        title: String,
        text: Binding<String>,
        isReadOnly: Bool,
        placeholder: String,
        textColor: Color = .primary,
        containerWidth: CGFloat,
        @ViewBuilder centerView: () -> Center = { EmptyView() },
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self._text = text
        self.isReadOnly = isReadOnly
        self.placeholder = placeholder
        self.textColor = textColor
        self.containerWidth = containerWidth
        self.centerView = centerView()
        self.actions = actions()
    }
    
    private var fontSize: CGFloat {
        let base: CGFloat = 22 // Reduced from 28 to 22 for better information density
        let scaled = containerWidth / 50
        return max(16, min(base, scaled))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.6))
                    
                    Spacer()
                    
                    actions
                }
                
                centerView
            }
            
            if isReadOnly {
                ScrollView {
                    Text(text.isEmpty ? placeholder : text)
                        .font(.system(size: fontSize, weight: .medium, design: .rounded))
                        .foregroundColor(text.isEmpty ? .secondary.opacity(0.3) : textColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
            } else {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: fontSize, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.3))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $text)
                        .font(.system(size: fontSize, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 200)
                }
            }
        }
        .padding(geometryPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    private var geometryPadding: CGFloat {
        containerWidth > 1200 ? 40 : 24
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(8)
            .background(Circle().fill(.ultraThinMaterial))
            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct CircleGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 32, height: 32)
            .background(Circle().fill(.ultraThinMaterial))
            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
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
            .background(.ultraThinMaterial)
            
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
            .scrollContentBackground(.hidden)
        }
        .frame(width: 500, height: 400)
        .background(.ultraThinMaterial)
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



