import SwiftUI
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "com.innovation.TranslateGemmaApp", category: "UI")

enum TranslationMode: String, CaseIterable {
    case text = "Text Translation"
    case file = "File Processing"
}

public struct TranslationView: View {
    @Environment(ModelManager.self) private var modelManager
    @Environment(TranslationService.self) private var translationService
    @State private var translationController = TranslationController()
    
    @AppStorage("selectedModelId") private var selectedModelId: String = ""
    
    // Mode State
    @State private var mode: TranslationMode = .text
    
    // Text Mode State
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var sourceLanguage: String = "Auto"
    @State private var targetLanguage: String = "English"
    
    // UI State
    @State private var showModelDashboard = false
    @State private var importedFileURL: URL? = nil
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert = false
    @State private var isHoveringSource = false
    @State private var isHoveringTarget = false
    @State private var showSourceLanguagePicker = false
    @State private var showTargetLanguagePicker = false
    @State private var languageSearchText = ""
    @State private var isDraggingOver = false
    @State private var currentTranslationTask: Task<Void, Never>? = nil

    let languages = LanguageManager.supportedLanguages
    
    public init() {}
    
    private var currentAccentColor: Color {
        .blue
    }
    
    private var detectedSourceLanguage: String? {
        LanguageManager.detectLanguage(for: inputText)
    }

    private func filteredLanguages(includeAuto: Bool) -> [String] {
        let base = languages.filter {
            languageSearchText.isEmpty || $0.lowercased().contains(languageSearchText.lowercased())
        }
        if includeAuto && (languageSearchText.isEmpty || "auto".contains(languageSearchText.lowercased())) {
            return ["Auto"] + base
        }
        return base
    }

    // MARK: - Main Body
    
