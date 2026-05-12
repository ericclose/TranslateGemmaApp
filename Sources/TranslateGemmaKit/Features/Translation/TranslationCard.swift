import SwiftUI
import AppKit

struct TranslationCard<HeaderTitle: View, Actions: View>: View {
    @ViewBuilder let title: HeaderTitle
    @Binding var text: String
    let isReadOnly: Bool
    let placeholder: String
    var textColor: Color = .primary
    let containerWidth: CGFloat
    let isHovered: Bool
    @ViewBuilder let actions: Actions
    @Environment(\.colorScheme) var colorScheme
    
    private var fontSize: CGFloat {
        let base: CGFloat = 18
        let scaled = containerWidth / 65
        return max(14, min(base, scaled))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                title
                    .frame(maxWidth: .infinity, alignment: .leading)
                actions
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: 32)
            
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: fontSize, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.4))
                        .allowsHitTesting(false)
                        .padding(.top, 10)
                }
                
                if isReadOnly {
                    ScrollView {
                        Text(text.isEmpty ? "" : text)
                            .font(.system(size: fontSize, weight: .medium, design: .rounded))
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                    }
                    .padding(.vertical, 10)
                } else {
                    NativeTextEditor(text: $text, font: .systemFont(ofSize: fontSize, weight: .medium))
                        .padding(.vertical, 10)
                        .frame(minHeight: 250)
                }
            }
        }
        .padding(geometryPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.15 : 0.6),
                                .white.opacity(colorScheme == .dark ? 0.05 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.12 : 0.06), radius: isHovered ? 30 : 20, x: 0, y: isHovered ? 15 : 10)
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
    }
    
    private var geometryPadding: CGFloat {
        containerWidth > 1200 ? 40 : 28
    }
}
