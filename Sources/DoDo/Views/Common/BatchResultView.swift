import SwiftUI

/// 批量结果视图（命令）
struct BatchCommandResultView: View {
    @ObservedObject var execution: BatchExecution
    var onItemSelect: ((BatchItem) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Design.spacingMedium) {
            // 标题行
            HStack {
                if execution.isRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("批量执行中 (\(execution.progress))")
                        .font(.headline)
                } else {
                    Text("完成")
                        .font(.headline)
                    if execution.completedCount > 0 {
                        Text("✓\(execution.completedCount)")
                            .foregroundColor(.green)
                    }
                    if execution.failedCount > 0 {
                        Text("✗\(execution.failedCount)")
                            .foregroundColor(.red)
                    }
                }

                Spacer()
            }

            // 结果列表
            ScrollView {
                VStack(spacing: Design.spacingSmall) {
                    ForEach(execution.items) { item in
                        BatchItemRow(item: item, isSelected: item.id == execution.selectedItemId)
                            .onTapGesture {
                                execution.selectedItemId = item.id
                                onItemSelect?(item)
                            }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }
}

/// 批量结果视图（API）
struct BatchAPIResultView: View {
    @ObservedObject var execution: BatchExecution
    @State private var showExportPanel = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题行
            HStack {
                if execution.isRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("批量执行中 (\(execution.progress))")
                        .font(.headline)
                } else {
                    Text("完成")
                        .font(.headline)
                    if execution.completedCount > 0 {
                        Text("✓\(execution.completedCount)")
                            .foregroundColor(.green)
                    }
                    if execution.failedCount > 0 {
                        Text("✗\(execution.failedCount)")
                            .foregroundColor(.red)
                    }
                }

                Spacer()

                if !execution.isRunning && execution.completedCount > 0 {
                    Button("导出") {
                        showExportPanel = true
                    }
                }
            }
            .padding(.bottom, Design.paddingMedium)

            // 左右分栏
            HSplitView {
                // 左侧：结果列表
                ScrollView {
                    VStack(spacing: Design.spacingSmall) {
                        ForEach(execution.items) { item in
                            BatchItemRow(item: item, isSelected: item.id == execution.selectedItemId)
                                .onTapGesture {
                                    execution.selectedItemId = item.id
                                }
                        }
                    }
                }
                .frame(minWidth: 150, maxWidth: 250)

                // 右侧：选中项详情
                if let selectedItem = execution.selectedItem {
                    BatchAPIDetailView(item: selectedItem)
                } else {
                    Text("选择一项查看详情")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(isPresented: $showExportPanel) {
            ExportAPIResultsSheet(execution: execution)
        }
    }
}

/// 单项行视图
struct BatchItemRow: View {
    let item: BatchItem
    var isSelected: Bool = false

    var body: some View {
        HStack {
            // 状态图标
            statusIcon

            // 输入名称
            Text(displayName)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // 输出或时间
            if item.status == .success {
                if let output = item.output {
                    Text("→ \(URL(fileURLWithPath: output).lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(item.durationText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if item.status == .running {
                Text("执行中")
                    .font(.caption)
                    .foregroundColor(.blue)
            } else if item.status == .failed {
                Text(item.result ?? "失败")
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            } else {
                Text("等待中")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, Design.paddingMedium)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(Design.cornerRadiusSmall)
    }

    private var statusIcon: some View {
        Group {
            switch item.status {
            case .pending:
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
            case .running:
                ProgressView()
                    .scaleEffect(0.6)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .frame(width: 20)
    }

    private var displayName: String {
        // 如果是文件路径，只显示文件名
        if item.input.contains("/") {
            return URL(fileURLWithPath: item.input).lastPathComponent
        }
        return item.input
    }
}

/// API 详情视图（复用单条响应的展示）
struct BatchAPIDetailView: View {
    let item: BatchItem

    @State private var viewMode: APIResponseViewMode = .json

    var body: some View {
        VStack(alignment: .leading, spacing: Design.spacingMedium) {
            // 视图切换
            Picker("", selection: $viewMode) {
                Text("JSON").tag(APIResponseViewMode.json)
                Text("卡片/表格").tag(APIResponseViewMode.card)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)

            // 响应内容
            if let response = item.response {
                ScrollView {
                    if viewMode == .json {
                        JSONResponseView(json: response.json, rawData: response.data)
                    } else {
                        CardResponseView(json: response.json)
                    }
                }
            } else if let result = item.result {
                ScrollView {
                    Text(result)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("无数据")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

/// API 响应视图模式
enum APIResponseViewMode {
    case json
    case card
}

/// 导出 API 结果表单
struct ExportAPIResultsSheet: View {
    @ObservedObject var execution: BatchExecution
    @Environment(\.dismiss) private var dismiss

    @State private var exportPath: String = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Design.spacingXL) {
            Text("导出 API 结果")
                .font(.headline)

            Text("将 \(execution.completedCount) 个成功的响应导出为 JSON 文件")
                .foregroundColor(.secondary)

            HStack {
                TextField("输出目录", text: $exportPath)
                    .textFieldStyle(.roundedBorder)

                Button("选择") {
                    selectDirectory()
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Spacer()

                Button("取消") {
                    dismiss()
                }

                Button("导出") {
                    exportResults()
                }
                .buttonStyle(.borderedProminent)
                .disabled(exportPath.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            exportPath = url.path
        }
    }

    private func exportResults() {
        let runner = BatchRunner()
        runner.execution = execution

        do {
            try runner.exportAPIResults(to: exportPath)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
