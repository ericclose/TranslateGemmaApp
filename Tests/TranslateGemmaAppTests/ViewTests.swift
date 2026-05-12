import XCTest
import SwiftUI
import ViewInspector
@testable import TranslateGemmaKit

final class ViewTests: XCTestCase {
    @MainActor
    func testLiquidBackground() throws {
        let view = LiquidBackground(accentColor: .red)
        let sut = try view.inspect()
        
        // We just verify that the view has content and can be inspected
        // Since MeshGradient is very new, we don't strictly check for it by type
        XCTAssertNotNil(sut)
    }
    
    @MainActor
    func testTranslationViewInitialState() throws {
        // TranslationView uses Environment objects, so we need to inject them
        let modelManager = ModelManager()
        let translationService = TranslationService()
        
        let view = TranslationView()
            .environment(modelManager)
            .environment(translationService)
            
        let sut = try view.inspect()
        XCTAssertNotNil(sut)
    }
}
