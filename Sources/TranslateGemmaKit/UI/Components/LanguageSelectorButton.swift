import SwiftUI

public struct LanguageSelectorButton: View {
    let title: String
    let isAuto: Bool
    let detectedLanguage: String?
    let accentColor: Color
    let action: () -> Void
    
    public init(title: String, isAuto: Bool = false, detectedLanguage: String? = nil, accentColor: Color, action: @escaping () -> Void) {
        self.title = title
        self.isAuto = isAuto
        self.detectedLanguage = detectedLanguage
        self.accentColor = accentColor
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isAuto ? "sparkles" : "character.bubble.fill")
                    .font(.system(size: 10))
                    .foregroundColor(accentColor)
                
                Text(isAuto ? (detectedLanguage != nil ? "Auto: \(detectedLanguage!)" : "Auto Detect") : title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(ZStack { Capsule().fill(.ultraThinMaterial); Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5) })
        }
        .buttonStyle(.plain)
    }
}
