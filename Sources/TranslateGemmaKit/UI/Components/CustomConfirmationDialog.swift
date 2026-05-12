import SwiftUI

public struct CustomConfirmationDialog: View {
    public enum Style {
        case info, warning, destructive
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .destructive: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "questionmark.circle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .destructive: return "exclamationmark.triangle.fill"
            }
        }
        
        var gradient: LinearGradient {
            switch self {
            case .info: return LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .warning: return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .destructive: return LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    let title: String
    let message: String
    let confirmTitle: String
    let style: Style
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    public init(
        title: String,
        message: String,
        confirmTitle: String,
        style: Style = .info,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.style = style
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }
    
    public var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(colorScheme == .dark ? 0.5 : 0.3)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
            
            VStack(spacing: 24) {
                // Header Icon
                ZStack {
                    Circle()
                        .fill(style.color.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: style.icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(style.color)
                }
                .padding(.top, 8)
                
                // Content
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                    Text(message)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 16)
                
                // Actions
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onConfirm) {
                        Text(confirmTitle)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(style.gradient)
                                    .shadow(color: style.color.opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 40, x: 0, y: 20)
            .frame(width: 360)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.7)),
                removal: .scale(scale: 1.05).combined(with: .opacity).animation(.easeIn(duration: 0.15))
            ))
        }
        .zIndex(100)
    }
}
