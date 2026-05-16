import SwiftUI

public struct ModeSwitcher: View {
    @Binding var selectedMode: TranslationMode
    let accentColor: Color
    @Namespace private var modeNamespace
    
    public init(selectedMode: Binding<TranslationMode>, accentColor: Color) {
        self._selectedMode = selectedMode
        self.accentColor = accentColor
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            ForEach(TranslationMode.allCases, id: \.self) { mode in
                Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedMode = mode } }) {
                    Text(mode.rawValue)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                if selectedMode == mode {
                                    Capsule()
                                        .fill(accentColor)
                                        .matchedGeometryEffect(id: "mode", in: modeNamespace)
                                }
                            }
                        )
                        .foregroundColor(selectedMode == mode ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
    }
}
