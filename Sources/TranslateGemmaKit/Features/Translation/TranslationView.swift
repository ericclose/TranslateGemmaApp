import SwiftUI
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "com.innovation.TranslateGemmaApp", category: "UI")

enum TranslationMode: String, CaseIterable {
    case plainText = "Plain Text Mode"
    case file = "File Mode"
}

public struct TranslationView: View {
    @Environment(ModelManager.self) private var modelManager
    @Environment(TranslationService.self) private var translationService
    @State private var translationController = TranslationController()
    
    @AppStorage("selectedModelId") private var selectedModelId: String = ""
    
    // Mode State
    @State private var mode: TranslationMode = .plainText
    
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
    @State private var showStopConfirmation = false

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
                
                if mode == .plainText {
                    GeometryReader { geometry in
                        plainTextTranslationView(geometry: geometry)
                    }
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                } else {
                    GeometryReader { geometry in
                        fileModeView(geometry: geometry)
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
                        if mode == .plainText {
                            translateButton
                        } else if !translationController.tasks.isEmpty {
                            startBatchButton
                        }
                    }
                    .padding(.bottom, 10)
                    
                    let shouldShowMetrics = (mode == .plainText && !inputText.isEmpty) || (mode == .file && !translationController.tasks.isEmpty)
                    if shouldShowMetrics {
                        HStack {
                            Spacer()
                            metricsCard
                                .padding(.trailing, 40)
                                .padding(.bottom, 10)
                        }
                    }
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
                        translationController.addFiles(urls, defaultTargetLang: targetLanguage)
                        let src = sourceLanguage == "Auto" ? nil : sourceLanguage
                        for i in 0..<translationController.tasks.count {
                            if translationController.tasks[i].status == .pending && translationController.tasks[i].sourceLang == nil {
                                translationController.tasks[i].sourceLang = src
                            }
                        }
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
        .alert("Stop Translation", isPresented: $showStopConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) {
                cancelTranslation()
            }
        } message: {
            Text("Are you sure you want to stop the current translation process? Unsaved progress will be lost.")
        }
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
        .onChange(of: targetLanguage) { _, newValue in
            if mode == .file {
                translationController.updatePendingTasksTargetLanguage(to: newValue)
            }
        }
        .onChange(of: sourceLanguage) { _, newValue in
            if mode == .file {
                let src = newValue == "Auto" ? nil : newValue
                for i in 0..<translationController.tasks.count {
                    if translationController.tasks[i].status == .pending {
                        translationController.tasks[i].sourceLang = src
                    }
                }
            }
        }
    }
    
    // MARK: - Layout Views
    
    @ViewBuilder
    private func plainTextTranslationView(geometry: GeometryProxy) -> some View {
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
    private func fileModeView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 24) {
            if translationController.tasks.isEmpty {
                dropZone
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Task Queue")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Spacer()
                        
                        Button(action: importBatchFiles) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Add Files")
                            }
                            .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(currentAccentColor)
                        
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.5))
                            
                        Button(action: { withAnimation { translationController.clearTasks() } }) {
                            Text("Clear All").font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach($translationController.tasks) { $task in
                                TaskCard(task: $task, accentColor: currentAccentColor) {
                                    translationController.removeTask(task)
                                }
                            }
                        }
                        .padding(4)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                        Text(translationController.exportDirectory != nil ? "Saving to: \(translationController.exportDirectory!.lastPathComponent)" : "Saving to: Original Directory")
                            .font(.system(size: 11, weight: .medium))
                        
                        Spacer()
                        
                        Button(action: selectExportDirectory) {
                            Text(translationController.exportDirectory != nil ? "Change..." : "Set Export Folder...")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(currentAccentColor.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(currentAccentColor)
                        
                        if translationController.exportDirectory != nil {
                            Button(action: { withAnimation { translationController.exportDirectory = nil } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.03)))
                    .padding(.top, 4)
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
        Button(action: {
            if translationService.isTranslating {
                showStopConfirmation = true
            } else {
                translateAction()
            }
        }) {
            HStack(spacing: 12) {
                if translationService.isTranslating {
                    Image(systemName: "stop.circle.fill").font(.system(size: 18))
                    Text("Stop Translation").font(.system(size: 18, weight: .bold, design: .rounded))
                } else {
                    Image(systemName: "sparkles").font(.system(size: 18, weight: .bold))
                    Text("Translate Now").font(.system(size: 18, weight: .bold, design: .rounded))
                }
            }
            .frame(width: 220, height: 56)
            .background(Capsule().fill(LinearGradient(colors: inputText.isEmpty ? [.gray.opacity(0.3)] : (translationService.isTranslating ? [.red, .red.opacity(0.8)] : [currentAccentColor, currentAccentColor.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing)))
            .foregroundColor(inputText.isEmpty ? .secondary : .white)
            .shadow(color: (translationService.isTranslating ? Color.red : currentAccentColor).opacity(inputText.isEmpty ? 0 : 0.3), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(inputText.isEmpty && !translationService.isTranslating)
    }
    
    @ViewBuilder
    private var metricsCard: some View {
        let shouldShow = (mode == .plainText && !inputText.isEmpty) || (mode == .file && !translationController.tasks.isEmpty)
        if shouldShow && (translationService.isTranslating || translationService.tokensPerSecond > 0) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(translationService.isTranslating ? "Speed" : "Avg Speed")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", translationService.tokensPerSecond))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(currentAccentColor)
                        Text("tok/s")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                    .frame(height: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(translationService.isTranslating ? "ETA" : "Total Time")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(translationService.isTranslating ? formatETA(translationService.estimatedTimeRemaining) : formatETA(translationService.totalTimeTaken))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(currentAccentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }
    
    private func formatETA(_ time: TimeInterval?) -> String {
        guard let time = time, time > 0, !time.isInfinite, !time.isNaN else { return "--:--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    @ViewBuilder
    private var startBatchButton: some View {
        Button(action: {
            if translationController.isBatchProcessing {
                showStopConfirmation = true
            } else {
                startBatchAction()
            }
        }) {
            HStack(spacing: 12) {
                if translationController.isBatchProcessing {
                    Image(systemName: "stop.circle.fill").font(.system(size: 18))
                    Text("Stop Processing").font(.system(size: 18, weight: .bold, design: .rounded))
                } else {
                    Image(systemName: "play.fill").font(.system(size: 18))
                    Text("Start Processing").font(.system(size: 18, weight: .bold, design: .rounded))
                }
            }
            .frame(width: 240, height: 56)
            .background(Capsule().fill(translationController.isBatchProcessing ? .red : currentAccentColor))
            .foregroundColor(.white)
            .shadow(color: (translationController.isBatchProcessing ? Color.red : currentAccentColor).opacity(0.3), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(.plain)
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
                
            ShareLink(item: outputText) {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(OrnamentButtonStyle())
            .disabled(outputText.isEmpty)
            .help("Share Text")
            
            Button(action: exportToFile) { Image(systemName: "square.and.arrow.down") }
                .buttonStyle(OrnamentButtonStyle())
                .disabled(outputText.isEmpty)
                .help("Export as TXT")
        }
    }

    // MARK: - Actions
    
    private func cancelTranslation() {
        currentTranslationTask?.cancel()
        currentTranslationTask = nil
    }
    
    private func selectExportDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Select Export Folder"
        if panel.runModal() == .OK, let url = panel.url {
            withAnimation {
                translationController.exportDirectory = url
            }
        }
    }
    
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
            translationController.addFiles(panel.urls, defaultTargetLang: targetLanguage)
            let src = sourceLanguage == "Auto" ? nil : sourceLanguage
            for i in 0..<translationController.tasks.count {
                if translationController.tasks[i].status == .pending && translationController.tasks[i].sourceLang == nil {
                    translationController.tasks[i].sourceLang = src
                }
            }
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
        currentTranslationTask?.cancel()
        currentTranslationTask = Task {
            await translationController.runBatch(translationService: translationService, selectedModelId: selectedModelId)
            currentTranslationTask = nil
        }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
    }
    
    private func exportToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Translation.txt"
        if panel.runModal() == .OK, let url = panel.url {
            try? outputText.write(to: url, atomically: true, encoding: .utf8)
        }
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
    @Binding var task: TranslationTask
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
            
            // Name & Size
            VStack(alignment: .leading, spacing: 4) {
                Text(task.fileName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(ByteCountFormatter().string(fromByteCount: task.fileSize))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(width: 160, alignment: .leading)
            
            Divider().frame(height: 20)
            
            // Language Settings
            if case .pending = task.status {
                HStack(spacing: 6) {
                    Text(task.sourceLang ?? "Auto")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .leading)
                    
                    Image(systemName: "arrow.right").font(.system(size: 10)).foregroundColor(.secondary.opacity(0.5))
                    
                    Menu {
                        ForEach(LanguageManager.supportedLanguages, id: \.self) { lang in
                            Button(lang) { task.targetLang = lang }
                        }
                    } label: {
                        Text(task.targetLang)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 100)
                }
            } else {
                HStack(spacing: 6) {
                    Text(task.sourceLang ?? "Auto")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .leading)
                    Image(systemName: "arrow.right").font(.system(size: 10)).foregroundColor(.secondary.opacity(0.5))
                    Text(task.targetLang)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(accentColor)
                        .frame(width: 100, alignment: .leading)
                }
            }
            
            Spacer()
            
            // Progress / Status / Metrics
            if case .processing = task.status {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(String(format: "%.1f tok/s", task.tokensPerSecond))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(accentColor)
                        if let eta = task.estimatedTimeRemaining, eta > 0 {
                            Text(formatETA(eta))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    ProgressView()
                        .controlSize(.small)
                        .tint(accentColor)
                }
                .frame(width: 150, alignment: .trailing)
            } else if case .completed(let url) = task.status {
                HStack(spacing: 12) {
                    Text("Completed").font(.system(size: 12, weight: .bold)).foregroundColor(.green)
                    Button(action: { NSWorkspace.shared.activateFileViewerSelecting([url]) }) {
                        Image(systemName: "folder.fill").foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")
                }
            } else if case .failed(let error) = task.status {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                    Text(error).font(.system(size: 10)).foregroundColor(.red).lineLimit(1).frame(maxWidth: 100)
                }
            } else {
                Text("Waiting...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            if case .processing = task.status {
                // Cannot remove while processing
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(.clear)
            } else {
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    task.status == .pending ? Color.white.opacity(0.1) : (
                        task.status == .processing ? accentColor.opacity(0.3) : Color.clear
                    ),
                    lineWidth: 1
                )
        )
    }
    
    private func formatETA(_ time: TimeInterval?) -> String {
        guard let time = time, time >= 0, !time.isInfinite, !time.isNaN else { return "--:--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
