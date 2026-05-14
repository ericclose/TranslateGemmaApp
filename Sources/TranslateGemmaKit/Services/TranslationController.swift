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
    
    public func processFile(url: URL, targetLang: String, translator: (String) async throws -> String) async throws -> String {
        let content = try String(contentsOf: url)
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "srt":
            var paragraphs = srtParser.parse(content: content)
            for i in 0..<paragraphs.count {
                paragraphs[i].text = try await translator(paragraphs[i].text)
            }
            return srtParser.write(paragraphs: paragraphs)
            
        case "vtt":
            var paragraphs = vttParser.parse(content: content)
            for i in 0..<paragraphs.count {
                paragraphs[i].text = try await translator(paragraphs[i].text)
            }
            return vttParser.write(paragraphs: paragraphs)
            
        case "ass":
            var paragraphs = assParser.parse(content: content)
            for i in 0..<paragraphs.count {
                paragraphs[i].text = try await translator(paragraphs[i].text)
            }
            return assParser.write(paragraphs: paragraphs)
            
        case "md", "markdown":
            let chunks = mdParser.parseForTranslation(content: content)
            var translatedTexts: [String] = []
            for chunk in chunks {
                if case .text(let t) = chunk {
                    translatedTexts.append(try await translator(t))
                }
            }
            return mdParser.assemble(chunks: chunks, translatedTexts: translatedTexts)
            
        default:
            return try await translator(content)
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
                // Check write permission
                let folderURL = url.deletingLastPathComponent()
                if !FileManager.default.isWritableFile(atPath: folderURL.path) {
                    throw NSError(domain: "TranslationController", code: 1, userInfo: [NSLocalizedDescriptionKey: "No write permission in directory: \(folderURL.lastPathComponent)"])
                }
                
                // Load model
                try await translationService.loadModel(modelId: selectedModelId)
                
                let content = try String(contentsOf: url)
                let ext = url.pathExtension.lowercased()
                let result: String
                
                switch ext {
                case "srt", "vtt", "ass":
                    let parser: SubtitleParser
                    if ext == "srt" { parser = srtParser }
                    else if ext == "vtt" { parser = vttParser }
                    else { parser = assParser }
                    var paragraphs = parser.parse(content: content)
                    let total = paragraphs.count
                    for j in 0..<total {
                        tasks[i].status = .processing(current: j + 1, total: total)
                        paragraphs[j].text = try await translateWithStreaming(text: paragraphs[j].text, targetLang: targetLang, service: translationService)
                    }
                    result = parser.write(paragraphs: paragraphs)
                    
                case "md", "markdown":
                    let chunks = mdParser.parseForTranslation(content: content)
                    var translatedTexts: [String] = []
                    let translatableCount = chunks.filter { if case .text = $0 { return true }; return false }.count
                    var current = 0
                    for chunk in chunks {
                        if case .text(let t) = chunk {
                            current += 1
                            tasks[i].status = .processing(current: current, total: translatableCount)
                            translatedTexts.append(try await translateWithStreaming(text: t, targetLang: targetLang, service: translationService))
                        }
                    }
                    result = mdParser.assemble(chunks: chunks, translatedTexts: translatedTexts)
                    
                default:
                    tasks[i].status = .processing(current: 0, total: 1)
                    result = try await translateWithStreaming(text: content, targetLang: targetLang, service: translationService)
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
        let langCode = getLangCode(targetLang)
        let fileName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let newName = "\(fileName).\(langCode).\(ext)"
        let outputURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        
        // Conflict handling: if exists, add index
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
    
    private func getLangCode(_ name: String) -> String {
        let mapping = [
            "Chinese (Simplified)": "zh",
            "Chinese (Traditional)": "zh-tw",
            "English": "en",
            "Japanese (Japan)": "ja",
            "Korean (South Korea)": "ko",
            "French (France)": "fr",
            "German (Germany)": "de",
            "Spanish (Mexico)": "es",
            "Russian (Russia)": "ru"
        ]
        return mapping[name] ?? name.prefix(2).lowercased()
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

