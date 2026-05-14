import SwiftUI
import UniformTypeIdentifiers
import NaturalLanguage
import os

private let logger = Logger(subsystem: "com.innovation.TranslateGemmaApp", category: "UI")

public struct TranslationView: View {
    @Environment(ModelManager.self) private var modelManager
    @Environment(TranslationService.self) private var translationService
    private let translationController = TranslationController()
    
    @AppStorage("selectedModelId") private var selectedModelId: String = ""
    
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var sourceLanguage: String = "Auto"
    @State private var targetLanguage: String = "English"
    @State private var showModelDashboard = false
    @State private var importedFileURL: URL? = nil
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert = false
    
    @State private var isHoveringSource = false
    @State private var isHoveringTarget = false
    
    let languages = [
        "Arabic (Egypt)", "Arabic (Saudi Arabia)", "Bulgarian (Bulgaria)", "Bengali (Bangladesh)",
        "Bengali (India)", "Catalan (Spain)", "Czech (Czechia)", "Danish (Denmark)",
        "German (Germany)", "Greek (Greece)", "Spanish (Mexico)", "Estonian (Estonia)",
        "Persian (Farsi)", "Finnish (Finland)", "Filipino (Tagalog)", "French (Canada)",
        "French (France)", "Gujarati (India)", "Hebrew (Israel)", "Hindi (India)",
        "Croatian (Croatia)", "Hungarian (Hungary)", "Indonesian (Indonesia)", "Icelandic (Iceland)",
        "Italian (Italy)", "Japanese (Japan)", "Kannada (India)", "Korean (South Korea)",
        "Lithuanian (Lithuania)", "Latvian (Latvia)", "Malayalam (India)", "Marathi (India)",
        "Dutch (Netherlands)", "Norwegian (Norway)", "Punjabi (India)", "Polish (Poland)",
        "Portuguese (Brazil)", "Portuguese (Portugal)", "Romanian (Romania)", "Russian (Russia)",
        "Slovak (Slovakia)", "Slovenian (Slovenia)", "Serbian (Serbia)", "Swedish (Sweden)",
        "Swahili (Kenya)", "Swahili (Tanzania)", "Tamil (India)", "Telugu (India)",
        "Thai (Thailand)", "Turkish (Turkey)", "Ukrainian (Ukraine)", "Urdu (Pakistan)",
        "Vietnamese (Vietnam)", "Chinese (Simplified)", "Chinese (Traditional)", "Zulu (South Africa)",
        "English"
    ].sorted()
    
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
    
