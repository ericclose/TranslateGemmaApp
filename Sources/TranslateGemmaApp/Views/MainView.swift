import SwiftUI
import UniformTypeIdentifiers
import TranslateGemmaLibrary
import os

private let logger = Logger(subsystem: "com.innovation.TranslateGemmaApp", category: "UI")

struct LiquidBackground: View {
    @State private var t: Float = 0
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    @Environment(\.colorScheme) var colorScheme
    var accentColor: Color = .blue
    
    var body: some View {
        if #available(macOS 15.0, *) {
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5 + 0.15 * sin(t * 0.8), 0.5 + 0.15 * cos(t * 1.2)], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ], colors: colorScheme == .dark ? [
                accentColor.opacity(0.3), .indigo.opacity(0.2), accentColor.opacity(0.2),
                accentColor.opacity(0.1), .black, .indigo.opacity(0.1),
                accentColor.opacity(0.2), accentColor.opacity(0.3), .indigo.opacity(0.2)
            ] : [
                accentColor.opacity(0.15), accentColor.opacity(0.1), .white,
                .indigo.opacity(0.05), accentColor.opacity(0.2), accentColor.opacity(0.1),
                .white, accentColor.opacity(0.15), .indigo.opacity(0.1)
            ])
            .onReceive(timer) { _ in
                t += 0.015
            }
            .ignoresSafeArea()
            .blur(radius: 40)
            .animation(.easeInOut(duration: 1.0), value: accentColor)
        } else {
            LinearGradient(
                colors: colorScheme == .dark ? [.black, accentColor.opacity(0.2), .indigo.opacity(0.1)] : [.white, accentColor.opacity(0.1), accentColor.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.0), value: accentColor)
        }
    }
}

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
    
    @State private var isHoveringSource = false
    @State private var isHoveringTarget = false
    
    let languages = ["Chinese", "English", "Japanese", "Korean", "French", "German", "Spanish"]
    
    private var currentAccentColor: Color {
        if selectedModelId.contains("27b") { return .purple }
        if selectedModelId.contains("12b") { return .indigo }
        return .blue
    }
    
    private var formattedModelName: String {
        guard let model = modelManager.models.first(where: { $0.id == selectedModelId }) else { return "No Model" }
        // Format "translategemma-4b-it-4bit" to "TranslateGemma 4B"
        let parts = model.name.lowercased().components(separatedBy: "-")
        if let size = parts.first(where: { $0.hasSuffix("b") }) {
            return "TranslateGemma \(size.uppercased())"
        }
        return model.name
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LiquidBackground(accentColor: currentAccentColor)
                
                VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    AdaptiveLayout(width: geometry.size.width) {
                        // Source Card
                        TranslationCard(
                            title: {
                                Label(importedFileURL != nil ? importedFileURL!.lastPathComponent : "Auto Detect", systemImage: "text.justify.left")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                            },
                            text: $inputText,
                            isReadOnly: false,
                            placeholder: "Type or drop text here...",
                            containerWidth: geometry.size.width,
                            isHovered: isHoveringSource,
                            actions: {
                                HStack(spacing: 8) {
                                    Button(action: importFile) {
                                        Image(systemName: "doc.badge.plus")
                                    }
                                    .buttonStyle(OrnamentButtonStyle())
                                    .help("Import File (⌘I)")
                                    
                                    if !inputText.isEmpty {
                                        Button(action: { withAnimation { inputText = ""; importedFileURL = nil } }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .symbolRenderingMode(.hierarchical)
                                        }
                                        .buttonStyle(OrnamentButtonStyle())
                                    }
                                }
                            }
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
                        
                        // Target Card
                        TranslationCard(
                            title: {
                                Menu {
                                    ForEach(languages, id: \.self) { lang in
                                        Button(lang) { targetLanguage = lang }
                                    }
                                } label: {
                                    HStack {
                                        Text(targetLanguage)
                                        Image(systemName: "chevron.down").font(.system(size: 10))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(.ultraThinMaterial))
                                }
                                .menuStyle(.button)
                            },
                            text: .constant(outputText),
                            isReadOnly: true,
                            placeholder: "Translation will appear here",
                            textColor: .blue,
                            containerWidth: geometry.size.width,
                            isHovered: isHoveringTarget,
                            actions: {
                                HStack(spacing: 8) {
                                    Button(action: copyToClipboard) {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .buttonStyle(OrnamentButtonStyle())
                                    .disabled(outputText.isEmpty)
                                    .help("Copy (⌘C)")
                                    
                                    Button(action: swapLanguages) {
                                        Image(systemName: "arrow.left.and.right")
                                    }
                                    .buttonStyle(OrnamentButtonStyle())
                                    
                                    Button(action: exportFile) {
                                        Image(systemName: "square.and.arrow.up")
                                    }
                                    .buttonStyle(OrnamentButtonStyle())
                                    .disabled(outputText.isEmpty)
                                    .help("Export (⌘E)")
                                }
                            }
                        )
                        .onHover { isHoveringTarget = $0 }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                    
                    Spacer()
                    
                    // Main Action Area
                    HStack(spacing: 20) {
                        Button(action: translateAction) {
                            HStack(spacing: 12) {
                                if translationService.isTranslating {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 18, weight: .bold))
                                }
                                Text("Translate")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                            }
                            .frame(width: 220, height: 56)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: inputText.isEmpty ? [.gray.opacity(0.3)] : [currentAccentColor, currentAccentColor.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: currentAccentColor.opacity(inputText.isEmpty ? 0 : 0.4), radius: 15, x: 0, y: 8)
                            )
                            .foregroundColor(inputText.isEmpty ? .secondary : .white)
                        }
                        .buttonStyle(.plain)
                        .disabled(inputText.isEmpty || translationService.isTranslating)
                        .keyboardShortcut(.return, modifiers: .command)
                    }
                    .padding(.bottom, 50)
                }
            }
            .toolbar {
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showModelDashboard = true }) {
                        Label("Models", systemImage: "cpu")
                    }
                    .help("Model Management")
                }
                
                ToolbarItem(placement: .status) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(LinearGradient(colors: [.green, .green.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 6, height: 6)
                        Text(formattedModelName)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        ZStack {
                            Capsule().fill(.ultraThinMaterial)
                            Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                        }
                    )
                }
            }
        }

        .frame(minWidth: 900, minHeight: 650)
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
    
    func importFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
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
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
    }
    
    func swapLanguages() {
        let currentTarget = targetLanguage
        if currentTarget == "English" {
            targetLanguage = "Chinese"
        } else {
            targetLanguage = "English"
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
}

// MARK: - Components

struct AdaptiveLayout<Content: View>: View {
    let width: CGFloat
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack(spacing: 24) {
            content
        }
        .frame(maxWidth: min(width - 64, 1600))
    }
}


