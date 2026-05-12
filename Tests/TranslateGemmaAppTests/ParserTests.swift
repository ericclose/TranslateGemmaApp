import XCTest
@testable import TranslateGemmaKit

final class ParserTests: XCTestCase {
    
    // MARK: - Basic Tests
    
    func testMarkdownParser() {
        let parser = MarkdownParser()
        let markdown = "# Hello\nThis is **bold** and *italic*."
        let chunks = parser.parseForTranslation(content: markdown)
        XCTAssertFalse(chunks.isEmpty)
    }
    
    func testSubtitleParserSRT() {
        let parser = SRTParser()
        let srt = """
        1
        00:00:01,000 --> 00:00:04,000
        Hello world!
        
        2
        00:00:05,000 --> 00:00:08,000
        Goodbye world!
        """
        
        let segments = parser.parse(content: srt)
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].text, "Hello world!")
        XCTAssertEqual(segments[1].text, "Goodbye world!")
    }
    
    // MARK: - Edge Cases: Huge Text
    
    func testMarkdownHugeText() {
        let parser = MarkdownParser()
        let line = "This is a repeated line of text for testing huge files.\n"
        let repeatCount = 20000 // Creates ~1.2MB of text
        let hugeMarkdown = String(repeating: line, count: repeatCount)
        
        let startTime = Date()
        let chunks = parser.parseForTranslation(content: hugeMarkdown)
        let duration = Date().timeIntervalSince(startTime)
        
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertTrue(duration < 1.0, "Parsing 1MB+ markdown took too long: \(duration)s")
        print("Huge Markdown Parsing took: \(duration)s")
    }
    
    // MARK: - Edge Cases: Corrupted Subtitles
    
    func testSRTCorruptedIndex() {
        let parser = SRTParser()
        let corruptedSrt = """
        NOT_AN_INDEX
        00:00:01,000 --> 00:00:04,000
        Hello world!
        """
        
        let segments = parser.parse(content: corruptedSrt)
        XCTAssertTrue(segments.isEmpty, "Should not parse corrupted index as valid segment")
    }
    
    func testSRTInvalidTimestamps() {
        let parser = SRTParser()
        let corruptedSrt = """
        1
        INVALID_TIME_FORMAT
        Hello world!
        """
        
        let segments = parser.parse(content: corruptedSrt)
        XCTAssertTrue(segments.isEmpty, "Should not parse invalid timestamps")
    }
    
    func testSRTMissingEmptyLines() {
        let parser = SRTParser()
        let messySrt = """
        1
        00:00:01,000 --> 00:00:04,000
        Line 1
        2
        00:00:05,000 --> 00:00:08,000
        Line 2
        """
        
        let segments = parser.parse(content: messySrt)
        XCTAssertEqual(segments.count, 2, "Messy SRT without empty lines should still parse both segments")
    }
    
    func testVTTCorruptedHeader() {
        let parser = VTTParser()
        let noHeaderVtt = """
        00:00:01.000 --> 00:00:04.000
        Hello world!
        """
        
        let segments = parser.parse(content: noHeaderVtt)
        XCTAssertTrue(segments.isEmpty, "VTT without WEBVTT header should be rejected")
    }
}
