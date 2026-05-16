import SwiftUI

public struct PlainTextTranslationView: View {
    @Binding var inputText: String
    @Binding var outputText: String
    @Binding var isHoveringSource: Bool
    @Binding var isHoveringTarget: Bool
    let geometry: GeometryProxy
    let currentAccentColor: Color
    let sourceActions: AnyView
    let targetActions: AnyView
    
    public init(
        inputText: Binding<String>,
        outputText: Binding<String>,
        isHoveringSource: Binding<Bool>,
        isHoveringTarget: Binding<Bool>,
        geometry: GeometryProxy,
        currentAccentColor: Color,
        sourceActions: AnyView,
        targetActions: AnyView
    ) {
        self._inputText = inputText
        self._outputText = outputText
        self._isHoveringSource = isHoveringSource
        self._isHoveringTarget = isHoveringTarget
        self.geometry = geometry
        self.currentAccentColor = currentAccentColor
        self.sourceActions = sourceActions
        self.targetActions = targetActions
    }
    
    public var body: some View {
        HStack(spacing: 24) {
            TranslationCard(
                title: { sourceActions },
                text: $inputText,
                isReadOnly: false,
                placeholder: "Type or drop text here...",
                containerWidth: geometry.size.width,
                isHovered: isHoveringSource,
                actions: { EmptyView() }
            )
            .onHover { isHoveringSource = $0 }
            
            TranslationCard(
                title: { EmptyView() },
                text: .constant(outputText),
                isReadOnly: true,
                placeholder: "Translation will appear here",
                textColor: currentAccentColor,
                containerWidth: geometry.size.width,
                isHovered: isHoveringTarget,
                actions: { targetActions }
            )
            .onHover { isHoveringTarget = $0 }
        }
        .frame(maxWidth: min(geometry.size.width - 64, 1600))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}