    public var body: some View {
        VStack(spacing: 0) {
            // Content
            VStack(spacing: 0) {
                // Top Mode Switcher & Language Selector
                VStack(spacing: 12) {
                    Text("TranslateGemma")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(currentAccentColor)

                    ModeSwitcher(selectedMode: $mode, accentColor: currentAccentColor)
                    
                    HStack(spacing: 0) {
                        sourceHeader
                            .frame(maxWidth: .infinity)
                        
                        swapButton
                            .padding(.horizontal, 16)
                        
                        targetHeader
                            .frame(maxWidth: .infinity)
                    }
                    .frame(width: 440)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 15)
                .overlay(alignment: .topTrailing) {
                    Button(action: { showModelDashboard = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "cpu")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(currentAccentColor)
                            Text("Model Library")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(ZStack { Capsule().fill(.ultraThinMaterial); Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5) })
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 40)
                    .padding(.top, 12)
                }
                .background(
                    TitleBarView()
                        .frame(height: 120) // Covers the entire header area
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea()
                )
                
                if mode == .text {
                    GeometryReader { geometry in
                        textTranslationView(geometry: geometry)
                    }
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                } else {
                    GeometryReader { geometry in
                        fileProcessingView(geometry: geometry)
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                }
                
                Spacer()
                
                // Bottom Section with Status Bar and Translate Button
                ZStack(alignment: .bottom) {
                    HStack {
                        SystemStatusBar()
                            .padding(.leading, 40)
                        Spacer()
                    }
                    
                    HStack {
                        if mode == .text {
                            translateButton
                        } else if !translationController.tasks.isEmpty {
                            startBatchButton
                        }
                    }
                    .padding(.bottom, 10)
                }
                .padding(.top, 40)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(
            ZStack {
                LiquidBackground(accentColor: currentAccentColor)
                VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                    .ignoresSafeArea()
            }
            .allowsHitTesting(false)
        )
        .frame(minWidth: 1000, minHeight: 700)
        .navigationTitle("TranslateGemma")
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            Task {
                var urls: [URL] = []
                for provider in providers {
                    if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil),
                       let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    }
                }
                if !urls.isEmpty {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        mode = .file
                        translationController.addFiles(urls)
                    }
                    return true
                }
                return false
            }
            return true
        }
        .overlay(
            Group {
                if isDraggingOver {
                    ZStack {
                        Color.black.opacity(0.2)
                        RoundedRectangle(cornerRadius: 30)
                            .strokeBorder(currentAccentColor, style: StrokeStyle(lineWidth: 4, dash: [10, 10]))
                            .padding(40)
                        
                        VStack(spacing: 20) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 60))
                                .foregroundColor(currentAccentColor)
                            Text("Drop files to process...")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
                }
            }
        )
        .sheet(isPresented: $showModelDashboard) {
            ModelDashboardView(selectedModelId: $selectedModelId)
                .environment(modelManager)
        }
        .alert("Error", isPresented: $showErrorAlert, presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { message in Text(message) }
        .onAppear {
            initializeModel()
        }
        .onChange(of: inputText) { _, newValue in
            translationService.recordActivity()
            if newValue.isEmpty { 
                currentTranslationTask?.cancel()
                currentTranslationTask = nil
                outputText = "" 
            } else if sourceLanguage == "Auto", let detected = detectedSourceLanguage {
                // If detected language matches target, switch target to avoid redundant translation
                if detected == targetLanguage {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        if detected == "English" {
                            targetLanguage = "Chinese (Simplified)"
                        } else {
                            targetLanguage = "English"
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Layout Views
    
    @ViewBuilder
    private func textTranslationView(geometry: GeometryProxy) -> some View {
        HStack(spacing: 24) {
            TranslationCard(
                title: { sourceActions },
                text: $inputText,
                isReadOnly: false,
                placeholder: "Type or drop text here...",
                containerWidth: geometry.size.width,
                isHovered: isHoveringSource,
                actions: { EmptyView() }
            )
            .onHover { isHoveringSource = $0 }
            
            TranslationCard(
                title: { EmptyView() },
                text: .constant(outputText),
                isReadOnly: true,
                placeholder: "Translation will appear here",
                textColor: currentAccentColor,
                containerWidth: geometry.size.width,
                isHovered: isHoveringTarget,
                actions: { targetActions }
            )
            .onHover { isHoveringTarget = $0 }
        }
        .frame(maxWidth: min(geometry.size.width - 64, 1600))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
    
    @ViewBuilder
    private func fileProcessingView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 24) {
            if translationController.tasks.isEmpty {
                dropZone
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Task Queue")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Spacer()
                        Button(action: { withAnimation { translationController.clearTasks() } }) {
                            Text("Clear All").font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(translationController.tasks) { task in
                                TaskCard(task: task, accentColor: currentAccentColor) {
                                    translationController.removeTask(task)
                                }
                            }
                        }
                        .padding(4)
                    }
                    
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Results will be saved as `filename.\(getLangCode(targetLanguage)).ext` in the same directory.")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.1), lineWidth: 1))
                )
            }
        }
        .frame(maxWidth: min(geometry.size.width - 64, 1600))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    @ViewBuilder
    private var dropZone: some View {
        Button(action: importBatchFiles) {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(currentAccentColor.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 48))
                        .foregroundColor(currentAccentColor)
                }
                
                VStack(spacing: 8) {
                    Text("Drop Subtitle or Markdown Files")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Supports SRT, VTT, ASS, and Markdown")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Text("Browse Files")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(currentAccentColor))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .strokeBorder(currentAccentColor.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 8]))
                .background(RoundedRectangle(cornerRadius: 32).fill(currentAccentColor.opacity(0.02)))
        )
    }

    // MARK: - Helper Subviews
    
    @ViewBuilder
    private var sourceHeader: some View {
        Button(action: { showSourceLanguagePicker.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: sourceLanguage == "Auto" ? "sparkles" : "character.bubble.fill")
                    .font(.system(size: 10))
                    .foregroundColor(currentAccentColor)
                
                Text(sourceLanguage == "Auto" ? (detectedSourceLanguage != nil ? "Auto: \(detectedSourceLanguage!)" : "Auto Detect") : sourceLanguage)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(ZStack { Capsule().fill(.ultraThinMaterial); Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5) })
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showSourceLanguagePicker) {
            languagePicker(selectedLanguage: $sourceLanguage, isPresented: $showSourceLanguagePicker, includeAuto: true)
        }
    }
    
    @ViewBuilder
    private var targetHeader: some View {
        Button(action: { showTargetLanguagePicker.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 10))
                    .foregroundColor(currentAccentColor)
                
                Text(targetLanguage)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(ZStack { Capsule().fill(.ultraThinMaterial); Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5) })
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showTargetLanguagePicker) {
            languagePicker(selectedLanguage: $targetLanguage, isPresented: $showTargetLanguagePicker, includeAuto: false)
        }
    }
    
    @ViewBuilder
    private var swapButton: some View {
        Button(action: swapLanguages) {
            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(currentAccentColor)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.ultraThinMaterial))
                .opacity(translationService.isTranslating ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(translationService.isTranslating)
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
                Text("Translate Now").font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .frame(width: 220, height: 56)
            .background(Capsule().fill(LinearGradient(colors: inputText.isEmpty ? [.gray.opacity(0.3)] : [currentAccentColor, currentAccentColor.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .foregroundColor(inputText.isEmpty ? .secondary : .white)
            .shadow(color: currentAccentColor.opacity(inputText.isEmpty ? 0 : 0.3), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(inputText.isEmpty || translationService.isTranslating)
    }
    
    @ViewBuilder
    private var startBatchButton: some View {
        Button(action: startBatchAction) {
            HStack(spacing: 12) {
                if translationController.isBatchProcessing {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Image(systemName: "play.fill").font(.system(size: 18))
                }
                Text("Start Processing").font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .frame(width: 240, height: 56)
            .background(Capsule().fill(currentAccentColor))
            .foregroundColor(.white)
            .shadow(color: currentAccentColor.opacity(0.3), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(translationController.isBatchProcessing)
    }

    @ViewBuilder
    private var sourceActions: some View {
        HStack(spacing: 8) {
            if !inputText.isEmpty {
                Button(action: { withAnimation { inputText = ""; outputText = "" } }) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(OrnamentButtonStyle())
            }
        }
    }
    
    @ViewBuilder
    private var targetActions: some View {
        HStack(spacing: 8) {
            Button(action: copyToClipboard) { Image(systemName: "doc.on.doc") }
                .buttonStyle(OrnamentButtonStyle())
                .disabled(outputText.isEmpty)
        }
    }

    // MARK: - Actions
    
    private func initializeModel() {
        Task {
            await modelManager.fetchCollectionModels()
            let downloaded = modelManager.models.filter { $0.isDownloaded }
            if downloaded.isEmpty {
                showModelDashboard = true
            } else if downloaded.count == 1 {
                selectedModelId = downloaded[0].id
            }
        }
    }
    
    private func importSingleFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.text, .plainText, UTType(filenameExtension: "srt")!, UTType(filenameExtension: "vtt")!, UTType(filenameExtension: "ass")!, UTType("public.markdown") ?? .plainText]
        if panel.runModal() == .OK, let url = panel.url {
            inputText = (try? String(contentsOf: url)) ?? ""
        }
    }
    
    private func importBatchFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.text, .plainText, UTType(filenameExtension: "srt")!, UTType(filenameExtension: "vtt")!, UTType(filenameExtension: "ass")!, UTType("public.markdown") ?? .plainText]
        if panel.runModal() == .OK {
            translationController.addFiles(panel.urls)
        }
    }
    
    private func translateAction() {
        guard !selectedModelId.isEmpty else { showModelDashboard = true; return }
        currentTranslationTask?.cancel()
        currentTranslationTask = Task {
            do {
                try await translationService.loadModel(modelId: selectedModelId)
                let sourceLang = sourceLanguage == "Auto" ? nil : sourceLanguage
                outputText = ""
                _ = try await translationService.translate(text: inputText, sourceLang: sourceLang, targetLang: targetLanguage) { chunk in
                    if !Task.isCancelled {
                        outputText += chunk
                    }
                }
            } catch is CancellationError {
                // Ignore cancellation
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
            currentTranslationTask = nil
        }
    }
    
    private func startBatchAction() {
        guard !selectedModelId.isEmpty else { showModelDashboard = true; return }
        Task {
            await translationController.runBatch(targetLang: targetLanguage, translationService: translationService, selectedModelId: selectedModelId)
        }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
    }
    
    private func swapLanguages() {
        let detected = detectedSourceLanguage ?? "English"
        let oldSource = sourceLanguage
        let oldTarget = targetLanguage
        
        if oldSource == "Auto" {
            // From Auto -> Target, swap to Target -> Detected
            sourceLanguage = oldTarget
            targetLanguage = detected
        } else {
            sourceLanguage = oldTarget
            targetLanguage = oldSource
        }
        
        if !outputText.isEmpty {
            inputText = outputText
            outputText = ""
        }
    }
    
    private func getLangCode(_ name: String) -> String {
        LanguageManager.getShortCode(for: name)
    }
    
    @ViewBuilder
    private func languagePicker(selectedLanguage: Binding<String>, isPresented: Binding<Bool>, includeAuto: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search...", text: $languageSearchText).textFieldStyle(.plain)
            }
            .padding(10).background(Color.black.opacity(0.05))
            
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(filteredLanguages(includeAuto: includeAuto), id: \.self) { lang in
                        LanguageRow(lang: lang, isSelected: selectedLanguage.wrappedValue == lang, accentColor: currentAccentColor) {
                            selectedLanguage.wrappedValue = lang
                            isPresented.wrappedValue = false
                        }
                    }
                }
                .padding(4)
            }
        }
        .frame(width: 200, height: 300)
    }
}

