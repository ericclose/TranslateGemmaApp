import Foundation

struct SubtitleParagraph: Identifiable {
    let id = UUID()
    var index: Int
    var startTime: String
    var endTime: String
    var text: String
    var metadata: String?
}

protocol SubtitleParser {
    func parse(content: String) -> [SubtitleParagraph]
    func write(paragraphs: [SubtitleParagraph]) -> String
}

class SRTParser: SubtitleParser {
    func parse(content: String) -> [SubtitleParagraph] {
        let lines = content.components(separatedBy: .newlines)
        var paragraphs: [SubtitleParagraph] = []
        var currentIndex = 0
        var currentTimes = ""
        var currentText: [String] = []
        
        enum State { case index, times, text }
        var state: State = .index
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !currentText.isEmpty {
                    paragraphs.append(SubtitleParagraph(index: currentIndex, startTime: String(currentTimes.split(separator: " --> ").first ?? ""), endTime: String(currentTimes.split(separator: " --> ").last ?? ""), text: currentText.joined(separator: "\n")))
                    currentText = []
                    state = .index
                }
                continue
            }
            
            switch state {
            case .index:
                if let idx = Int(trimmed) {
                    currentIndex = idx
                    state = .times
                }
            case .times:
                if trimmed.contains(" --> ") {
                    currentTimes = trimmed
                    state = .text
                }
            case .text:
                currentText.append(line)
            }
        }
        
        if !currentText.isEmpty {
            paragraphs.append(SubtitleParagraph(index: currentIndex, startTime: String(currentTimes.split(separator: " --> ").first ?? ""), endTime: String(currentTimes.split(separator: " --> ").last ?? ""), text: currentText.joined(separator: "\n")))
        }
        
        return paragraphs
    }
    
    func write(paragraphs: [SubtitleParagraph]) -> String {
        var output = ""
        for p in paragraphs {
            output += "\(p.index)\n"
            output += "\(p.startTime) --> \(p.endTime)\n"
            output += "\(p.text)\n\n"
        }
        return output
    }
}

class VTTParser: SubtitleParser {
    func parse(content: String) -> [SubtitleParagraph] {
        let lines = content.components(separatedBy: .newlines)
        var paragraphs: [SubtitleParagraph] = []
        var currentTimes = ""
        var currentText: [String] = []
        
        var state: Int = 0 // 0: header, 1: looking for times, 2: text
        
        for (i, line) in lines.enumerated() {
            if i == 0 && line.starts(with: "WEBVTT") {
                state = 1
                continue
            }
            
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !currentText.isEmpty {
                    let parts = currentTimes.split(separator: " --> ")
                    paragraphs.append(SubtitleParagraph(index: paragraphs.count + 1, startTime: String(parts.first ?? ""), endTime: String(parts.last ?? ""), text: currentText.joined(separator: "\n")))
                    currentText = []
                    state = 1
                }
                continue
            }
            
            if line.contains(" --> ") {
                currentTimes = line
                state = 2
                continue
            }
            
            if state == 2 {
                currentText.append(line)
            }
        }
        
        if !currentText.isEmpty {
             let parts = currentTimes.split(separator: " --> ")
             paragraphs.append(SubtitleParagraph(index: paragraphs.count + 1, startTime: String(parts.first ?? ""), endTime: String(parts.last ?? ""), text: currentText.joined(separator: "\n")))
        }
        
        return paragraphs
    }
    
    func write(paragraphs: [SubtitleParagraph]) -> String {
        var output = "WEBVTT\n\n"
        for p in paragraphs {
            output += "\(p.startTime) --> \(p.endTime)\n"
            output += "\(p.text)\n\n"
        }
        return output
    }
}

class ASSParser: SubtitleParser {
    var header: String = ""
    
    func parse(content: String) -> [SubtitleParagraph] {
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
    
    func write(paragraphs: [SubtitleParagraph]) -> String {
        var output = header + "\n"
        for p in paragraphs {
            // Re-assemble Dialogue line
            // Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Text
            output += "Dialogue: 0,\(p.startTime),\(p.endTime),Default,,0,0,0,,\(p.text)\n"
        }
        return output
    }
}
