import Foundation
import SwiftUI
import Observation

@Observable
public class TranslationController {
    public var tasks: [TranslationTask] = []
    public var isBatchProcessing = false
    
    private let srtParser = SRTParser()
    private let vttParser = VTTParser()
    private let assParser = ASSParser()
    private let mdParser = MarkdownParser()
    
    public init() {}
    
    public func addFiles(_ urls: [URL]) {
        for url in urls {
            if !tasks.contains(where: { $0.sourceURL == url }) {
                tasks.append(TranslationTask(sourceURL: url))
            }
        }
    }
    
    public func clearTasks() {
        tasks.removeAll()
    }
    
    public func removeTask(_ task: TranslationTask) {
        tasks.removeAll(where: { $0.id == task.id })
    }
    
    public func processFile(url: URL, targetLang: String, onProgress: ((Int, Int) -> Void)? = nil, translator: (String) async throws -> String) async throws -> String {
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
    
    public func runBatch(targetLang: String, translationService: TranslationService, selectedModelId: String) async {
        isBatchProcessing = true
        defer { isBatchProcessing = false }
        
        for i in 0..<tasks.count {
            guard tasks[i].status == .pending else { continue }
            
            let url = tasks[i].sourceURL
            let outputURL = generateOutputURL(for: url, targetLang: targetLang)
            
            do {
                let folderURL = url.deletingLastPathComponent()
                if !FileManager.default.isWritableFile(atPath: folderURL.path) {
                    throw NSError(domain: "TranslationController", code: 1, userInfo: [NSLocalizedDescriptionKey: "No write permission in directory: \(folderURL.lastPathComponent)"])
                }
                
                try await translationService.loadModel(modelId: selectedModelId)
                
                let result = try await processFile(
                    url: url,
                    targetLang: targetLang,
                    onProgress: { current, total in
                        self.tasks[i].status = .processing(current: current, total: total)
                    }
                ) { text in
                    return try await self.translateWithStreaming(text: text, targetLang: targetLang, service: translationService)
                }
                
                try result.write(to: outputURL, atomically: true, encoding: .utf8)
                tasks[i].status = .completed(outputURL: outputURL)
            } catch {
                tasks[i].status = .failed(error.localizedDescription)
            }
        }
    }
    
    private func translateWithStreaming(text: String, targetLang: String, service: TranslationService) async throws -> String {
        var result = ""
        _ = try await service.translate(text: text, sourceLang: nil, targetLang: targetLang) { chunk in
            result += chunk
        }
        return result
    }
    
    private func generateOutputURL(for url: URL, targetLang: String) -> URL {
        let langCode = LanguageManager.getShortCode(for: targetLang)
        let fileName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let newName = "\(fileName).\(langCode).\(ext)"
        let outputURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            var index = 1
            var indexedURL: URL
            repeat {
                let indexedName = "\(fileName).\(langCode).\(index).\(ext)"
                indexedURL = url.deletingLastPathComponent().appendingPathComponent(indexedName)
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
    case processing(current: Int, total: Int)
    case completed(outputURL: URL)
    case failed(String)
    
    public var description: String {
        switch self {
        case .pending: return "Pending"
        case .processing(let current, let total): return "Processing \(current)/\(total)"
        case .completed: return "Completed"
        case .failed(let error): return "Failed: \(error)"
        }
    }
    
    public var progress: Double {
        switch self {
        case .processing(let current, let total): return Double(current) / Double(total)
        case .completed: return 1.0
        default: return 0.0
        }
    }
}

