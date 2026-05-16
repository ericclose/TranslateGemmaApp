import SwiftUI
import AppKit

public struct TaskCard: View {
    @Binding var task: TranslationTask
    let accentColor: Color
    let isSelected: Bool
    let onSelect: () -> Void
    let onReveal: (URL) -> Void
    let onRemove: () -> Void
    
    @State private var isHovered = false
    @State private var showSourcePicker = false
    @State private var showTargetPicker = false
    @Environment(\.colorScheme) var colorScheme
    
    public init(
        task: Binding<TranslationTask>,
        accentColor: Color,
        isSelected: Bool = false,
        onSelect: @escaping () -> Void = {},
        onReveal: @escaping (URL) -> Void,
        onRemove: @escaping () -> Void
    ) {
        self._task = task
        self.accentColor = accentColor
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onReveal = onReveal
        self.onRemove = onRemove
    }
    
    private var fileIcon: String {
        let ext = task.sourceURL.pathExtension.lowercased()
        switch ext {
        case "srt", "vtt", "ass": return "captions.bubble.fill"
        case "md", "markdown": return "doc.markup.fill"
        case "txt": return "doc.text.fill"
        default: return "doc.fill"
        }
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            // Selection Checkbox
            Button(action: onSelect) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? accentColor : .secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, -4)
            
            // File Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentColor.opacity(0.12))
                Image(systemName: fileIcon)
                    .foregroundColor(accentColor)
                    .font(.system(size: 18))
            }
            .frame(width: 44, height: 44)
            
            // Name & Size
            VStack(alignment: .leading, spacing: 2) {
                Text(task.fileName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(ByteCountFormatter().string(fromByteCount: task.fileSize))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .frame(width: 180, alignment: .leading)
            
            Divider()
                .frame(height: 24)
                .opacity(0.3)
            
            // Language Settings
            HStack(spacing: 8) {
                // Source Language
                if case .pending = task.status {
                    Button(action: { showSourcePicker = true }) {
                        Text(task.sourceLang ?? "Auto")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.primary.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showSourcePicker) {
                        LanguagePickerView(
                            selectedLanguage: Binding(
                                get: { task.sourceLang ?? "Auto" },
                                set: { task.sourceLang = ($0 == "Auto" ? nil : $0) }
                            ),
                            isPresented: $showSourcePicker,
                            includeAuto: true,
                            accentColor: accentColor
                        )
                    }
                } else {
                    Text(task.sourceLang ?? "Auto")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.primary.opacity(0.05)))
                }
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.4))
                
                // Target Language
                if case .pending = task.status {
                    Button(action: { showTargetPicker = true }) {
                        HStack(spacing: 4) {
                            Text(task.targetLang)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(accentColor.opacity(0.1)))
                        .foregroundColor(accentColor)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showTargetPicker) {
                        LanguagePickerView(
                            selectedLanguage: $task.targetLang,
                            isPresented: $showTargetPicker,
                            includeAuto: false,
                            accentColor: accentColor
                        )
                    }
                } else {
                    Text(task.targetLang)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(accentColor.opacity(0.1)))
                }
            }
            
            Spacer()
            
            // Progress / Status
            Group {
                switch task.status {
                case .pending:
                    Text("Ready")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().strokeBorder(.secondary.opacity(0.2), lineWidth: 1))
                    
                case .processing:
                    ProgressView()
                        .controlSize(.small)
                        .tint(accentColor)
                        .frame(width: 100)
                    
                case .completed(let url):
                    HStack(spacing: 12) {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Done")
                            }
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                            
                            if let duration = task.duration {
                                Text(TimeFormatter.formatETA(duration))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: { onReveal(url) }) {
                            Image(systemName: "folder")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                                .padding(6)
                                .background(Circle().fill(.green.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")
                    }
                    
                case .failed(let error):
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.red)
                            .lineLimit(1)
                            .frame(maxWidth: 120)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.red.opacity(0.1)))
                }
            }
            .frame(width: 160, alignment: .trailing)
            
            // Remove / Cancel Button
            if case .processing = task.status {
                Button(action: { 
                    withAnimation {
                        task.isCancelled = true 
                    }
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Cancel this file")
            } else {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.1 : 0.4),
                                .white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .shadow(color: Color.black.opacity(isHovered ? 0.1 : 0.04), radius: isHovered ? 15 : 10, x: 0, y: isHovered ? 8 : 4)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isHovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
