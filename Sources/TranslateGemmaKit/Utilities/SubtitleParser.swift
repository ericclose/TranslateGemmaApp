import Foundation

public struct SubtitleParagraph: Identifiable {
    public let id = UUID()
    public var index: Int
    public var startTime: String
    public var endTime: String
    public var text: String
    public var metadata: String?
    
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

public class SRTParser: SubtitleParser {
    public init() {}
    
    public func parse(content: String) -> [SubtitleParagraph] {
        let lines = content.components(separatedBy: .newlines)
        var paragraphs: [SubtitleParagraph] = []
        var currentIndex = 0
        var currentTimes = ""
        var currentText: [String] = []
        
        enum State { case index, times, text }
        var state: State = .index
        
        func flush() {
            if !currentText.isEmpty && !currentTimes.isEmpty {
                let times = currentTimes.components(separatedBy: " --> ")
                paragraphs.append(SubtitleParagraph(
                    index: currentIndex,
                    startTime: times.first?.trimmingCharacters(in: .whitespaces) ?? "",
                    endTime: times.last?.trimmingCharacters(in: .whitespaces) ?? "",
                    text: currentText.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                ))
            }
            currentText = []
            currentTimes = ""
        }
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                flush()
                state = .index
                continue
            }
            
            switch state {
            case .index:
                if let idx = Int(trimmed) {
                    // If we were already in text state and see a new index without an empty line
                    if !currentText.isEmpty { flush() }
                    currentIndex = idx
                    state = .times
                } else if !currentText.isEmpty {
                    // Probably continued text
                    currentText.append(line)
                }
            case .times:
                if trimmed.contains(" --> ") {
                    currentTimes = trimmed
                    state = .text
                } else {
                    // Invalid format, reset
                    state = .index
                }
            case .text:
                // Check if this line looks like a new index (heuristic for messy files)
                if let _ = Int(trimmed), line == trimmed {
                    flush()
                    currentIndex = Int(trimmed)!
                    state = .times
                } else {
                    currentText.append(line)
                }
            }
        }
        
        flush()
        return paragraphs
    }
    
    public func write(paragraphs: [SubtitleParagraph]) -> String {
        var output = ""
        for p in paragraphs {
            output += "\(p.index)\n"
            output += "\(p.startTime) --> \(p.endTime)\n"
            output += "\(p.text)\n\n"
        }
        return output
    }
}

public class VTTParser: SubtitleParser {
    public init() {}
    
    public func parse(content: String) -> [SubtitleParagraph] {
        let lines = content.components(separatedBy: .newlines)
        var paragraphs: [SubtitleParagraph] = []
        var currentTimes = ""
        var currentText: [String] = []
        
        var headerFound = false
        var state: Int = 0 // 0: looking for times, 1: text
        
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if i == 0 {
                if line.hasPrefix("WEBVTT") {
                    headerFound = true
                    continue
                } else {
                    return [] // Strict VTT check
                }
            }
            
            if !headerFound { return [] }
            
            if trimmed.isEmpty {
                if !currentText.isEmpty {
                    let parts = currentTimes.components(separatedBy: " --> ")
                    paragraphs.append(SubtitleParagraph(
                        index: paragraphs.count + 1,
                        startTime: parts.first?.trimmingCharacters(in: .whitespaces) ?? "",
                        endTime: parts.last?.trimmingCharacters(in: .whitespaces) ?? "",
                        text: currentText.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                    currentText = []
                    state = 0
                }
                continue
            }
            
            if line.contains(" --> ") {
                currentTimes = line
                state = 1
                continue
            }
            
            if state == 1 {
                currentText.append(line)
            }
        }
        
        if !currentText.isEmpty && !currentTimes.isEmpty {
             let parts = currentTimes.components(separatedBy: " --> ")
             paragraphs.append(SubtitleParagraph(
                index: paragraphs.count + 1,
                startTime: parts.first?.trimmingCharacters(in: .whitespaces) ?? "",
                endTime: parts.last?.trimmingCharacters(in: .whitespaces) ?? "",
                text: currentText.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
             ))
        }
        
        return paragraphs
    }
    
    public func write(paragraphs: [SubtitleParagraph]) -> String {
        var output = "WEBVTT\n\n"
        for p in paragraphs {
            output += "\(p.startTime) --> \(p.endTime)\n"
            output += "\(p.text)\n\n"
        }
        return output
    }
}

public class ASSParser: SubtitleParser {
    public var header: String = ""
    public init() {}
    
    public func parse(content: String) -> [SubtitleParagraph] {
        let lines = content.components(separatedBy: .newlines)
        var paragraphs: [SubtitleParagraph] = []
        var eventsStarted = false
        var headerLines: [String] = []
        
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).starts(with: "[Events]") {
                eventsStarted = true
                headerLines.append(line)
                continue
            }
            
            if !eventsStarted {
                headerLines.append(line)
                continue
            }
            
            if line.starts(with: "Dialogue:") {
                let parts = line.components(separatedBy: ",")
                if parts.count >= 10 {
                    let startTime = parts[1]
                    let endTime = parts[2]
                    let text = parts[9...].joined(separator: ",")
                    paragraphs.append(SubtitleParagraph(index: paragraphs.count + 1, startTime: startTime, endTime: endTime, text: text))
                }
            } else if line.starts(with: "Format:") {
                headerLines.append(line)
            }
        }
        
        self.header = headerLines.joined(separator: "\n")
        return paragraphs
    }
    
    public func write(paragraphs: [SubtitleParagraph]) -> String {
        var output = header + "\n"
        for p in paragraphs {
            output += "Dialogue: 0,\(p.startTime),\(p.endTime),Default,,0,0,0,,\(p.text)\n"
        }
        return output
    }
}
