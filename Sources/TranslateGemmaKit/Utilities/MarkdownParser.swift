import Foundation

enum MarkdownChunk {
    case text(String, [String: String])
    case code(String)
    case syntax(String) // Headers, lists, blockquote markers, thematic breaks, tables, HTML, YAML, etc.
}

class MarkdownParser {
    func parseForTranslation(content: String) -> [MarkdownChunk] {
        let lines = content.components(separatedBy: .newlines)
        var chunks: [MarkdownChunk] = []
        
        var inCodeBlock = false
        var codeBlockFence = ""
        var inYamlFrontmatter = false
        var hasSeenFirstLine = false
        
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let suffix = i < lines.count - 1 ? "\n" : ""
            
            // 0. Handle YAML Frontmatter
            if !hasSeenFirstLine && i == 0 && trimmed == "---" {
                inYamlFrontmatter = true
                hasSeenFirstLine = true
                chunks.append(.syntax(line + suffix))
                continue
            }
            hasSeenFirstLine = true
            
            if inYamlFrontmatter {
                chunks.append(.syntax(line + suffix))
                if trimmed == "---" {
                    inYamlFrontmatter = false
                }
                continue
            }
            
            // 1. Handle Fenced Code Blocks
            if !inCodeBlock && (trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~")) {
                inCodeBlock = true
                codeBlockFence = String(trimmed.prefix(3))
                chunks.append(.code(line + suffix))
                continue
            }
            
            if inCodeBlock {
                chunks.append(.code(line + suffix))
                if trimmed.hasPrefix(codeBlockFence) {
                    inCodeBlock = false
                }
                continue
            }
            
            // 2. Handle Indented Code Blocks (approximate GFM)
            if line.hasPrefix("    ") || line.hasPrefix("\t") {
                if !trimmed.isEmpty {
                    if isBlockSyntax(trimmed) {
                        processNormalLine(line, into: &chunks, isLast: i == lines.count - 1)
                    } else {
                        chunks.append(.code(line + suffix))
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
        if trimmed.hasPrefix("#") { return true }
        if let first = trimmed.first, "-*+".contains(first) { return true }
        if trimmed.range(of: #"^\d+\."#, options: .regularExpression) != nil { return true }
        if trimmed.hasPrefix(">") { return true }
        if trimmed.range(of: #"^([-*_])(?:\s*\1){2,}\s*$"#, options: .regularExpression) != nil { return true }
        if trimmed.hasPrefix("|") { return true }
        return false
    }
    
    private func processNormalLine(_ line: String, into chunks: inout [MarkdownChunk], isLast: Bool) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let suffix = isLast ? "" : "\n"
        
        if trimmed.isEmpty {
            chunks.append(.syntax(line + suffix))
            return
        }
        
        // Thematic break
        if trimmed.range(of: #"^([-*_])(?:\s*\1){2,}\s*$"#, options: .regularExpression) != nil {
            chunks.append(.syntax(line + suffix))
            return
        }
        
        // HTML Block approximation (if line starts with HTML tag and closes it, or just treating it simply)
        // Here we just let inline HTML handle it, but if the whole line is an HTML block:
        if trimmed.hasPrefix("<") && trimmed.hasSuffix(">") && trimmed.range(of: #"^<\/?[\w]+[^>]*>$"#, options: .regularExpression) != nil {
            chunks.append(.syntax(line + suffix))
            return
        }
        
        // Table line
        if trimmed.hasPrefix("|") || trimmed.contains("|") {
            // Check if it's an alignment row like |---|---|
            if trimmed.range(of: #"^\|?\s*[:\-]+\s*(?:\|\s*[:\-]+\s*)*\|?$"#, options: .regularExpression) != nil {
                chunks.append(.syntax(line + suffix))
                return
            }
            
            if trimmed.hasPrefix("|") {
                processTableLine(line, into: &chunks)
                chunks.append(.syntax(suffix))
                return
            }
        }
        
        // Handle Block Syntax prefixes
        let leadingLineSpaces = line.prefix(while: { $0 == " " || $0 == "\t" })
        
        if trimmed.hasPrefix("#") {
            let hashPart = trimmed.prefix(while: { $0 == "#" })
            let rest = trimmed.dropFirst(hashPart.count)
            let trailingSpaces = rest.prefix(while: { $0 == " " })
            let prefixStr = String(leadingLineSpaces) + String(hashPart) + String(trailingSpaces)
            chunks.append(.syntax(prefixStr))
            processInlineText(String(rest.dropFirst(trailingSpaces.count)), into: &chunks)
            chunks.append(.syntax(suffix))
        } else if trimmed.hasPrefix(">") {
            let rest = trimmed.dropFirst()
            let trailingSpaces = rest.prefix(while: { $0 == " " })
            let prefixStr = String(leadingLineSpaces) + ">" + String(trailingSpaces)
            chunks.append(.syntax(prefixStr))
            processInlineText(String(rest.dropFirst(trailingSpaces.count)), into: &chunks)
            chunks.append(.syntax(suffix))
        } else if let first = trimmed.first, "-*+".contains(first), trimmed.dropFirst().hasPrefix(" ") {
            let rest = trimmed.dropFirst()
            let trailingSpaces = rest.prefix(while: { $0 == " " })
            let prefixStr = String(leadingLineSpaces) + String(first) + String(trailingSpaces)
            chunks.append(.syntax(prefixStr))
            processInlineText(String(rest.dropFirst(trailingSpaces.count)), into: &chunks)
            chunks.append(.syntax(suffix))
        } else if let range = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
            let markerAndSpaces = String(trimmed[range])
            let prefixStr = String(leadingLineSpaces) + markerAndSpaces
            chunks.append(.syntax(prefixStr))
            processInlineText(String(trimmed[range.upperBound...]), into: &chunks)
            chunks.append(.syntax(suffix))
        } else {
            // Paragraph line
            processInlineText(line, into: &chunks)
            chunks.append(.syntax(suffix))
        }
    }
    
    private func processTableLine(_ line: String, into chunks: inout [MarkdownChunk]) {
        // Split by | but keep them as syntax
        let components = line.components(separatedBy: "|")
        for (i, comp) in components.enumerated() {
            if i > 0 {
                chunks.append(.syntax("|"))
            }
            if !comp.isEmpty {
                // Keep leading/trailing spaces as syntax
                let leadingSpaces = comp.prefix(while: { $0 == " " || $0 == "\t" })
                let trailingSpaces = String(comp.reversed()).prefix(while: { $0 == " " || $0 == "\t" })
                
                if !leadingSpaces.isEmpty {
                    chunks.append(.syntax(String(leadingSpaces)))
                }
                
                let textContent = comp.trimmingCharacters(in: .whitespaces)
                if !textContent.isEmpty {
                    processInlineText(textContent, into: &chunks)
                }
                
                if !trailingSpaces.isEmpty && comp.count > leadingSpaces.count {
                    chunks.append(.syntax(String(trailingSpaces.reversed())))
                }
            }
        }
    }
    
    private func processInlineText(_ text: String, into chunks: inout [MarkdownChunk]) {
        let nsString = text as NSString
        // Regex for inline code, links/images, and HTML tags
        // HTML tag: <[^>]+>
        let inlineRegex = try! NSRegularExpression(pattern: "(`[^`]+`|\\[[^\\]]+\\]\\([^\\)]+\\)|!\\[[^\\]]*\\]\\([^\\)]+\\)|<[^>]+>)", options: [])
        let matches = inlineRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if matches.isEmpty {
            chunks.append(.text(text, [:]))
            return
        }
        
        var currentIdx = 0
        var replacedText = ""
        var placeholders: [String: String] = [:]
        
        for (index, match) in matches.enumerated() {
            let range = match.range
            if range.location > currentIdx {
                replacedText += nsString.substring(with: NSRange(location: currentIdx, length: range.location - currentIdx))
            }
            
            let original = nsString.substring(with: range)
            let ph = "<ph id=\"\(index)\"/>"
            replacedText += ph
            placeholders[ph] = original
            
            currentIdx = range.location + range.length
        }
        
        if currentIdx < nsString.length {
            replacedText += nsString.substring(from: currentIdx)
        }
        
        chunks.append(.text(replacedText, placeholders))
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

