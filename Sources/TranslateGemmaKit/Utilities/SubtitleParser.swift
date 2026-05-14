import Foundation

public struct SubtitleParagraph: Identifiable {
    public let id = UUID()
    public var index: Int
    public var startTime: String
    public var endTime: String
    public var text: String
    public var metadata: String? // Position info, region, etc.
    
    public init(index: Int, startTime: String, endTime: String, text: String, metadata: String? = nil) {
        self.index = index
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.metadata = metadata
    }
}

public protocol SubtitleParser {
    func parse(content: String) -> [SubtitleParagraph]
    func write(paragraphs: [SubtitleParagraph]) -> String
}

// MARK: - SRT Parser

public class SRTParser: SubtitleParser {
    public init() {}
    
    private let timecodeRegex = try! NSRegularExpression(pattern: #"(\d{1,2}:\d{2}:\d{2}[.,]\d{3})\s*[-—=]+>+\s*(\d{1,2}:\d{2}:\d{2}[.,]\d{3})(.*)"#, options: [])

    public func parse(content: String) -> [SubtitleParagraph] {
        let lines = content.components(separatedBy: .newlines)
        var paragraphs: [SubtitleParagraph] = []
        var currentIndex = 0
        var currentTimes: (start: String, end: String, meta: String?)?
        var currentText: [String] = []
        
        func flush() {
            if let times = currentTimes, !currentText.isEmpty {
                paragraphs.append(SubtitleParagraph(
                    index: currentIndex,
                    startTime: times.start,
                    endTime: times.end,
                    text: currentText.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                    metadata: times.meta
                ))
            }
            currentText = []
            currentTimes = nil
        }
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                flush()
                continue
            }
            
            let nsLine = line as NSString
            if let match = timecodeRegex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: nsLine.length)) {
                if !currentText.isEmpty || currentTimes != nil { flush() }
                
                let start = nsLine.substring(with: match.range(at: 1))
                let end = nsLine.substring(with: match.range(at: 2))
                let meta = nsLine.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)
                currentTimes = (start, end, meta.isEmpty ? nil : meta)
                continue
            }
            
            if currentTimes == nil {
                if let idx = Int(trimmed) {
                    currentIndex = idx
                } else if !currentText.isEmpty {
                    currentText.append(line)
                }
            } else {
                currentText.append(line)
            }
        }
        
        flush()
        return paragraphs
    }
    
    public func write(paragraphs: [SubtitleParagraph]) -> String {
        var output = ""
        for (i, p) in paragraphs.enumerated() {
            output += "\(p.index != 0 ? p.index : i + 1)\n"
            output += "\(p.startTime) --> \(p.endTime)\(p.metadata != nil ? " " + p.metadata! : "")\n"
            output += "\(p.text)\n\n"
        }
        return output
    }
}

// MARK: - VTT Parser

public class VTTParser: SubtitleParser {
    public init() {}
    
    private let timecodeRegex = try! NSRegularExpression(pattern: #"((?:\d+:)?\d{2}:\d{2}\.\d{3})\s*-->\s*((?:\d+:)?\d{2}:\d{2}\.\d{3})(.*)"#, options: [])

    public func parse(content: String) -> [SubtitleParagraph] {
        let lines = content.components(separatedBy: .newlines)
        var paragraphs: [SubtitleParagraph] = []
        var currentTimes: (start: String, end: String, meta: String?)?
        var currentText: [String] = []
        var headerFound = false
        var inNote = false
        
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if i == 0 && trimmed.hasPrefix("WEBVTT") {
                headerFound = true
                continue
            }
            
            if !headerFound { continue }
            
            if trimmed.isEmpty {
                if inNote { inNote = false; continue }
                if let times = currentTimes, !currentText.isEmpty {
                    paragraphs.append(SubtitleParagraph(
                        index: paragraphs.count + 1,
                        startTime: times.start,
                        endTime: times.end,
                        text: currentText.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                        metadata: times.meta
                    ))
                    currentTimes = nil
                    currentText = []
                }
                continue
            }
            
            if trimmed.hasPrefix("NOTE") {
                inNote = true
                continue
            }
            if inNote { continue }

            let nsLine = line as NSString
            if let match = timecodeRegex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: nsLine.length)) {
                if !currentText.isEmpty || currentTimes != nil {
                    // Flush previous
                    if let times = currentTimes, !currentText.isEmpty {
                        paragraphs.append(SubtitleParagraph(
                            index: paragraphs.count + 1,
                            startTime: times.start,
                            endTime: times.end,
                            text: currentText.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                            metadata: times.meta
                        ))
                    }
                }
                
                let start = nsLine.substring(with: match.range(at: 1))
                let end = nsLine.substring(with: match.range(at: 2))
                let meta = nsLine.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)
                currentTimes = (start, end, meta.isEmpty ? nil : meta)
                currentText = []
                continue
            }
            
            if currentTimes != nil {
                currentText.append(line)
            }
        }
        
        // Final flush
        if let times = currentTimes, !currentText.isEmpty {
            paragraphs.append(SubtitleParagraph(
                index: paragraphs.count + 1,
                startTime: times.start,
                endTime: times.end,
                text: currentText.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                metadata: times.meta
            ))
        }
        
        return paragraphs
    }
    
    public func write(paragraphs: [SubtitleParagraph]) -> String {
        var output = "WEBVTT\n\n"
        for p in paragraphs {
            output += "\(p.startTime) --> \(p.endTime)\(p.metadata != nil ? " " + p.metadata! : "")\n"
            output += "\(p.text)\n\n"
        }
        return output
    }
}

