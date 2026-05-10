import Foundation

enum MarkdownChunk {
    case text(String)
    case code(String)
    case syntax(String) // Headers, lists, etc.
}

class MarkdownParser {
    func parseForTranslation(content: String) -> [MarkdownChunk] {
        // Simple regex-based approach for demonstration
        // Better: Use a real MD parser, but here we'll skip code blocks and inline code
        var chunks: [MarkdownChunk] = []
        let codeBlockRegex = try! NSRegularExpression(pattern: "```[\\s\\S]*?```", options: [])
        
        let nsString = content as NSString
        
        // Find code blocks
        let codeBlockMatches = codeBlockRegex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var currentIdx = 0
        for match in codeBlockMatches {
            let range = match.range
            if range.location > currentIdx {
                let textPart = nsString.substring(with: NSRange(location: currentIdx, length: range.location - currentIdx))
                processTextPart(textPart, into: &chunks)
            }
            chunks.append(.code(nsString.substring(with: range)))
            currentIdx = range.location + range.length
        }
        
        if currentIdx < nsString.length {
            let textPart = nsString.substring(from: currentIdx)
            processTextPart(textPart, into: &chunks)
        }
        
        return chunks
    }
    
    private func processTextPart(_ text: String, into chunks: inout [MarkdownChunk]) {
        let nsString = text as NSString
        let inlineCodeRegex = try! NSRegularExpression(pattern: "`[^`]+`", options: [])
        let matches = inlineCodeRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var currentIdx = 0
        for match in matches {
            let range = match.range
            if range.location > currentIdx {
                let rawText = nsString.substring(with: NSRange(location: currentIdx, length: range.location - currentIdx))
                chunks.append(.text(rawText))
            }
            chunks.append(.code(nsString.substring(with: range)))
            currentIdx = range.location + range.length
        }
        
        if currentIdx < nsString.length {
            chunks.append(.text(nsString.substring(from: currentIdx)))
        }
    }
    
    func assemble(chunks: [MarkdownChunk], translatedTexts: [String]) -> String {
        var output = ""
        var textIdx = 0
        for chunk in chunks {
            switch chunk {
            case .text:
                if textIdx < translatedTexts.count {
                    output += translatedTexts[textIdx]
                    textIdx += 1
                }
            case .code(let code):
                output += code
            case .syntax(let syn):
                output += syn
            }
        }
        return output
    }
}
