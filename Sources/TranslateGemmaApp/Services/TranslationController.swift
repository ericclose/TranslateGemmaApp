import Foundation

class TranslationController {
    let srtParser = SRTParser()
    let vttParser = VTTParser()
    let assParser = ASSParser()
    let mdParser = MarkdownParser()
    
    func processFile(url: URL, targetLang: String, translator: (String) async throws -> String) async throws -> String {
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
}
