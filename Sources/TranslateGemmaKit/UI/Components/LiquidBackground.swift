import SwiftUI

public struct LiquidBackground: View {
    @State private var t: Float = 0
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    @Environment(\.colorScheme) var colorScheme
    var accentColor: Color = .blue
    
    public init(accentColor: Color = .blue) {
        self.accentColor = accentColor
    }
    
    public var body: some View {
        if #available(macOS 15.0, *) {
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5 + 0.15 * sin(t * 0.8), 0.5 + 0.15 * cos(t * 1.2)], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ], colors: colorScheme == .dark ? [
                accentColor.opacity(0.3), .indigo.opacity(0.2), accentColor.opacity(0.2),
                accentColor.opacity(0.1), .black, .indigo.opacity(0.1),
                accentColor.opacity(0.2), accentColor.opacity(0.3), .indigo.opacity(0.2)
            ] : [
                accentColor.opacity(0.15), accentColor.opacity(0.1), .white,
                .indigo.opacity(0.05), accentColor.opacity(0.2), accentColor.opacity(0.1),
                .white, accentColor.opacity(0.15), .indigo.opacity(0.1)
            ])
            .onReceive(timer) { _ in
                t += 0.015
            }
            .ignoresSafeArea()
            .blur(radius: 40)
            .animation(.easeInOut(duration: 1.0), value: accentColor)
        } else {
            LinearGradient(
                colors: colorScheme == .dark ? [.black, accentColor.opacity(0.2), .indigo.opacity(0.1)] : [.white, accentColor.opacity(0.1), accentColor.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.0), value: accentColor)
        }
    }
}