// MARK: - Components

struct ModeSwitcher: View {
    @Binding var selectedMode: TranslationMode
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TranslationMode.allCases, id: \.self) { mode in
                Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedMode = mode } }) {
                    Text(mode.rawValue)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                if selectedMode == mode {
                                    Capsule()
                                        .fill(accentColor)
                                        .matchedGeometryEffect(id: "mode", in: modeNamespace)
                                }
                            }
                        )
                        .foregroundColor(selectedMode == mode ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
    }
    
    @Namespace private var modeNamespace
}

struct TaskCard: View {
    let task: TranslationTask
    let accentColor: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // File Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(accentColor.opacity(0.1))
                Image(systemName: "doc.text.fill").foregroundColor(accentColor).font(.system(size: 16))
            }
            .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.fileName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                
                HStack(spacing: 10) {
                    Text(ByteCountFormatter().string(fromByteCount: task.fileSize))
                    Circle().fill(.secondary).frame(width: 2, height: 2)
                    Text(task.status.description)
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if case .processing = task.status {
                ProgressView(value: task.status.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 100)
                    .tint(accentColor)
            } else if case .completed(let url) = task.status {
                Button(action: { NSWorkspace.shared.activateFileViewerSelecting([url]) }) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(accentColor)
                }
                .buttonStyle(.plain)
                .help("Show in Finder")
            } else if case .failed = task.status {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
            }
            
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))
    }
}



struct LanguageRow: View {
    let lang: String
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Text(lang)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? accentColor : .primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                HStack {
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(accentColor)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? accentColor.opacity(0.12) : (isHovering ? Color.primary.opacity(0.05) : .clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
