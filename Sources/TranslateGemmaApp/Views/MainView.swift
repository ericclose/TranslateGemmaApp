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
                // Simplified Clean Background
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()
                
                VisualEffectView(material: .fullScreenUI, blendingMode: .withinWindow)
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
                            title: {
                                Text(importedFileURL != nil ? importedFileURL!.lastPathComponent : "Auto Detect")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                            },
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
                            title: {
                                Picker("", selection: $targetLanguage) {
                                    ForEach(languages, id: \.self) { lang in
                                        Text(lang).tag(lang)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 100)
                                .labelsHidden()
                                .background(Capsule().fill(.ultraThinMaterial))
                            },
                            text: .constant(outputText),
                            isReadOnly: true,
                            placeholder: "Translation will appear here",
                            textColor: .blue,
                            containerWidth: geometry.size.width,
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
            ModelDashboardView(
                modelManager: modelManager,
                selectedModelId: $selectedModelId
            )
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
        HStack(spacing: 20) {
            Text("TranslateGemma")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary.opacity(0.9))
            
            Spacer()
            
            HStack(spacing: 10) {
                Button(action: { modelManager.selectCustomHubPath() }) {
                    Image(systemName: "folder")
                }
                .buttonStyle(CircleGlassButtonStyle())
                
                Button(action: { showModelDashboard = true }) {
                    Image(systemName: "cpu")
                }
                .buttonStyle(CircleGlassButtonStyle())
                
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14))
                        .foregroundColor(.blue.opacity(0.8))
                    
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
                    .frame(width: 260) // Increased width to avoid truncation
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
        }
    }
}

struct NativeTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var textColor: NSColor = .labelColor
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = textColor
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        
        // Remove all implicit padding for perfect alignment
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.font = font
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeTextEditor
        
        init(_ parent: NativeTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
    }
}

struct TranslationCard<HeaderTitle: View, Actions: View>: View {
    @ViewBuilder let title: HeaderTitle
    @Binding var text: String
    let isReadOnly: Bool
    let placeholder: String
    var textColor: Color = .primary
    let containerWidth: CGFloat
    @ViewBuilder let actions: Actions
    
    private var fontSize: CGFloat {
        let base: CGFloat = 18
        let scaled = containerWidth / 65
        return max(14, min(base, scaled))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                title
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                actions
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: 28)
            
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: fontSize, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.3))
                        .allowsHitTesting(false)
                        .padding(.top, 1) // Tiny offset for visual balance
                }
                
                if isReadOnly {
                    ScrollView {
                        Text(text.isEmpty ? "" : text)
                            .font(.system(size: fontSize, weight: .medium, design: .rounded))
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                } else {
                    NativeTextEditor(
                        text: $text,
                        font: .systemFont(ofSize: fontSize, weight: .medium)
                    )
                    .frame(minHeight: 200)
                }
            }
        }
        .padding(geometryPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private var geometryPadding: CGFloat {
        containerWidth > 1200 ? 28 : 16
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
    @Binding var selectedModelId: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model Library")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Manage your local LLM weights")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(CircleGlassButtonStyle())
            }
            .padding(24)
            .background(.ultraThinMaterial)
            
            Divider().opacity(0.1)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(modelManager.models) { model in
                        ModelRowView(
                            model: model, 
                            modelManager: modelManager,
                            isSelected: model.id == selectedModelId
                        )
                    }
                }
                .padding(20)
            }
            
            Divider().opacity(0.1)
            
            // Footer Info
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.secondary)
                Text(modelManager.currentHubPath)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: { modelManager.selectCustomHubPath() }) {
                    Text("Change Location")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.link)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial.opacity(0.5))
        }
        .frame(width: 550, height: 550)
        .background(VisualEffectView(material: .fullScreenUI, blendingMode: .withinWindow))
    }
}

struct ModelRowView: View {
    let model: ModelInfo
    @ObservedObject var modelManager: ModelManager
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Model Icon
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue.opacity(0.2) : (model.isDownloaded ? Color.blue.opacity(0.1) : Color.primary.opacity(0.05)))
                    .frame(width: 44, height: 44)
                
                Image(systemName: isSelected ? "brain.head.profile.fill" : (model.isDownloaded ? "brain.head.profile" : "cloud.circle"))
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .blue : (model.isDownloaded ? .blue : .secondary))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .blue : .primary)
                
                HStack(spacing: 8) {
                    Text(model.size)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    if isSelected {
                        Text("• Active")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                    } else if model.isDownloaded {
                        Text("• Local")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.green.opacity(0.8))
                    }
                }
            }
            
            Spacer()
            
            if model.isDownloaded {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.green)
                    
                    Button(action: { modelManager.revealInFinder(modelId: model.id) }) {
                        Image(systemName: "folder")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(8)
                            .background(Circle().fill(.primary.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")
                }
            } else if modelManager.isDownloading && model.downloadProgress > 0 {
                VStack(alignment: .trailing, spacing: 4) {
                    ProgressView(value: model.downloadProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 100)
                        .tint(.blue)
                    
                    Text("\(Int(model.downloadProgress * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
            } else {
                Button(action: { 
                    Task { await modelManager.downloadModel(modelId: model.id) }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.system(size: 12, weight: .bold))
                        Text("Download")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.primary))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .opacity(modelManager.isDownloading ? 0.5 : 1.0)
                .disabled(modelManager.isDownloading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color.blue.opacity(0.08) : Color.white.opacity(NSApp.effectiveAppearance.name == .darkAqua ? 0.05 : 0.4))
                .shadow(color: isSelected ? Color.blue.opacity(0.1) : Color.black.opacity(0.02), radius: isSelected ? 10 : 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
        )
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



