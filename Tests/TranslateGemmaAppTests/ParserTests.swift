import XCTest
@testable import TranslateGemmaKit

final class ParserTests: XCTestCase {
    
    // MARK: - SRT Parser Tests
    
    func testSRTRobustParsing() {
        let parser = SRTParser()
        let srt = """
        1
        00:00:01,000 --> 00:00:02,000 X1:100 Y1:100
        Hello world
        
        2
        00:00:03,000 -> 00:00:04,000
        Line 2
        """
        
        let segments = parser.parse(content: srt)
        XCTAssertEqual(segments.count, 2)
        
        // Check Metadata preservation
        XCTAssertEqual(segments[0].metadata, "X1:100 Y1:100")
        XCTAssertEqual(segments[0].text, "Hello world")
        
        // Check Alternative Separator (->)
        XCTAssertEqual(segments[1].startTime, "00:00:03,000")
        XCTAssertEqual(segments[1].text, "Line 2")
    }
    
    func testSRTWriteBack() {
        let parser = SRTParser()
        let segments = [
            SubtitleParagraph(index: 1, startTime: "00:00:01,000", endTime: "00:00:02,000", text: "Hello", metadata: "X:10")
        ]
        let output = parser.write(paragraphs: segments)
        XCTAssertTrue(output.contains("1"))
        XCTAssertTrue(output.contains("00:00:01,000 --> 00:00:02,000 X:10"))
        XCTAssertTrue(output.contains("Hello"))
    }
    
    // MARK: - VTT Parser Tests
    
