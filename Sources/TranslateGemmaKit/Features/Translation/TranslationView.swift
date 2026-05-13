import SwiftUI
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "com.innovation.TranslateGemmaApp", category: "UI")

public struct TranslationView: View {
    @Environment(ModelManager.self) private var modelManager
    @Environment(TranslationService.self) private var translationService
    private let translationController = TranslationController()
    
    @AppStorage("selectedModelId") private var selectedModelId: String = ""
    
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var targetLanguage: String = "Chinese"
    @State private var showModelDashboard = false
    @State private var importedFileURL: URL? = nil
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert = false
    
    @State private var isHoveringSource = false
    @State private var isHoveringTarget = false
    
    let languages = ["Chinese", "English", "Japanese", "Korean", "French", "German", "Spanish"]
    
    public init() {}
    
    private var currentAccentColor: Color {
        if selectedModelId.contains("27b") { return .purple }
        if selectedModelId.contains("12b") { return .indigo }
        return .blue
    }
    
    private var formattedModelName: String {
        guard let model = modelManager.models.first(where: { $0.id == selectedModelId }) else { return "No Model" }
        let parts = model.name.lowercased().components(separatedBy: "-")
        if let size = parts.first(where: { $0.hasSuffix("b") }) {
            return "TranslateGemma \(size.uppercased())"
        }
    return model.name
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var sourceHeader: some View {
        Label(importedFileURL != nil ? importedFileURL!.lastPathComponent : "Auto Detect", systemImage: "text.justify.left")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private var sourceActions: some View {
        HStack(spacing: 8) {
            Button(action: importFile) { Image(systemName: "doc.badge.plus") }
                .buttonStyle(OrnamentButtonStyle())
                .help("Import File (⌘I)")
            
            if !inputText.isEmpty {
                Button(action: { withAnimation { inputText = ""; importedFileURL = nil } }) {
                    Image(systemName: "xmark.circle.fill").symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(OrnamentButtonStyle())
            }
        }
    }
    
    @State private var showLanguagePicker = false
    
    @ViewBuilder
    private var targetHeader: some View {
        Button(action: { showLanguagePicker.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 10))
                    .foregroundColor(currentAccentColor)
                
                Text(targetLanguage)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                    Capsule()
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                }
            )
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showLanguagePicker, arrowEdge: .bottom) {
            VStack(alignment: .center, spacing: 2) {
                ForEach(languages, id: \.self) { lang in
                    Button(action: {
                        targetLanguage = lang
                        showLanguagePicker = false
                    }) {
                        ZStack {
                            Text(lang)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            HStack {
                                Spacer()
                                if targetLanguage == lang {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(currentAccentColor)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(targetLanguage == lang ? currentAccentColor.opacity(0.1) : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .frame(width: 140)
            .background(VisualEffectView(material: .popover, blendingMode: .withinWindow))
        }
    }
    
    @ViewBuilder
    private var targetActions: some View {
        HStack(spacing: 8) {
            Button(action: copyToClipboard) { Image(systemName: "doc.on.doc") }
                .buttonStyle(OrnamentButtonStyle())
                .disabled(outputText.isEmpty)
                .help("Copy (⌘C)")
            
            Button(action: swapLanguages) { Image(systemName: "arrow.left.and.right") }
                .buttonStyle(OrnamentButtonStyle())
            
            Button(action: exportFile) { Image(systemName: "square.and.arrow.up") }
                .buttonStyle(OrnamentButtonStyle())
                .disabled(outputText.isEmpty)
                .help("Export (⌘E)")
        }
    }
    
    @ViewBuilder
    private var translateButton: some View {
        Button(action: translateAction) {
            HStack(spacing: 12) {
                if translationService.isTranslating {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Image(systemName: "sparkles").font(.system(size: 18, weight: .bold))
                }
                Text("Translate").font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .frame(width: 220, height: 56)
            .background(
                Capsule().fill(LinearGradient(colors: inputText.isEmpty ? [.gray.opacity(0.3)] : [currentAccentColor, currentAccentColor.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: currentAccentColor.opacity(inputText.isEmpty ? 0 : 0.4), radius: 15, x: 0, y: 8)
            )
            .foregroundColor(inputText.isEmpty ? .secondary : .white)
        }
        .buttonStyle(.plain)
        .disabled(inputText.isEmpty || translationService.isTranslating)
        .keyboardShortcut(.return, modifiers: .command)
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                LiquidBackground(accentColor: currentAccentColor)
                VisualEffectView(material: .sidebar, blendingMode: .withinWindow).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    AdaptiveLayout(width: geometry.size.width) {
                        TranslationCard(
                            title: { sourceHeader },
                            text: $inputText,
                            isReadOnly: false,
                            placeholder: "Type or drop text here...",
                            containerWidth: geometry.size.width,
                            isHovered: isHoveringSource,
                            actions: { sourceActions }
                        )
                        .onHover { isHoveringSource = $0 }
                        .dropDestination(for: URL.self) { items, _ in
                            if let url = items.first {
                                self.importedFileURL = url
                                self.inputText = (try? String(contentsOf: url)) ?? ""
                                return true
                            }
                            return false
                        }
                        
                        TranslationCard(
                            title: { targetHeader },
                            text: .constant(outputText),
                            isReadOnly: true,
                            placeholder: "Translation will appear here",
                            textColor: .blue,
                            containerWidth: geometry.size.width,
                            isHovered: isHoveringTarget,
                            actions: { targetActions }
                        )
                        .onHover { isHoveringTarget = $0 }
                    }
                    .padding(.horizontal, 40).padding(.bottom, 30) // Adjusted padding
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        translateButton
                    }
                    .padding(.bottom, 50)
                }
                
                // System Status Bar in bottom-left
                VStack {
                    Spacer()
                    HStack {
                        SystemStatusBar()
                            .padding(.leading, 40)
                            .padding(.bottom, 25) // Slightly adjusted for optical balance
                        Spacer()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showModelDashboard = true }) { Label("Models", systemImage: "cpu") }
                        .help("Model Management")
                }
                ToolbarItem(placement: .status) {
                    HStack(spacing: 6) {
                        Circle().fill(LinearGradient(colors: [.green, .green.opacity(0.6)], startPoint: .top, endPoint: .bottom)).frame(width: 6, height: 6)
                        Text(formattedModelName).font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(ZStack { Capsule().fill(.ultraThinMaterial); Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 0.5) })
                }
            }
        }
        .frame(minWidth: 900, minHeight: 650)
        .sheet(isPresented: $showModelDashboard) {
            ModelDashboardView(selectedModelId: $selectedModelId)
                .environment(modelManager)
        }
        .alert("Error", isPresented: $showErrorAlert, presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { message in Text(message) }
        .onAppear {
            Task {
                await modelManager.fetchCollectionModels()
                let downloaded = modelManager.models.filter { $0.isDownloaded }
                
                if downloaded.isEmpty {
                    // Scenario: No models locally, show dashboard and clear selection
                    selectedModelId = ""
                    showModelDashboard = true
                } else if downloaded.count == 1 {
                    // Scenario: Exactly one model available, auto-activate it
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedModelId = downloaded[0].id
                    }
                } else {
                    // Scenario: Multiple models exist, validate that current selection is still available
                    if !selectedModelId.isEmpty && !downloaded.contains(where: { $0.id == selectedModelId }) {
                        selectedModelId = ""
                    }
                }
            }
        }
        .onChange(of: inputText) { _, _ in
            translationService.recordActivity()
        }
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
    
    func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
    }
    
    func swapLanguages() {
        targetLanguage = (targetLanguage == "English") ? "Chinese" : "English"
    }
    
    func translateAction() {
        // Guidance: If no model is selected, open the Model Library
        guard !selectedModelId.isEmpty else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showModelDashboard = true
            }
            return
        }
        
        Task {
            do {
                try await translationService.loadModel(modelId: selectedModelId)
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
}

public struct AdaptiveLayout<Content: View>: View {
    let width: CGFloat
    @ViewBuilder let content: Content
    
    public init(width: CGFloat, @ViewBuilder content: () -> Content) {
        self.width = width
        self.content = content()
    }
    
    public var body: some View {
        HStack(spacing: 24) { content }
            .frame(maxWidth: min(width - 64, 1600))
    }
}
