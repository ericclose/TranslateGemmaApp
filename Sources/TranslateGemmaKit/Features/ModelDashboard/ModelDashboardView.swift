import SwiftUI

public struct ModelDashboardView: View {
    @Environment(ModelManager.self) private var modelManager
    @Binding var selectedModelId: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    private var currentAccentColor: Color {
        if selectedModelId.contains("27b") { return .purple }
        if selectedModelId.contains("12b") { return .indigo }
        return .blue
    }
    
    enum ActiveDialog: Identifiable {
        case delete(ModelInfo)
        case cancelDownload(ModelInfo)
        
        var id: String {
            switch self {
            case .delete(let m): return "delete-\(m.id)"
            case .cancelDownload(let m): return "cancel-\(m.id)"
            }
        }
    }
    
    @State private var activeDialog: ActiveDialog? = nil
    
    public init(selectedModelId: Binding<String>) {
        self._selectedModelId = selectedModelId
    }
    
    public var body: some View {
        ZStack {
            LiquidBackground(accentColor: currentAccentColor)
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "cpu")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.blue)
                            Text("Model Library")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                        }
                        Text("Manage your local LLM weights and storage")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(OrnamentButtonStyle())
                }
                .padding(32)
                
                // Requirement Prompt
                if !modelManager.models.contains(where: { $0.isDownloaded }) {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("No Models Downloaded")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Text("Download at least one model to start translating.")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.orange.opacity(0.1)))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.orange.opacity(0.2), lineWidth: 1))
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)
                    }
                } else if selectedModelId.isEmpty {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Select a Model")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Text("Choose an active model from the list below to begin.")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.blue.opacity(0.1)))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.blue.opacity(0.2), lineWidth: 1))
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)
                    }
                }
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(modelManager.models) { model in
                            ModelRowView(
                                model: model,
                                selectedModelId: $selectedModelId,
                                onDelete: { activeDialog = .delete(model) },
                                onCancelDownload: { activeDialog = .cancelDownload(model) }
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
                
                // Unified Storage Management Footer
                VStack(spacing: 0) {
                    Divider().opacity(colorScheme == .dark ? 0.2 : 0.1)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Storage Location")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(modelManager.currentHubPath)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.primary.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 10) {
                            Button("Reset") { modelManager.resetToDefaultHubPath() }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(.primary.opacity(0.05)))
                            
                            Button(action: { modelManager.selectCustomHubPath() }) {
                                Label("Change", systemImage: "pencil")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.blue))
                            .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                    .background(.ultraThinMaterial)
                }
            }
            
            // Custom Dialog Overlay
            if let dialog = activeDialog {
                Group {
                    switch dialog {
                    case .delete(let model):
                        CustomConfirmationDialog(
                            title: "Delete Model?",
                            message: "Are you sure you want to delete \(model.name)? This action cannot be undone.",
                            confirmTitle: "Delete",
                            style: .destructive,
                            onConfirm: {
                                withAnimation { activeDialog = nil }
                                modelManager.deleteModel(modelId: model.id)
                                if selectedModelId == model.id { selectedModelId = "" }
                            },
                            onCancel: { withAnimation { activeDialog = nil } }
                        )
                    case .cancelDownload(let model):
                        CustomConfirmationDialog(
                            title: "Stop Download?",
                            message: "Are you sure you want to cancel the download for \(model.name)?",
                            confirmTitle: "Stop",
                            style: .warning,
                            onConfirm: {
                                withAnimation { activeDialog = nil }
                                modelManager.cancelDownload()
                            },
                            onCancel: { withAnimation { activeDialog = nil } }
                        )
                    }
                }
            }
        }
        .frame(width: 680, height: 640)
    }
}

struct ModelRowView: View {
    let model: ModelInfo
    @Environment(ModelManager.self) private var modelManager
    @Binding var selectedModelId: String
    @Environment(\.colorScheme) var colorScheme
    let onDelete: () -> Void
    let onCancelDownload: () -> Void
    @State private var isHovered = false
    
    var isSelected: Bool { model.id == selectedModelId }
    
    private func selectModel() {
        if model.isDownloaded {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedModelId = model.id
            }
        }
    }
    
    private var rowBackground: Color {
        if isSelected {
            return Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.05)
        } else if isHovered {
            return Color.primary.opacity(0.03)
        } else {
            return Color.clear
        }
    }
    
    private var rowStroke: Color {
        isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.1)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue.opacity(0.15) : (model.isDownloaded ? Color.blue.opacity(0.05) : Color.primary.opacity(0.03)))
                    .frame(width: 48, height: 48)
                Image(systemName: isSelected ? "brain.head.profile.fill" : (model.isDownloaded ? "brain.head.profile" : "cloud.circle"))
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .blue : (model.isDownloaded ? .blue : .secondary))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .blue : .primary)
                HStack(spacing: 8) {
                    Text(model.size)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    if isSelected {
                        Text("• Active")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                    } else if model.isDownloaded {
                        Text("• Local")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.green.opacity(0.8))
                    }
                }
            }
            Spacer()
            
            if model.isDownloaded {
                HStack(spacing: 10) {
                    Button(action: { modelManager.revealInFinder(modelId: model.id) }) {
                        Image(systemName: "folder")
                            .font(.system(size: 12, weight: .bold))
                            .padding(8)
                            .background(Circle().fill(.primary.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .bold))
                            .padding(8)
                            .background(Circle().fill(.red.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .help("Delete Model")
                }
            } else if modelManager.downloadingModelId == model.id {
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 8) {
                        ProgressView(value: model.downloadProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 120)
                            .tint(.blue)
                        Button(action: onCancelDownload) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack(spacing: 4) {
                        if modelManager.isConnecting && model.completedSize == 0 {
                            Text("Connecting...").italic()
                        } else {
                            Text(String(format: "%.1f%%", model.downloadProgress * 100))
                            Text("•")
                            Text(ByteCountFormatter.string(fromByteCount: model.completedSize, countStyle: .file))
                            Text("/")
                            Text(ByteCountFormatter.string(fromByteCount: model.totalSize, countStyle: .file))
                        }
                    }
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.blue.opacity(0.8))
                    .padding(.trailing, 28)
                }
            } else {
                Button(action: { Task { await modelManager.downloadModel(modelId: model.id) } }) {
                    HStack(spacing: 8) {
                        Image(systemName: "icloud.and.arrow.down").font(.system(size: 12, weight: .bold))
                        Text("Download").font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .foregroundColor(.white)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .opacity(modelManager.isDownloading ? 0.5 : 1.0)
                .disabled(modelManager.isDownloading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(rowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(rowStroke, lineWidth: 1)
        )
        .scaleEffect(isSelected ? 1.015 : 1.0)
        .shadow(color: isSelected ? Color.blue.opacity(0.12) : Color.clear, radius: 12, x: 0, y: 6)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isSelected)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { selectModel() }
    }
}
