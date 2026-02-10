import SwiftUI
import SwiftData

/// 保存为快捷命令的弹窗
struct SaveAsQuickCommandSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Binding var name: String
    let command: String
    let sourceName: String

    @State private var runOnLaunch = false
    @State private var repeatInterval: Int = 0

    var body: some View {
        VStack(spacing: Design.spacingSection) {
            Text("保存为定时任务")
                .font(.headline)

            VStack(alignment: .leading, spacing: Design.spacingXL) {
                // 名称
                VStack(alignment: .leading, spacing: Design.spacingSmall) {
                    Text("名称")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("任务名称", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                // 命令预览
                VStack(alignment: .leading, spacing: Design.spacingSmall) {
                    Text("命令")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(command)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(3)
                        .padding(Design.paddingMedium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(Design.cornerRadiusMedium)
                }

                Divider()

                // 调度设置
                VStack(alignment: .leading, spacing: Design.spacingLarge) {
                    Text("自动执行")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Toggle("启动时执行", isOn: $runOnLaunch)

                    HStack {
                        Text("定时重复")
                        Spacer()
                        Picker("", selection: $repeatInterval) {
                            Text("不重复").tag(0)
                            Divider()
                            Text("每分钟").tag(60)
                            Text("每5分钟").tag(300)
                            Text("每15分钟").tag(900)
                            Text("每30分钟").tag(1800)
                            Divider()
                            Text("每小时").tag(3600)
                            Text("每2小时").tag(7200)
                            Text("每4小时").tag(14400)
                            Text("每8小时").tag(28800)
                            Text("每12小时").tag(43200)
                            Divider()
                            Text("每天").tag(86400)
                        }
                        .frame(width: 120)
                    }
                }
            }
            .frame(width: 350)

            HStack(spacing: Design.spacingLarge) {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("保存") {
                    saveQuickCommand()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding(Design.paddingSection)
    }

    private func saveQuickCommand() {
        let quickCommand = QuickCommand(
            name: name,
            command: command,
            runOnLaunch: runOnLaunch,
            repeatInterval: repeatInterval == 0 ? nil : repeatInterval
        )
        modelContext.insert(quickCommand)
        saveContext(modelContext)
        // 自动备份到 iCloud JSON
        let config = QuickCommandConfig.from(quickCommand)
        try? ConfigManager.shared.saveQuickCommandConfig(config, name: config.name)
        dismiss()
    }
}

/// 保存 Pipeline 为快捷命令的弹窗
struct SaveAsPipelineQuickCommandSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Binding var name: String
    let pipeline: Pipeline
    let presetInput: String
    let presetOutput: String?
    let presetFormatOptions: [String]?

    @State private var runOnLaunch = false
    @State private var repeatInterval: Int = 0

    var body: some View {
        VStack(spacing: Design.spacingSection) {
            Text("保存为定时任务")
                .font(.headline)

            VStack(alignment: .leading, spacing: Design.spacingXL) {
                // 名称
                VStack(alignment: .leading, spacing: Design.spacingSmall) {
                    Text("名称")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("任务名称", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                // Pipeline 信息
                VStack(alignment: .leading, spacing: Design.spacingSmall) {
                    Text("组合命令")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(.orange)
                        Text(pipeline.name)
                        Text("(\(pipeline.steps.joined(separator: " → ")))")
                            .foregroundStyle(.secondary)
                    }
                    .padding(Design.paddingMedium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(Design.cornerRadiusMedium)
                }

                // 预设参数
                VStack(alignment: .leading, spacing: Design.spacingSmall) {
                    Text("预设参数")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: Design.spacingTight) {
                        Text("输入: \(presetInput)")
                            .font(.caption)
                        if let output = presetOutput {
                            Text("输出: \(output)")
                                .font(.caption)
                        }
                    }
                    .padding(Design.paddingMedium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(Design.cornerRadiusMedium)
                }

                Divider()

                // 调度设置
                VStack(alignment: .leading, spacing: Design.spacingLarge) {
                    Text("自动执行")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Toggle("启动时执行", isOn: $runOnLaunch)

                    HStack {
                        Text("定时重复")
                        Spacer()
                        Picker("", selection: $repeatInterval) {
                            Text("不重复").tag(0)
                            Divider()
                            Text("每分钟").tag(60)
                            Text("每5分钟").tag(300)
                            Text("每15分钟").tag(900)
                            Text("每30分钟").tag(1800)
                            Divider()
                            Text("每小时").tag(3600)
                            Text("每2小时").tag(7200)
                            Text("每4小时").tag(14400)
                            Text("每8小时").tag(28800)
                            Text("每12小时").tag(43200)
                            Divider()
                            Text("每天").tag(86400)
                        }
                        .frame(width: 120)
                    }
                }
            }
            .frame(width: 380)

            HStack(spacing: Design.spacingLarge) {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("保存") {
                    saveQuickCommand()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding(Design.paddingSection)
    }

    private func saveQuickCommand() {
        let quickCommand = QuickCommand(
            name: name,
            pipelineId: pipeline.id,
            presetInput: presetInput,
            presetOutput: presetOutput,
            presetFormatOptions: presetFormatOptions,
            runOnLaunch: runOnLaunch,
            repeatInterval: repeatInterval == 0 ? nil : repeatInterval
        )
        modelContext.insert(quickCommand)
        saveContext(modelContext)
        // Pipeline 类型的 QuickCommand 暂不备份到 JSON（依赖 pipelineId）
        dismiss()
    }
}

#Preview {
    SaveAsQuickCommandSheet(
        name: .constant("网页抓取"),
        command: "wf https://example.com -o /tmp",
        sourceName: "wf"
    )
}
