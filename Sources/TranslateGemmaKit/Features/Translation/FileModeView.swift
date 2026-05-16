import SwiftUI

public struct FileModeView: View {
    @Bindable var translationController: TranslationController
    let geometry: GeometryProxy
    let currentAccentColor: Color
    let importBatchFiles: () -> Void
    let selectExportDirectory: () -> Void
    
    @State private var selectedTaskIds = Set<UUID>()
    @State private var showBulkTargetPicker = false
    
    public init(
        translationController: TranslationController,
        geometry: GeometryProxy,
        currentAccentColor: Color,
        importBatchFiles: @escaping () -> Void,
        selectExportDirectory: @escaping () -> Void
    ) {
        self.translationController = translationController
        self.geometry = geometry
        self.currentAccentColor = currentAccentColor
        self.importBatchFiles = importBatchFiles
        self.selectExportDirectory = selectExportDirectory
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 24) {
                if translationController.tasks.isEmpty {
                    dropZone
                } else {
                    taskQueueList
                }
            }
            .frame(maxWidth: min(geometry.size.width - 64, 1600))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40)
            
            if !selectedTaskIds.isEmpty {
                bulkActionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 40)
            }
        }
    }
    
    @ViewBuilder
    private var taskQueueList: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Task Queue")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                    Text("\(translationController.tasks.count) files in queue")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: importBatchFiles) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Files")
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(ZStack { Capsule().fill(.ultraThinMaterial); Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 0.5) })
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(currentAccentColor)
                    .opacity(translationController.isBatchProcessing ? 0.5 : 1.0)
                    .disabled(translationController.isBatchProcessing)
                    
                    Button(action: { withAnimation { translationController.clearTasks() } }) {
                        Text("Clear All")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(ZStack { Capsule().fill(.ultraThinMaterial); Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 0.5) })
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .opacity(translationController.isBatchProcessing ? 0.5 : 1.0)
                    .disabled(translationController.isBatchProcessing)
                }
            }
            .padding(.horizontal, 8)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($translationController.tasks) { $task in
                        TaskCard(
                            task: $task,
                            accentColor: currentAccentColor,
                            isSelected: selectedTaskIds.contains(task.id),
                            onSelect: {
                                if selectedTaskIds.contains(task.id) {
                                    selectedTaskIds.remove(task.id)
                                } else {
                                    selectedTaskIds.insert(task.id)
                                }
                            },
                            onReveal: { url in
                                translationController.revealInFinder(outputURL: url)
                            }
                        ) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedTaskIds.remove(task.id)
                                translationController.removeTask(task)
                            }
                        }
                    }
                }
                .padding(4)
            }
            
            exportLocationFooter
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
        )
    }
    
    @ViewBuilder
    private var exportLocationFooter: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(currentAccentColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 14))
                    .foregroundColor(currentAccentColor)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Export Location")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Text(translationController.exportDirectory != nil ? translationController.exportDirectory!.lastPathComponent : "Original Directory")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
            }
            
            Spacer()
            
            Button(action: selectExportDirectory) {
                Text(translationController.exportDirectory != nil ? "Change Folder" : "Set Export Folder")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(currentAccentColor.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .foregroundColor(currentAccentColor)
            .opacity(translationController.isBatchProcessing ? 0.5 : 1.0)
            .disabled(translationController.isBatchProcessing)
            
            if translationController.exportDirectory != nil {
                Button(action: { withAnimation { translationController.exportDirectory = nil } }) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.04)))
        .padding(.top, 4)
    }
    
    @ViewBuilder
    private var bulkActionBar: some View {
        HStack(spacing: 20) {
            Text("\(selectedTaskIds.count) items selected")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            HStack(spacing: 12) {
                // Change Target Language
                Button(action: { showBulkTargetPicker = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "character.bubble.fill")
                        Text("Set Target Language")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.white.opacity(0.2)))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showBulkTargetPicker) {
                    LanguagePickerView(
                        selectedLanguage: Binding(
                            get: { "Select..." },
                            set: { lang in
                                translationController.updateTargetLanguageForTasks(ids: selectedTaskIds, to: lang)
                                showBulkTargetPicker = false
                                selectedTaskIds.removeAll()
                            }
                        ),
                        isPresented: $showBulkTargetPicker,
                        includeAuto: false,
                        accentColor: currentAccentColor
                    )
                }
                
                // Bulk Remove
                Button(action: {
                    withAnimation {
                        translationController.removeTasks(ids: selectedTaskIds)
                        selectedTaskIds.removeAll()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        Text("Remove")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.red.opacity(0.8)))
                }
                .buttonStyle(.plain)
                
                Divider().frame(height: 20).background(Color.white.opacity(0.3))
                
                // Cancel selection
                Button(action: { selectedTaskIds.removeAll() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .padding(8)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            Capsule()
                .fill(currentAccentColor)
                .shadow(color: currentAccentColor.opacity(0.4), radius: 20, y: 10)
        )
        .foregroundColor(.white)
        .frame(width: 550)
    }
    
    @ViewBuilder
    private var dropZone: some View {
        Button(action: importBatchFiles) {
            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(currentAccentColor.opacity(0.08))
                        .frame(width: 160, height: 160)
                    
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 64))
                        .foregroundColor(currentAccentColor)
                        .shadow(color: currentAccentColor.opacity(0.3), radius: 25)
                }
                
                VStack(spacing: 10) {
                    Text("Batch Translation")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                    Text("Drop Subtitle or Markdown files here")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                    Text("Select Files")
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .padding(.horizontal, 36)
                .padding(.vertical, 14)
                .background(Capsule().fill(currentAccentColor))
                .foregroundColor(.white)
                .shadow(color: currentAccentColor.opacity(0.3), radius: 15, x: 0, y: 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .strokeBorder(currentAccentColor.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [12, 12]))
                .background(RoundedRectangle(cornerRadius: 48, style: .continuous).fill(currentAccentColor.opacity(0.02)))
        )
    }
}
