import SwiftUI
import SwiftData

/// 快捷命令详情视图
struct QuickCommandDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pipeline.name) private var pipelines: [Pipeline]
    @Query(sort: \Action.name) private var actions: [Action]
    @Bindable var quickCommand: QuickCommand
    var onDelete: () -> Void

    @StateObject private var commandRunner = CommandRunner()
    @StateObject private var pipelineRunner = PipelineRunner()
    @State private var showingDeleteConfirm = false
    @State private var isEditing = false

    private var isRunning: Bool {
        commandRunner.isRunning || pipelineRunner.isRunning
    }

    private var linkedPipeline: Pipeline? {
        guard quickCommand.type == .pipeline,
              let pipelineId = quickCommand.pipelineId else { return nil }
        return pipelines.first { $0.id == pipelineId }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            headerSection

            Divider()

            // 内容区
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 命令显示/编辑
                    commandSection

                    // 调度设置
                    scheduleSection

                    // 输出区域
                    if isRunning || hasOutput {
                        outputSection
                    }
                }
                .padding(20)
            }
        }
        .confirmationDialog("确定删除此快捷命令？", isPresented: $showingDeleteConfirm) {
            Button("删除", role: .destructive) {
                onDelete()
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "bolt.fill")
                .font(.title2)
                .foregroundStyle(.purple)

            if isEditing {
                TextField("名称", text: $quickCommand.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
            } else {
                Text(quickCommand.name)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    isEditing.toggle()
                    if !isEditing {
                        quickCommand.updatedAt = Date()
                        saveContext(modelContext)
                    }
                } label: {
                    Image(systemName: isEditing ? "checkmark" : "pencil")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(.bar)
    }

    // MARK: - Command Section

    private var commandSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 根据类型显示不同内容
            switch quickCommand.type {
            case .command:
                commandTypeSection
            case .pipeline:
                pipelineTypeSection
            }

            // 执行按钮
            HStack {
                Button {
                    Task {
                        await runTask()
                    }
                } label: {
                    HStack {
                        if isRunning {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(isRunning ? "执行中..." : "执行")
                    }
                    .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(isRunning || (quickCommand.type == .command && quickCommand.command.isEmpty))

                if isRunning {
                    Button("取消") {
                        if quickCommand.type == .command {
                            commandRunner.cancel()
                        } else {
                            pipelineRunner.cancel()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // 命令类型的显示
    private var commandTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("命令")
                .font(.headline)

            if isEditing {
                TextEditor(text: $quickCommand.command)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 60)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            } else {
                HStack {
                    Text(quickCommand.command)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(quickCommand.command, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .help("复制命令")
                }
            }
        }
    }

    // Pipeline 类型的显示
    private var pipelineTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("组合命令")
                    .font(.headline)

                if let pipeline = linkedPipeline {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(.orange)
                        Text(pipeline.name)
                            .foregroundStyle(.orange)
                    }
                    .font(.subheadline)
                } else {
                    Text("(Pipeline 已删除)")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }

            if let pipeline = linkedPipeline {
                // 执行流程
                HStack(spacing: 4) {
                    ForEach(Array(pipeline.steps.enumerated()), id: \.offset) { index, stepName in
                        if index > 0 {
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        let action = actions.first { $0.name == stepName }
                        Text(action?.label ?? stepName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }

            // 预设参数
            VStack(alignment: .leading, spacing: 4) {
                Text("预设参数")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    if let input = quickCommand.presetInput {
                        HStack(alignment: .top) {
                            Text("输入:")
                                .foregroundStyle(.secondary)
                            Text(input)
                                .textSelection(.enabled)
                        }
                        .font(.caption)
                    }
                    if let output = quickCommand.presetOutput {
                        HStack(alignment: .top) {
                            Text("输出:")
                                .foregroundStyle(.secondary)
                            Text(output)
                                .textSelection(.enabled)
                        }
                        .font(.caption)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)
            }
        }
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("自动执行")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                // 启动时执行
                Toggle(isOn: $quickCommand.runOnLaunch) {
                    HStack {
                        Image(systemName: "power")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text("启动时执行")
                            Text("每次打开 DoDo 时自动运行")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: quickCommand.runOnLaunch) {
                    saveContext(modelContext)
                }

                Divider()

                // 重复执行
                HStack {
                    Image(systemName: "repeat")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text("定时重复")
                        Text("在 DoDo 运行期间定期执行")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { quickCommand.repeatInterval ?? 0 },
                        set: { quickCommand.repeatInterval = $0 == 0 ? nil : $0 }
                    )) {
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
                    .onChange(of: quickCommand.repeatInterval) {
                        saveContext(modelContext)
                    }
                }

                // 上次执行时间
                if let lastRun = quickCommand.lastRunAt {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("上次执行: \(lastRun.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Output Section

    private var hasOutput: Bool {
        !currentOutput.isEmpty || !currentErrorOutput.isEmpty
    }

    private var currentOutput: String {
        quickCommand.type == .command ? commandRunner.output : pipelineRunner.output
    }

    private var currentErrorOutput: String {
        quickCommand.type == .command ? commandRunner.errorOutput : pipelineRunner.errorOutput
    }

    private var currentExitCode: Int? {
        quickCommand.type == .command ? commandRunner.exitCode : nil
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("输出")
                    .font(.headline)

                Spacer()

                if let code = currentExitCode {
                    HStack(spacing: 4) {
                        Image(systemName: code == 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(code == 0 ? .green : .red)
                        Text("退出码: \(code)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if quickCommand.type == .pipeline && pipelineRunner.isRunning {
                    Text("步骤 \(pipelineRunner.currentStep)/\(pipelineRunner.totalSteps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if isRunning {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }

            // stdout
            if !currentOutput.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("标准输出")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView {
                        Text(currentOutput)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
                }
            }

            // stderr
            if !currentErrorOutput.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("错误输出")
                        .font(.caption)
                        .foregroundStyle(.red)
                    ScrollView {
                        Text(currentErrorOutput)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func runTask() async {
        // 在异步操作前保存必要的值，避免操作期间对象失效
        let taskId = quickCommand.id
        let taskType = quickCommand.type
        let command = quickCommand.command

        switch taskType {
        case .command:
            do {
                _ = try await commandRunner.run(command)
                // 异步操作后通过 ID 重新获取对象再更新
                updateLastRunAt(taskId: taskId)
            } catch {
                print("执行失败: \(error)")
            }

        case .pipeline:
            guard let pipeline = linkedPipeline,
                  let input = quickCommand.presetInput else {
                print("Pipeline 配置无效")
                return
            }

            // 构建输出格式配置
            var finalFormat: OutputFormatConfig?
            if let options = quickCommand.presetFormatOptions, !options.isEmpty {
                if let lastStepName = pipeline.steps.last,
                   let lastAction = actions.first(where: { $0.name == lastStepName }) {
                    finalFormat = lastAction.supportedOutputFormats.first { config in
                        config.requiredOptions == options
                    }
                }
            }

            do {
                _ = try await pipelineRunner.run(
                    pipeline: pipeline,
                    actions: Array(actions),
                    input: input,
                    finalOutput: quickCommand.presetOutput,
                    finalOutputFormat: finalFormat
                )
                // 异步操作后通过 ID 重新获取对象再更新
                updateLastRunAt(taskId: taskId)
            } catch {
                print("Pipeline 执行失败: \(error)")
            }
        }
    }

    /// 通过 ID 安全地更新 lastRunAt，避免访问可能已失效的对象
    private func updateLastRunAt(taskId: UUID) {
        let descriptor = FetchDescriptor<QuickCommand>(
            predicate: #Predicate<QuickCommand> { $0.id == taskId }
        )
        guard let task = try? modelContext.fetch(descriptor).first else {
            print("QuickCommand 已被删除，跳过更新 lastRunAt")
            return
        }
        task.lastRunAt = Date()
        saveContext(modelContext)
    }
}

#Preview {
    QuickCommandDetailView(
        quickCommand: QuickCommand(
            name: "安装 Claude Code",
            command: "npm i -g @anthropic-ai/claude-code"
        ),
        onDelete: {}
    )
    .frame(width: 600, height: 400)
}
