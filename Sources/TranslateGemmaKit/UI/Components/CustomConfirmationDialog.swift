import SwiftUI

public struct CustomConfirmationDialog: View {
    let title: String
    let message: String
    let confirmTitle: String
    let isDestructive: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    public init(
        title: String,
        message: String,
        confirmTitle: String,
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.isDestructive = isDestructive
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
                        .fill(isDestructive ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: isDestructive ? "exclamationmark.triangle.fill" : "questionmark.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(isDestructive ? .red : .blue)
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
                                    .fill(isDestructive ? 
                                        LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                        LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .shadow(color: (isDestructive ? Color.red : Color.blue).opacity(0.3), radius: 8, x: 0, y: 4)
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
