import SwiftUI

public struct OrnamentButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .frame(width: 32, height: 32)
            .background(
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().strokeBorder(.white.opacity(colorScheme == .dark ? 0.1 : 0.4), lineWidth: 0.5)
                }
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