    func testVTTWithNotesAndSettings() {
        let parser = VTTParser()
        let vtt = """
        WEBVTT
        
        NOTE
        This is a comment and should be ignored
        
        00:01.000 --> 00:04.000 align:left size:50%
        Hello VTT
        """
        
        let segments = parser.parse(content: vtt)
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].text, "Hello VTT")
        XCTAssertEqual(segments[0].metadata, "align:left size:50%")
    }
    
    // MARK: - ASS Parser Tests
    
    func testASSDynamicFormat() {
        let parser = ASSParser()
        let ass = """
        [Events]
        Format: Layer, Start, End, Style, Actor, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:01.00,0:00:02.00,Default,John,0,0,0,,Hello John
        Comment: 1,0:00:03.00,0:00:04.00,Alt,Jane,10,10,10,Fading,Hidden note
        """
        
        let segments = parser.parse(content: ass)
        XCTAssertEqual(segments.count, 2)
        
        // Verify Dialogue
        XCTAssertEqual(segments[0].text, "Hello John")
        XCTAssertEqual(segments[0].startTime, "0:00:01.00")
        XCTAssertTrue(segments[0].metadata?.contains("Actor=John") ?? false)
        
        // Verify Comment
        XCTAssertEqual(segments[1].text, "Hidden note")
        XCTAssertTrue(segments[1].metadata?.contains("type=comment") ?? false)
        XCTAssertTrue(segments[1].metadata?.contains("Effect=Fading") ?? false)
        
        // Verify Roundtrip
        let output = parser.write(paragraphs: segments)
        XCTAssertTrue(output.contains("Dialogue: 0,0:00:01.00,0:00:02.00,Default,John,0,0,0,,Hello John"))
        XCTAssertTrue(output.contains("Comment: 1,0:00:03.00,0:00:04.00,Alt,Jane,10,10,10,Fading,Hidden note"))
    }
    
    // MARK: - Markdown Parser Tests
    
    func testMarkdownStructurePreservation() {
        let parser = MarkdownParser()
        let markdown = """
        # Header
        > Quote with [Link](http://example.com)
        
        ```swift
        print("Hello")
        ```
        
        - List item with `inline code`
        """
        
        let chunks = parser.parseForTranslation(content: markdown)
        
        // We expect:
        // 1. Syntax (# )
        // 2. Text (Header)
        // 3. Syntax (\n)
        // 4. Syntax (> )
        // 5. Text (Quote with )
        // 6. Code ([Link](http://example.com))
        // 7. Syntax (\n\n)
        // 8. Code (```swift...```)
        // ...
        
        let texts = chunks.compactMap { chunk -> String? in
            if case .text(let t, _) = chunk { return t }
            return nil
        }
        
        XCTAssertTrue(texts.contains("Header"))
        XCTAssertTrue(texts.contains("Quote with "))
        XCTAssertTrue(texts.contains("List item with "))
        
        // Ensure URLs and Code are not in 'text' chunks
        XCTAssertFalse(texts.contains(where: { $0.contains("http://") }))
        XCTAssertFalse(texts.contains(where: { $0.contains("print") }))
        XCTAssertFalse(texts.contains(where: { $0.contains("inline code") }))
    }
    
    func testMarkdownThematicBreak() {
        let parser = MarkdownParser()
        let markdown = "Para 1\n\n---\n\nPara 2"
        let chunks = parser.parseForTranslation(content: markdown)
        
        let hasThematicBreak = chunks.contains { chunk in
            if case .syntax(let s) = chunk { return s.contains("---") }
            return false
        }
        XCTAssertTrue(hasThematicBreak)
    }
    
    func testYAMLFrontmatterPreservation() {
        let parser = MarkdownParser()
        let markdown = """
        ---
        title: Hello
        date: 2023-10-27
        ---
        # Header
        """
        
        let chunks = parser.parseForTranslation(content: markdown)
        
        let texts = chunks.compactMap { chunk -> String? in
            if case .text(let t, _) = chunk { return t }
            return nil
        }
        
        XCTAssertTrue(texts.contains("Header"))
        XCTAssertFalse(texts.contains(where: { $0.contains("title") }))
        XCTAssertFalse(texts.contains(where: { $0.contains("2023") }))
        
        // Ensure reassembled markdown contains exactly the YAML frontmatter
        let reassembled = parser.assemble(chunks: chunks, translatedTexts: texts)
        XCTAssertTrue(reassembled.hasPrefix("---\ntitle: Hello\ndate: 2023-10-27\n---\n"))
    }
    
    func testHTMLTagPreservation() {
        let parser = MarkdownParser()
        let markdown = "Press <kbd>Ctrl</kbd> + <kbd>C</kbd> to copy. <br/>"
        
        let chunks = parser.parseForTranslation(content: markdown)
        
        let texts = chunks.compactMap { chunk -> String? in
            if case .text(let t, _) = chunk { return t }
            return nil
        }
        
        XCTAssertTrue(texts.contains("Press "))
        XCTAssertTrue(texts.contains("Ctrl"))
        XCTAssertTrue(texts.contains(" + "))
        XCTAssertTrue(texts.contains("C"))
        XCTAssertTrue(texts.contains(" to copy. "))
        
        let syntaxChunks = chunks.compactMap { chunk -> String? in
            if case .syntax(let s) = chunk { return s }
            return nil
        }
        
        XCTAssertTrue(syntaxChunks.contains("<kbd>"))
        XCTAssertTrue(syntaxChunks.contains("</kbd>"))
        XCTAssertTrue(syntaxChunks.contains("<br/>"))
    }
    
    func testTablePreservation() {
        let parser = MarkdownParser()
        let markdown = """
        | Header 1 | Header 2 |
        | :--- | :---: |
        | Row 1 | Row 2 |
        """
        
        let chunks = parser.parseForTranslation(content: markdown)
        
        let texts = chunks.compactMap { chunk -> String? in
            if case .text(let t, _) = chunk { return t }
            return nil
        }
        
        XCTAssertTrue(texts.contains("Header 1"))
        XCTAssertTrue(texts.contains("Header 2"))
        XCTAssertTrue(texts.contains("Row 1"))
        XCTAssertTrue(texts.contains("Row 2"))
        
        // Make sure syntax formatting like alignment row is not translated
        XCTAssertFalse(texts.contains(where: { $0.contains(":---") }))
        
        let reassembled = parser.assemble(chunks: chunks, translatedTexts: ["Header 1 Trans", "Header 2 Trans", "Row 1 Trans", "Row 2 Trans"])
        let expected = """
        | Header 1 Trans | Header 2 Trans |
        | :--- | :---: |
        | Row 1 Trans | Row 2 Trans |
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(reassembled, expected)
    }
    
    // MARK: - Performance Tests
    
    func testParserPerformance() {
        let parser = MarkdownParser()
        let largeMD = String(repeating: "This is a sentence that needs translation. [Link](url) `code`\n", count: 1000)
        
        measure {
            _ = parser.parseForTranslation(content: largeMD)
        }
    }
}

