import SwiftUI
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "com.innovation.TranslateGemmaApp", category: "UI")

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
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert = false
    @State private var isHoveringSource = false
    @State private var isHoveringTarget = false
    @State private var showSourceLanguagePicker = false
    @State private var showTargetLanguagePicker = false
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

    // Removed filteredLanguages in favor of LanguagePickerView logic

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
                        LanguageSelectorButton(title: sourceLanguage, isAuto: sourceLanguage == "Auto", detectedLanguage: detectedSourceLanguage, accentColor: currentAccentColor) {
                            showSourceLanguagePicker.toggle()
                        }
                        .frame(maxWidth: .infinity)
                        .popover(isPresented: $showSourceLanguagePicker) {
                            LanguagePickerView(selectedLanguage: $sourceLanguage, isPresented: $showSourceLanguagePicker, includeAuto: true, accentColor: currentAccentColor)
                        }
                        
                        swapButton
                            .padding(.horizontal, 16)
                        
                        LanguageSelectorButton(title: targetLanguage, accentColor: currentAccentColor) {
                            showTargetLanguagePicker.toggle()
                        }
                        .frame(maxWidth: .infinity)
                        .popover(isPresented: $showTargetLanguagePicker) {
                            LanguagePickerView(selectedLanguage: $targetLanguage, isPresented: $showTargetLanguagePicker, includeAuto: false, accentColor: currentAccentColor)
                        }
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
                        PlainTextTranslationView(
                            inputText: $inputText,
                            outputText: $outputText,
                            isHoveringSource: $isHoveringSource,
                            isHoveringTarget: $isHoveringTarget,
                            geometry: geometry,
                            currentAccentColor: currentAccentColor,
                            sourceActions: AnyView(sourceActions),
                            targetActions: AnyView(targetActions)
                        )
                    }
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                } else {
                    GeometryReader { geometry in
                        FileModeView(
                            translationController: translationController,
                            geometry: geometry,
                            currentAccentColor: currentAccentColor,
                            importBatchFiles: importBatchFiles,
                            selectExportDirectory: selectExportDirectory
                        )
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
            guard !translationController.isBatchProcessing else { return false }
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
                        let src = sourceLanguage == "Auto" ? nil : sourceLanguage
                        translationController.addFiles(urls, sourceLang: src, targetLang: targetLanguage)
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
                        
                        VStack(spacing: 24) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 72))
                                .foregroundColor(currentAccentColor)
                                .shadow(color: currentAccentColor.opacity(0.4), radius: 20)
                            Text("Drop files to process")
                                .font(.system(size: 28, weight: .black, design: .rounded))
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
        .overlay(
            Group {
                if showStopConfirmation {
                    CustomConfirmationDialog(
                        title: mode == .plainText ? "Stop Translation" : "Stop Processing",
                        message: "Are you sure you want to stop the current process? Unsaved progress will be lost.",
                        confirmTitle: "Stop",
                        style: .destructive,
                        onConfirm: {
                            withAnimation {
                                cancelTranslation()
                                showStopConfirmation = false
                            }
                        },
                        onCancel: {
                            withAnimation { showStopConfirmation = false }
                        }
                    )
                }
            }
        )
    }
    
    // Helper Subviews removed and moved to separate files

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
            LanguagePickerView(selectedLanguage: $sourceLanguage, isPresented: $showSourceLanguagePicker, includeAuto: true, accentColor: currentAccentColor)
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
            LanguagePickerView(selectedLanguage: $targetLanguage, isPresented: $showTargetLanguagePicker, includeAuto: false, accentColor: currentAccentColor)
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
        if shouldShow && translationService.totalTimeTaken != nil {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Time")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(TimeFormatter.formatETA(translationService.totalTimeTaken))
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
    
    private var isBatchFinished: Bool {
        !translationController.isBatchProcessing && 
        !translationController.tasks.isEmpty && 
        translationController.tasks.allSatisfy { 
            if case .completed = $0.status { return true }
            if case .failed = $0.status { return true }
            return false
        }
    }

    @ViewBuilder
    private var startBatchButton: some View {
        Button(action: {
            if isBatchFinished {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    translationController.clearTasks()
                }
            } else if translationController.isBatchProcessing {
                showStopConfirmation = true
            } else {
                startBatchAction()
            }
        }) {
            HStack(spacing: 12) {
                if isBatchFinished {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 18))
                    Text("Finish").font(.system(size: 18, weight: .bold, design: .rounded))
                } else if translationController.isBatchProcessing {
                    Image(systemName: "stop.circle.fill").font(.system(size: 18))
                    Text("Stop Processing").font(.system(size: 18, weight: .bold, design: .rounded))
                } else {
                    Image(systemName: "play.fill").font(.system(size: 18))
                    Text("Start Processing").font(.system(size: 18, weight: .bold, design: .rounded))
                }
            }
            .frame(width: 240, height: 56)
            .background(Capsule().fill(isBatchFinished ? Color.green : (translationController.isBatchProcessing ? Color.red : currentAccentColor)))
            .foregroundColor(.white)
            .shadow(color: (isBatchFinished ? Color.green : (translationController.isBatchProcessing ? Color.red : currentAccentColor)).opacity(0.3), radius: 15, x: 0, y: 8)
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
            let src = sourceLanguage == "Auto" ? nil : sourceLanguage
            translationController.addFiles(panel.urls, sourceLang: src, targetLang: targetLanguage)
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
    
}