struct NativeTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var textColor: NSColor = .labelColor
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
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
        init(_ parent: NativeTextEditor) { self.parent = parent }
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
    let isHovered: Bool
    @ViewBuilder let actions: Actions
    @Environment(\.colorScheme) var colorScheme
    
    private var fontSize: CGFloat {
        let base: CGFloat = 18
        let scaled = containerWidth / 65
        return max(14, min(base, scaled))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                title
                    .frame(maxWidth: .infinity, alignment: .leading)
                actions
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: 32)
            
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: fontSize, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.4))
                        .allowsHitTesting(false)
                        .padding(.top, 10) // Align with NativeTextEditor vertical padding
                }
                
                if isReadOnly {
                    ScrollView {
                        Text(text.isEmpty ? "" : text)
                            .font(.system(size: fontSize, weight: .medium, design: .rounded))
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                    }
                    .padding(.vertical, 10)
                } else {
                    NativeTextEditor(text: $text, font: .systemFont(ofSize: fontSize, weight: .medium))
                        .padding(.vertical, 10)
                        .frame(minHeight: 250)
                }
            }
        }
        .padding(geometryPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.15 : 0.6),
                                .white.opacity(colorScheme == .dark ? 0.05 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.12 : 0.06), radius: isHovered ? 30 : 20, x: 0, y: isHovered ? 15 : 10)
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
    }
    
    private var geometryPadding: CGFloat {
        containerWidth > 1200 ? 40 : 28
    }
}

