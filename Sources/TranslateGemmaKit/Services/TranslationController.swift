import Foundation
import SwiftUI
import Observation

@Observable
public class TranslationController {
    public var tasks: [TranslationTask] = []
    public var isBatchProcessing = false
    public var exportDirectory: URL? = nil
    
    private let srtParser = SRTParser()
    private let vttParser = VTTParser()
    private let assParser = ASSParser()
    private let mdParser = MarkdownParser()
    
    public init() {}
    
    public func addFiles(_ urls: [URL], defaultTargetLang: String) {
        for url in urls {
            if !tasks.contains(where: { $0.sourceURL == url }) {
                tasks.append(TranslationTask(sourceURL: url, targetLang: defaultTargetLang))
            }
        }
    }
    
    public func updatePendingTasksTargetLanguage(to lang: String) {
        for i in 0..<tasks.count {
            if tasks[i].status == .pending {
                tasks[i].targetLang = lang
            }
        }
    }
    
    public func clearTasks() {
        tasks.removeAll()
    }
    
    public func removeTask(_ task: TranslationTask) {
        tasks.removeAll(where: { $0.id == task.id })
    }
    
    public func processFile(url: URL, sourceLang: String?, targetLang: String, onProgress: ((Int, Int) -> Void)? = nil, translator: (String) async throws -> String) async throws -> String {
        let content = try String(contentsOf: url)
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "srt":
            var paragraphs = srtParser.parse(content: content)
            let total = paragraphs.count
            for i in 0..<total {
                onProgress?(i + 1, total)
                paragraphs[i].text = try await translator(paragraphs[i].text)
            }
            return srtParser.write(paragraphs: paragraphs)
            
        case "vtt":
            var paragraphs = vttParser.parse(content: content)
            let total = paragraphs.count
            for i in 0..<total {
                onProgress?(i + 1, total)
                paragraphs[i].text = try await translator(paragraphs[i].text)
            }
            return vttParser.write(paragraphs: paragraphs)
            
        case "ass":
            var paragraphs = assParser.parse(content: content)
            let total = paragraphs.count
            for i in 0..<total {
                onProgress?(i + 1, total)
                paragraphs[i].text = try await translator(paragraphs[i].text)
            }
            return assParser.write(paragraphs: paragraphs)
            
        case "md", "markdown":
            let chunks = mdParser.parseForTranslation(content: content)
            var translatedTexts: [String] = []
            let translatableCount = chunks.filter { if case .text = $0 { return true }; return false }.count
            var current = 0
            for chunk in chunks {
                if case .text(let t, let placeholders) = chunk {
                    current += 1
                    onProgress?(current, translatableCount)
                    var translated = try await translator(t)
                    for (ph, original) in placeholders {
                        translated = translated.replacingOccurrences(of: ph, with: original)
                    }
                    translatedTexts.append(translated)
                }
            }
            return mdParser.assemble(chunks: chunks, translatedTexts: translatedTexts)
            
        default:
            onProgress?(0, 1)
            let result = try await translator(content)
            onProgress?(1, 1)
            return result
        }
    }
    
    @MainActor
    public func runBatch(translationService: TranslationService, selectedModelId: String) async {
        isBatchProcessing = true
        defer { isBatchProcessing = false }
        
        let totalPendingSize = tasks.filter { $0.status == .pending }.map { $0.fileSize }.reduce(0, +)
        translationService.startBatchSession(estimatedTokens: Int(totalPendingSize / 2))
        defer { translationService.endBatchSession() }
        
        for i in 0..<tasks.count {
            guard tasks[i].status == .pending else { continue }
            
            try? Task.checkCancellation()
            if Task.isCancelled { break }
            
            let url = tasks[i].sourceURL
            let sourceLang = tasks[i].sourceLang
            let targetLang = tasks[i].targetLang
            let outputURL = generateOutputURL(for: url, targetLang: targetLang)
            
            let estimatedFileTokens = Int(tasks[i].fileSize / 2)
            var currentFileTokens = 0
            let fileStartTime = Date()
            var lastFileUpdate = Date()
            
            tasks[i].status = .processing
            
            do {
                print("--- DEBUG: Processing file: \(url.lastPathComponent) ---")
                let folderURL = exportDirectory ?? url.deletingLastPathComponent()
                if !FileManager.default.isWritableFile(atPath: folderURL.path) {
                    throw NSError(domain: "TranslationController", code: 1, userInfo: [NSLocalizedDescriptionKey: "No write permission in directory: \(folderURL.lastPathComponent)"])
                }
                
                try await translationService.loadModel(modelId: selectedModelId)
                
                let result = try await processFile(
                    url: url,
                    sourceLang: sourceLang,
                    targetLang: targetLang,
                    onProgress: { current, total in
                        if current % 10 == 0 || current == total {
                             print("--- DEBUG: Progress for \(url.lastPathComponent): \(current)/\(total) ---")
                        }
                    }
                ) { text in
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return text
                    }
                    let resultText = try await translationService.translate(text: text, sourceLang: sourceLang, targetLang: targetLang) { chunk in
                        currentFileTokens += 1
                        
                        let now = Date()
                        if now.timeIntervalSince(lastFileUpdate) >= 1.0 {
                            let elapsed = now.timeIntervalSince(fileStartTime)
                            if elapsed > 0 {
                                self.tasks[i].tokensPerSecond = Double(currentFileTokens) / elapsed
                                let remaining = max(0, estimatedFileTokens - currentFileTokens)
                                if self.tasks[i].tokensPerSecond > 0 {
                                    self.tasks[i].estimatedTimeRemaining = Double(remaining) / self.tasks[i].tokensPerSecond
                                }
                            }
                            lastFileUpdate = now
                        }
                    }
                    return resultText
                }
                
                print("--- DEBUG: Writing result for \(url.lastPathComponent) (\(result.count) chars) to \(outputURL.lastPathComponent) ---")
                try result.write(to: outputURL, atomically: true, encoding: .utf8)
                tasks[i].status = .completed(outputURL: outputURL)
            } catch is CancellationError {
                tasks[i].status = .failed("Cancelled")
                break
            } catch {
                tasks[i].status = .failed(error.localizedDescription)
            }
        }
    }
    
    private func generateOutputURL(for url: URL, targetLang: String) -> URL {
        let langCode = LanguageManager.getShortCode(for: targetLang)
        let fileName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let newName = "\(fileName).\(langCode).\(ext)"
        let baseDir = exportDirectory ?? url.deletingLastPathComponent()
        let outputURL = baseDir.appendingPathComponent(newName)
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            var index = 1
            var indexedURL: URL
            repeat {
                let indexedName = "\(fileName).\(langCode).\(index).\(ext)"
                indexedURL = baseDir.appendingPathComponent(indexedName)
                index += 1
            } while FileManager.default.fileExists(atPath: indexedURL.path)
            return indexedURL
        }
        
        return outputURL
    }
}

public struct TranslationTask: Identifiable, Equatable {
    public let id = UUID()
    public let sourceURL: URL
    public var status: TaskStatus = .pending
    
    public var sourceLang: String? = nil
    public var targetLang: String
    
    public var tokensPerSecond: Double = 0
    public var estimatedTimeRemaining: TimeInterval? = nil
    
    public var fileName: String { sourceURL.lastPathComponent }
    public var fileSize: Int64 {
        (try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64) ?? 0
    }
    
    public static func == (lhs: TranslationTask, rhs: TranslationTask) -> Bool {
        lhs.id == rhs.id
    }
}

public enum TaskStatus: Equatable {
    case pending
    case processing
    case completed(outputURL: URL)
    case failed(String)
    
    public var description: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed(let error): return "Failed: \(error)"
        }
    }
}

