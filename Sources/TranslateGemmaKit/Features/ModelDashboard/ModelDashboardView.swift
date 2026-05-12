import SwiftUI

public struct ModelDashboardView: View {
    @Environment(ModelManager.self) private var modelManager
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedModelId: String
    
    public init(selectedModelId: Binding<String>) {
        self._selectedModelId = selectedModelId
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model Library")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Manage your TranslateGemma models")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(modelManager.models) { model in
                        ModelRow(model: model, isSelected: selectedModelId == model.id) {
                            selectedModelId = model.id
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Settings")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Storage Path")
                                    .font(.subheadline)
                                Text(modelManager.currentHubPath)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            HStack {
                                Button("Change") {
                                    modelManager.selectCustomHubPath()
                                }
                                Button("Reset") {
                                    modelManager.resetToDefaultHubPath()
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                    }
                    .padding(.top, 16)
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
    }
}

struct ModelRow: View {
    @Environment(ModelManager.self) private var modelManager
    let model: ModelInfo
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.name)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        if isSelected && model.isDownloaded {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                        }
                    }
                    Text(model.size)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if model.isDownloaded {
                    HStack(spacing: 8) {
                        Button(action: onSelect) {
                            Text(isSelected ? "Selected" : "Select")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isSelected ? .blue : .secondary)
                        .disabled(isSelected)
                        
                        Menu {
                            Button("Show in Finder") {
                                modelManager.revealInFinder(modelId: model.id)
                            }
                            Button("Delete", role: .destructive) {
                                modelManager.deleteModel(modelId: model.id)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        }
                        .menuStyle(.button)
                        .buttonStyle(.plain)
                    }
                } else if modelManager.isDownloading && modelManager.downloadingModelId == model.id {
                    Button(action: { modelManager.cancelDownload() }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        Task {
                            await modelManager.downloadModel(modelId: model.id)
                        }
                    }) {
                        Label("Download", systemImage: "icloud.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .disabled(modelManager.isDownloading)
                }
            }
            
            if modelManager.isDownloading && modelManager.downloadingModelId == model.id {
                VStack(spacing: 4) {
                    ProgressView(value: model.downloadProgress)
                        .progressViewStyle(.linear)
                    
                    HStack {
                        if modelManager.isConnecting {
                            Text("Connecting...")
                        } else {
                            Text("\(formatBytes(model.completedSize)) / \(model.size)")
                        }
                        Spacer()
                        Text("\(Int(model.downloadProgress * 100))%")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected && model.isDownloaded ? Color.blue.opacity(0.1) : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected && model.isDownloaded ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
