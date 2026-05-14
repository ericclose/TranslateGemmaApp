import Foundation

enum MarkdownChunk {
    case text(String)
    case code(String)
    case syntax(String) // Headers, lists, blockquote markers, thematic breaks, etc.
}

class MarkdownParser {
    func parseForTranslation(content: String) -> [MarkdownChunk] {
        let lines = content.components(separatedBy: .newlines)
        var chunks: [MarkdownChunk] = []
        
        var inCodeBlock = false
        var codeBlockFence = ""
        
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 1. Handle Fenced Code Blocks
            if !inCodeBlock && (trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~")) {
                inCodeBlock = true
                codeBlockFence = String(trimmed.prefix(3))
                chunks.append(.code(line + (i < lines.count - 1 ? "\n" : "")))
                continue
            }
            
            if inCodeBlock {
                chunks.append(.code(line + (i < lines.count - 1 ? "\n" : "")))
                if trimmed.hasPrefix(codeBlockFence) {
                    inCodeBlock = false
                }
                continue
            }
            
            // 2. Handle Indented Code Blocks (approximate GFM)
            if line.hasPrefix("    ") || line.hasPrefix("\t") {
                // Heuristic: check if previous line was blank or another code line
                // For simplicity, we'll treat lines starting with 4 spaces as code if they aren't obviously something else
                if !trimmed.isEmpty {
                    // Check if it's a list item or other block first
                    if isBlockSyntax(trimmed) {
                        processNormalLine(line, into: &chunks, isLast: i == lines.count - 1)
                    } else {
                        chunks.append(.code(line + (i < lines.count - 1 ? "\n" : "")))
                    }
                } else {
                    chunks.append(.syntax("\n"))
                }
                continue
            }
            
            // 3. Handle Normal Blocks
            processNormalLine(line, into: &chunks, isLast: i == lines.count - 1)
        }
        
        return chunks
    }
    
    private func isBlockSyntax(_ trimmed: String) -> Bool {
        // Headers
        if trimmed.hasPrefix("#") { return true }
        // Lists
        if let first = trimmed.first, "-*+".contains(first) { return true }
        if trimmed.range(of: #"^\d+\."#, options: .regularExpression) != nil { return true }
        // Blockquotes
        if trimmed.hasPrefix(">") { return true }
        // Thematic breaks
        if trimmed.range(of: #"^([-*_])\s*\1\s*\1"#, options: .regularExpression) != nil { return true }
        
        return false
    }
    
    private func processNormalLine(_ line: String, into chunks: inout [MarkdownChunk], isLast: Bool) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let suffix = isLast ? "" : "\n"
        
        if trimmed.isEmpty {
            chunks.append(.syntax(line + suffix))
            return
        }
        
        // Handle Block Syntax prefixes
        if trimmed.hasPrefix("#") {
            let hashPart = trimmed.prefix(while: { $0 == "#" })
            let rest = trimmed.dropFirst(hashPart.count)
            let leadingSpaces = rest.prefix(while: { $0 == " " })
            chunks.append(.syntax(String(hashPart) + String(leadingSpaces)))
            processInlineText(String(rest.dropFirst(leadingSpaces.count)), into: &chunks)
            chunks.append(.syntax(suffix))
        } else if trimmed.hasPrefix(">") {
            let rest = trimmed.dropFirst()
            let leadingSpaces = rest.prefix(while: { $0 == " " })
            chunks.append(.syntax(">" + String(leadingSpaces)))
            processInlineText(String(rest.dropFirst(leadingSpaces.count)), into: &chunks)
            chunks.append(.syntax(suffix))
        } else if let first = trimmed.first, "-*+".contains(first), trimmed.dropFirst().hasPrefix(" ") {
            let rest = trimmed.dropFirst()
            let leadingSpaces = rest.prefix(while: { $0 == " " })
            chunks.append(.syntax(String(first) + String(leadingSpaces)))
            processInlineText(String(rest.dropFirst(leadingSpaces.count)), into: &chunks)
            chunks.append(.syntax(suffix))
        } else if let range = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
            let marker = String(trimmed[range])
            chunks.append(.syntax(marker))
            processInlineText(String(trimmed[range.upperBound...]), into: &chunks)
            chunks.append(.syntax(suffix))
        } else if trimmed.range(of: #"^([-*_])\s*\1\s*\1"#, options: .regularExpression) != nil {
            // Thematic break
            chunks.append(.syntax(line + suffix))
        } else {
            // Paragraph line
            processInlineText(line, into: &chunks)
            chunks.append(.syntax(suffix))
        }
    }
    
    private func processInlineText(_ text: String, into chunks: inout [MarkdownChunk]) {
        let nsString = text as NSString
        // Regex for inline code and links/images (to preserve tags)
        let inlineRegex = try! NSRegularExpression(pattern: "(`[^`]+`|\\[[^\\]]+\\]\\([^\\)]+\\)|!\\[[^\\]]*\\]\\([^\\)]+\\))", options: [])
        let matches = inlineRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var currentIdx = 0
        for match in matches {
            let range = match.range
            if range.location > currentIdx {
                let rawText = nsString.substring(with: NSRange(location: currentIdx, length: range.location - currentIdx))
                chunks.append(.text(rawText))
            }
            chunks.append(.code(nsString.substring(with: range))) // Treat as code to preserve
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