struct OrnamentButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .frame(width: 32, height: 32)
            .background(
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().strokeBorder(.white.opacity(colorScheme == .dark ? 0.1 : 0.4), lineWidth: 0.5)
                }
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ModelDashboardView: View {
    @ObservedObject var modelManager: ModelManager
    @Binding var selectedModelId: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    private var currentAccentColor: Color {
        if selectedModelId.contains("27b") { return .purple }
        if selectedModelId.contains("12b") { return .indigo }
        return .blue
    }
    
    var body: some View {
        ZStack {
            LiquidBackground(accentColor: currentAccentColor)
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "cpu")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.blue)
                            Text("Model Library")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                        }
                        Text("Manage your local LLM weights and storage").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(OrnamentButtonStyle())
                }
                .padding(32)
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(modelManager.models) { model in
                            ModelRowView(
                                model: model,
                                modelManager: modelManager,
                                selectedModelId: $selectedModelId
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
                
                // Unified Storage Management Footer
                VStack(spacing: 0) {
                    Divider().opacity(colorScheme == .dark ? 0.2 : 0.1)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Storage Location").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).textCase(.uppercase)
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(modelManager.currentHubPath)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.primary.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 10) {
                            Button("Reset") { modelManager.resetToDefaultHubPath() }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(.primary.opacity(0.05)))
                            
                            Button(action: { modelManager.selectCustomHubPath() }) {
                                Label("Change", systemImage: "pencil")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.blue))
                            .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .frame(width: 680, height: 640)
    }
}

struct ModelRowView: View {
    let model: ModelInfo
    @ObservedObject var modelManager: ModelManager
    @Binding var selectedModelId: String
    @Environment(\.colorScheme) var colorScheme
    @State private var showDeleteConfirmation = false
    @State private var isHovered = false
    
    var isSelected: Bool { model.id == selectedModelId }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue.opacity(0.15) : (model.isDownloaded ? Color.blue.opacity(0.05) : Color.primary.opacity(0.03)))
                    .frame(width: 48, height: 48)
                Image(systemName: isSelected ? "brain.head.profile.fill" : (model.isDownloaded ? "brain.head.profile" : "cloud.circle"))
                    .font(.system(size: 22))
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
                        Text("• Active").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.blue)
                    } else if model.isDownloaded {
                        Text("• Local").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.green.opacity(0.8))
                    }
                }
            }
            Spacer()
            
            if model.isDownloaded {
                HStack(spacing: 10) {
                    if isSelected {
                        Image(systemName: "checkmark.seal.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: { modelManager.revealInFinder(modelId: model.id) }) {
                        Image(systemName: "folder").font(.system(size: 12, weight: .bold)).padding(8).background(Circle().fill(.primary.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                    
                    Button(action: { showDeleteConfirmation = true }) {
                        Image(systemName: "trash").font(.system(size: 12, weight: .bold)).padding(8).background(Circle().fill(.red.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .help("Delete Model")
                }
            } else if modelManager.downloadingModelId == model.id {
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 8) {
                        ProgressView(value: model.downloadProgress).progressViewStyle(.linear).frame(width: 120).tint(.blue)
                        Button(action: { modelManager.cancelDownload() }) {
                            Image(systemName: "stop.circle.fill").font(.system(size: 20)).foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack(spacing: 4) {
                        if modelManager.isConnecting && model.completedSize == 0 {
                            Text("Connecting...").italic()
                        } else {
                            Text(String(format: "%.1f%%", model.downloadProgress * 100))
                            Text("•")
                            Text(ByteCountFormatter.string(fromByteCount: model.completedSize, countStyle: .file))
                            Text("/")
                            Text(ByteCountFormatter.string(fromByteCount: model.totalSize, countStyle: .file))
                        }
                    }
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.blue.opacity(0.8))
                    .padding(.trailing, 28)
                }
            } else {
                Button(action: { Task { await modelManager.downloadModel(modelId: model.id) } }) {
                    HStack(spacing: 8) {
                        Image(systemName: "icloud.and.arrow.down").font(.system(size: 12, weight: .bold))
                        Text("Download").font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .foregroundColor(.white)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .opacity(modelManager.isDownloading ? 0.5 : 1.0)
                .disabled(modelManager.isDownloading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.05) : (isHovered ? Color.primary.opacity(0.03) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            if model.isDownloaded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedModelId = model.id
                }
            }
        }
        .alert("Confirm Deletion", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelManager.deleteModel(modelId: model.id)
                if isSelected { selectedModelId = "" }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(model.name)? This action cannot be undone.")
        }
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
