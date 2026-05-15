import Foundation

public struct TextChunk {
    public let text: String
    public let separator: String
}

public class TextSplitter {
    public static func split(text: String, maxChunkLength: Int = 1000) -> [TextChunk] {
        if text.count <= maxChunkLength {
            return [TextChunk(text: text, separator: "")]
        }
        
        var chunks: [TextChunk] = []
        let pattern = "(?s)(.*?)(?:(\\n\\n+|\\n|[.!?。！？]+\\s*)|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [TextChunk(text: text, separator: "")]
        }
        
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var currentText = ""
        var currentSeparator = ""
        
        for match in matches {
            let partText = nsString.substring(with: match.range(at: 1))
            let partSeparator = match.range(at: 2).location != NSNotFound ? nsString.substring(with: match.range(at: 2)) : ""
            
            if partText.isEmpty && partSeparator.isEmpty { continue }
            
            let combined = partText + partSeparator
            
            if currentText.count + combined.count > maxChunkLength && !currentText.isEmpty {
                chunks.append(TextChunk(text: currentText, separator: currentSeparator))
                currentText = partText
                currentSeparator = partSeparator
            } else {
                currentText += currentSeparator + partText
                currentSeparator = partSeparator
            }
        }
        
        if !currentText.isEmpty {
            chunks.append(TextChunk(text: currentText, separator: currentSeparator))
        }
        
        return chunks
    }
}