// MARK: - ASS Parser

public class ASSParser: SubtitleParser {
    public var header: String = ""
    public var formatFields: [String] = []
    
    public init() {}
    
    public func parse(content: String) -> [SubtitleParagraph] {
        let lines = content.components(separatedBy: .newlines)
        var paragraphs: [SubtitleParagraph] = []
        var eventsStarted = false
        var headerLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.starts(with: "[Events]") {
                eventsStarted = true
                headerLines.append(line)
                continue
            }
            
            if !eventsStarted {
                headerLines.append(line)
                continue
            }
            
            if trimmed.starts(with: "Format:") {
                let formatLine = trimmed.replacingOccurrences(of: "Format:", with: "").trimmingCharacters(in: .whitespaces)
                formatFields = formatLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                headerLines.append(line)
                continue
            }
            
            if trimmed.starts(with: "Dialogue:") || trimmed.starts(with: "Comment:") {
                let isComment = trimmed.starts(with: "Comment:")
                let prefix = isComment ? "Comment:" : "Dialogue:"
                let rawData = trimmed.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespaces)
                
                // Comma separated, but the last field (Text) can contain commas
                let parts = rawData.components(separatedBy: ",")
                if parts.count >= formatFields.count {
                    let fieldCount = formatFields.count
                    
                    var startTime = ""
                    var endTime = ""
                    var text = ""
                    var metadataParts: [String] = []
                    
                    for (idx, fieldName) in formatFields.enumerated() {
                        let value: String
                        if idx == fieldCount - 1 {
                            // Text is always the last field, join remaining parts
                            value = parts[idx...].joined(separator: ",")
                        } else {
                            value = parts[idx]
                        }
                        
                        switch fieldName.lowercased() {
                        case "start": startTime = value
                        case "end": endTime = value
                        case "text": text = value
                        default:
                            metadataParts.append("\(fieldName)=\(value)")
                        }
                    }
                    
                    var p = SubtitleParagraph(index: paragraphs.count + 1, startTime: startTime, endTime: endTime, text: text)
                    if isComment {
                        p.metadata = "type=comment;" + metadataParts.joined(separator: ";")
                    } else {
                        p.metadata = metadataParts.joined(separator: ";")
                    }
                    paragraphs.append(p)
                }
            } else {
                // Unknown event line, preserve it in header if it's before any dialogue? 
                // Or just ignore if it's within events.
            }
        }
        
        self.header = headerLines.joined(separator: "\n")
        return paragraphs
    }
    
    public func write(paragraphs: [SubtitleParagraph]) -> String {
        var output = header + "\n"
        
        for p in paragraphs {
            let isComment = p.metadata?.contains("type=comment") ?? false
            let type = isComment ? "Comment: " : "Dialogue: "
            
            var values: [String] = []
            let metaDict = parseMetadata(p.metadata)
            
            for field in formatFields {
                switch field.lowercased() {
                case "start": values.append(p.startTime)
                case "end": values.append(p.endTime)
                case "text": values.append(p.text)
                default:
                    values.append(metaDict[field] ?? "0")
                }
            }
            
            output += type + values.joined(separator: ",") + "\n"
        }
        
        return output
    }
    
    private func parseMetadata(_ metadata: String?) -> [String: String] {
        var dict: [String: String] = [:]
        guard let metadata = metadata else { return dict }
        let components = metadata.components(separatedBy: ";")
        for comp in components {
            let parts = comp.components(separatedBy: "=")
            if parts.count == 2 {
                dict[parts[0]] = parts[1]
            }
        }
        return dict
    }
}

