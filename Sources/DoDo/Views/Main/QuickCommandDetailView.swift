import SwiftUI
import SwiftData

/// 快捷命令详情视图
struct QuickCommandDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pipeline.name) private var pipelines: [Pipeline]
    @Query(sort: \Action.name) private var actions: [Action]
    @Bindable var quickCommand: QuickCommand
    var onDelete: () -> Void

    @Query(sort: \Execution.startedAt, order: .reverse) private var allExecutions: [Execution]
    @StateObject private var commandRunner = CommandRunner()
    @StateObject private var pipelineRunner = PipelineRunner()
    @State private var showingDeleteConfirm = false
    @State private var isEditing = false
    @State private var expandedExecutionId: UUID?

    /// Executions for this QuickCommand (using quickCommand.id as actionId)
    private var recentExecutions: [Execution] {
        allExecutions.filter { $0.actionId == quickCommand.id }.prefix(10).map { $0 }
    }

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
                VStack(alignment: .leading, spacing: Design.spacingSection) {
                    // 命令显示/编辑
                    commandSection

                    // 调度设置
                    scheduleSection

                    // 输出区域
                    if isRunning || hasOutput {
                        outputSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // 执行历史
                    if !recentExecutions.isEmpty {
                        executionHistorySection
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isRunning)
                .animation(.easeInOut(duration: 0.2), value: hasOutput)
                .padding(Design.paddingXXL)
            }
        }
        .confirmationDialog("确定删除此快捷命令？", isPresented: $showingDeleteConfirm) {
            Button("删除", role: .destructive) {
                onDelete()
            }
            Button("取消", role: .cancel) {}
        }
        .focusedSceneValue(\.copyablePageText, pageTextForCopy)
    }

    /// 页面全部文本（用于 Cmd+Shift+A 复制）
    private var pageTextForCopy: String {
        var parts: [String] = []
        parts.append("[\(quickCommand.name)]")
        if quickCommand.type == .command {
            parts.append("命令: \(quickCommand.command)")
        } else {
            parts.append("类型: 组合命令")
        }
        if !currentOutput.isEmpty { parts.append("标准输出:\n\(currentOutput)") }
        if !currentErrorOutput.isEmpty { parts.append("错误输出:\n\(currentErrorOutput)") }
        return parts.joined(separator: "\n\n")
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

            HStack(spacing: Design.spacingLarge) {
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
        .padding(Design.paddingXL)
        .background(.bar)
    }

    // MARK: - Command Section

    private var commandSection: some View {
        VStack(alignment: .leading, spacing: Design.spacingLarge) {
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
        VStack(alignment: .leading, spacing: Design.spacingMedium) {
            Text("命令")
                .font(.headline)

            if isEditing {
                TextEditor(text: $quickCommand.command)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 60)
                    .padding(Design.paddingMedium)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(Design.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Design.cornerRadius)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            } else {
                HStack {
                    Text(quickCommand.command)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(Design.paddingLarge)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(Design.cornerRadius)

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
        VStack(alignment: .leading, spacing: Design.spacingLarge) {
            HStack {
                Text("组合命令")
                    .font(.headline)

                if let pipeline = linkedPipeline {
                    HStack(spacing: Design.spacingSmall) {
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
                HStack(spacing: Design.spacingSmall) {
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
                            .padding(.vertical, Design.paddingXS)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(Design.cornerRadiusSmall)
                    }
                }
            }

            // 预设参数
            VStack(alignment: .leading, spacing: Design.spacingSmall) {
                Text("预设参数")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: Design.spacingTight) {
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
                .padding(Design.paddingMedium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(Design.cornerRadiusMedium)
            }
        }
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: Design.spacingLarge) {
            Text("自动执行")
                .font(.headline)

            VStack(alignment: .leading, spacing: Design.spacingXL) {
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
            .padding(Design.paddingLarge)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(Design.cornerRadius)
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
        VStack(alignment: .leading, spacing: Design.spacingLarge) {
            HStack {
                Text("输出")
                    .font(.headline)

                Spacer()

                if let code = currentExitCode {
                    HStack(spacing: Design.spacingSmall) {
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
                VStack(alignment: .leading, spacing: Design.spacingSmall) {
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
                    .padding(Design.paddingMedium)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(Design.cornerRadius)
                }
            }

            // stderr
            if !currentErrorOutput.isEmpty {
                VStack(alignment: .leading, spacing: Design.spacingSmall) {
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
                    .padding(Design.paddingMedium)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(Design.cornerRadius)
                }
            }
        }
    }

    // MARK: - Execution History

    private var executionHistorySection: some View {
        VStack(alignment: .leading, spacing: Design.spacingLarge) {
            Text("执行历史")
                .font(.headline)

            VStack(spacing: Design.spacingSmall) {
                ForEach(recentExecutions) { exec in
                    VStack(alignment: .leading, spacing: Design.spacingSmall) {
                        HStack {
                            // Status icon
                            Image(systemName: exec.status == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(exec.status == .success ? .green : .red)
                                .font(.caption)

                            // Time
                            Text(exec.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)

                            Spacer()

                            // Exit code
                            if let code = exec.exitCode {
                                Text("退出码: \(code)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            // Duration
                            Text(exec.durationText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            // Expand toggle
                            Image(systemName: expandedExecutionId == exec.id ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                expandedExecutionId = expandedExecutionId == exec.id ? nil : exec.id
                            }
                        }

                        // Expanded output
                        if expandedExecutionId == exec.id {
                            VStack(alignment: .leading, spacing: Design.spacingSmall) {
                                if !exec.stdout.isEmpty {
                                    Text(String(exec.stdout.prefix(500)))
                                        .font(.system(.caption2, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                if !exec.stderr.isEmpty {
                                    Text(String(exec.stderr.prefix(300)))
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.red)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(Design.paddingMedium)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(Design.cornerRadiusSmall)
                        }
                    }
                    .padding(.horizontal, Design.paddingMedium)
                    .padding(.vertical, Design.paddingSmall)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(Design.cornerRadiusSmall)
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

        // 创建执行记录
        let execution = Execution(
            actionId: taskId,
            actionName: quickCommand.name,
            command: taskType == .command ? command : "pipeline:\(quickCommand.name)",
            status: .running
        )
        modelContext.insert(execution)
        saveContext(modelContext)

        switch taskType {
        case .command:
            do {
                _ = try await commandRunner.run(command)
                execution.stdout = commandRunner.output
                execution.stderr = commandRunner.errorOutput
                execution.exitCode = commandRunner.exitCode
                execution.status = (commandRunner.exitCode ?? -1) == 0 ? .success : .failed
                execution.finishedAt = Date()
                saveContext(modelContext)
                updateLastRunAt(taskId: taskId)
            } catch {
                execution.stderr = error.localizedDescription
                execution.status = .failed
                execution.finishedAt = Date()
                saveContext(modelContext)
                print("执行失败: \(error)")
            }

        case .pipeline:
            guard let pipeline = linkedPipeline,
                  let input = quickCommand.presetInput else {
                execution.stderr = "Pipeline 配置无效"
                execution.status = .failed
                execution.finishedAt = Date()
                saveContext(modelContext)
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
                execution.stdout = pipelineRunner.output
                execution.stderr = pipelineRunner.errorOutput
                execution.status = pipelineRunner.errorOutput.isEmpty ? .success : .failed
                execution.finishedAt = Date()
                saveContext(modelContext)
                updateLastRunAt(taskId: taskId)
            } catch {
                execution.stderr = error.localizedDescription
                execution.status = .failed
                execution.finishedAt = Date()
                saveContext(modelContext)
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