    private var detectedSourceLanguage: String? {
        guard !inputText.isEmpty else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(inputText)
        guard let languageCode = recognizer.dominantLanguage?.rawValue else { return nil }
        
        // Map common detection codes to our specific language list names
        if languageCode == "zh-Hant" { return "Chinese (Traditional)" }
        if languageCode.hasPrefix("zh") { return "Chinese (Simplified)" }
        if languageCode.hasPrefix("en") { return "English" }
        
        let locale = Locale(identifier: "en")
        return locale.localizedString(forLanguageCode: languageCode)?.capitalized
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
    
    @ViewBuilder
    private func languagePicker(selectedLanguage: Binding<String>, isPresented: Binding<Bool>, includeAuto: Bool) -> some View {
        VStack(spacing: 0) {
            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                TextField("Search language...", text: $languageSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .rounded))
                if !languageSearchText.isEmpty {
                    Button(action: { languageSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.05))
            
            Divider().opacity(0.5)
            
            ScrollView {
                VStack(alignment: .center, spacing: 1) {
                    let displayLanguages = filteredLanguages(includeAuto: includeAuto)
                    
                    if displayLanguages.isEmpty {
                        Text("No results")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(displayLanguages, id: \.self) { lang in
                            LanguageRow(
                                lang: lang,
                                isSelected: selectedLanguage.wrappedValue == lang,
                                accentColor: currentAccentColor
                            ) {
                                selectedLanguage.wrappedValue = lang
                                isPresented.wrappedValue = false
                                languageSearchText = ""
                            }
                        }
                    }
                }
                .padding(4)
            }
            .scrollIndicators(.hidden)
            .background(Color.clear)
        }
        .frame(width: 200, height: 350)
    }
    
    @ViewBuilder
    private var sourceHeader: some View {
        HStack(spacing: 8) {
            Button(action: { showSourceLanguagePicker.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: sourceLanguage == "Auto" ? "sparkles" : "character.bubble.fill")
                        .font(.system(size: 10))
                        .foregroundColor(currentAccentColor)
                    
                    Text(sourceLanguage == "Auto" ? (detectedSourceLanguage != nil ? "Auto: \(detectedSourceLanguage!)" : "Auto Detect") : sourceLanguage)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 120)
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
            .popover(isPresented: $showSourceLanguagePicker, arrowEdge: .top) {
                languagePicker(selectedLanguage: $sourceLanguage, isPresented: $showSourceLanguagePicker, includeAuto: true)
            }
            
            if let fileURL = importedFileURL {
                Text(fileURL.lastPathComponent)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
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
    
    @State private var showSourceLanguagePicker = false
    @State private var showTargetLanguagePicker = false
    @State private var languageSearchText = ""
    

    
    @ViewBuilder
    private var targetHeader: some View {
        Button(action: { showTargetLanguagePicker.toggle() }) {
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
            .frame(minWidth: 120)
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
        .popover(isPresented: $showTargetLanguagePicker, arrowEdge: .top) {
            languagePicker(selectedLanguage: $targetLanguage, isPresented: $showTargetLanguagePicker, includeAuto: false)
        }
    }

    
    @ViewBuilder
    private var targetActions: some View {
        HStack(spacing: 8) {
            Button(action: copyToClipboard) { Image(systemName: "doc.on.doc") }
                .buttonStyle(OrnamentButtonStyle())
                .disabled(outputText.isEmpty)
                .help("Copy (⌘C)")
            
            Button(action: exportFile) { Image(systemName: "square.and.arrow.up") }
                .buttonStyle(OrnamentButtonStyle())
                .disabled(outputText.isEmpty)
                .help("Export (⌘E)")
        }
    }
    
    private var swapButton: some View {
        Button(action: swapLanguages) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 32, height: 32)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(currentAccentColor)
            }
        }
        .buttonStyle(.plain)
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
                            title: { sourceActions },
                            text: $inputText,
                            isReadOnly: false,
                            placeholder: "Type or drop text here...",
                            containerWidth: geometry.size.width,
                            isHovered: isHoveringSource,
                            actions: { sourceHeader }
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
                        
                        swapButton
                            .zIndex(1) // Ensure it's above card shadows if they overlap
                        
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
        .onChange(of: inputText) { _, newValue in
            translationService.recordActivity()
            if newValue.isEmpty {
                outputText = ""
            } else if sourceLanguage == "Auto" && detectedSourceLanguage == "English" && targetLanguage == "English" {
                targetLanguage = "Chinese (Simplified)"
            }
        }
        .onChange(of: sourceLanguage) { _, newValue in
            if newValue == "English" && targetLanguage == "English" {
                targetLanguage = "Chinese (Simplified)"
            }
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
        // 1. Capture the current state before moving anything
        let detected = detectedSourceLanguage ?? "English"
        let oldSource = sourceLanguage
        let oldTarget = targetLanguage
        let oldOutput = outputText
        
        // 2. Perform text swap
        if !oldOutput.isEmpty {
            inputText = oldOutput
            outputText = ""
        }
        
        // 3. Perform language swap
        if oldSource == "Auto" {
            // From Auto -> Target, swap to Target -> Detected
            sourceLanguage = oldTarget
            targetLanguage = detected
        } else {
            sourceLanguage = oldTarget
            targetLanguage = oldSource
        }
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
                let sourceLang = sourceLanguage == "Auto" ? nil : sourceLanguage
                outputText = "" // Clear before starting
                
                if let fileURL = importedFileURL {
                    outputText = try await translationController.processFile(url: fileURL, targetLang: targetLanguage) { text in
                        try await translationService.translate(text: text, sourceLang: sourceLang, targetLang: targetLanguage) { chunk in
                            outputText += chunk
                        }
                    }
                } else {
                    _ = try await translationService.translate(text: inputText, sourceLang: sourceLang, targetLang: targetLanguage) { chunk in
                        outputText += chunk
                    }
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
        HStack(spacing: 12) { content }
            .frame(maxWidth: min(width - 64, 1600))
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
