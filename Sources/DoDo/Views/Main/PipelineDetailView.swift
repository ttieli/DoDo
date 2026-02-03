import SwiftUI
import SwiftData

/// Pipeline 详情视图
struct PipelineDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Action.name) private var actions: [Action]
    @Bindable var pipeline: Pipeline
    var onDelete: (() -> Void)?

    @StateObject private var runner = PipelineRunner()

    @State private var inputValue = ""
    @State private var outputValue = ""
    @State private var showingFilePicker = false
    @State private var showingOutputPicker = false
    @State private var showingDeleteConfirm = false
    @State private var selectedFinalFormat: OutputFormatConfig?
    @State private var showingSaveAsQuickCommand = false
    @State private var quickCommandName = ""
    @State private var isEditing = false

    /// 最后一步的 Action
    private var lastAction: Action? {
        guard let lastStepName = pipeline.steps.last else { return nil }
        return actions.first(where: { $0.name == lastStepName })
    }

    /// 最后一步可选的输出格式
    private var finalOutputFormats: [OutputFormatConfig] {
        lastAction?.supportedOutputFormats ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题区
            headerSection

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Design.spacingSection) {
                    // 流程说明
                    pipelineStepsSection

                    // 输入区
                    inputSection

                    // 输出目录
                    outputSection

                    // 执行按钮
                    executeSection

                    // 输出结果
                    if !runner.output.isEmpty || !runner.errorOutput.isEmpty || runner.isRunning {
                        outputResultSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: runner.isRunning)
                .padding()
            }
        }
        .focusedSceneValue(\.copyablePageText, pageTextForCopy)
    }

    /// 页面全部文本（用于 Cmd+Shift+A 复制）
    private var pageTextForCopy: String {
        var parts: [String] = []
        parts.append("[\(pipeline.name)] \(pipeline.label)")
        parts.append("步骤: \(pipeline.steps.joined(separator: " → "))")
        if !inputValue.isEmpty { parts.append("输入: \(inputValue)") }
        if !outputValue.isEmpty { parts.append("输出目录: \(outputValue)") }
        if !runner.output.isEmpty { parts.append("标准输出:\n\(runner.output)") }
        if !runner.errorOutput.isEmpty { parts.append("错误输出:\n\(runner.errorOutput)") }
        return parts.joined(separator: "\n\n")
    }

    // MARK: - 标题区

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: Design.spacingSmall) {
                HStack(spacing: Design.spacingMedium) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(.orange)
                    if isEditing {
                        TextField("名称", text: $pipeline.name)
                            .textFieldStyle(.roundedBorder)
                            .font(.title2)
                            .frame(maxWidth: 250)
                    } else {
                        Text(pipeline.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }
                if isEditing {
                    TextField("标签", text: $pipeline.label)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                        .frame(maxWidth: 250)
                } else {
                    Text(pipeline.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()

            HStack(spacing: Design.spacingLarge) {
                Button {
                    isEditing.toggle()
                    if !isEditing {
                        pipeline.updatedAt = Date()
                        saveContext(modelContext)
                    }
                } label: {
                    Image(systemName: isEditing ? "checkmark" : "pencil")
                }
                .buttonStyle(.bordered)
                .help(isEditing ? "完成编辑" : "编辑步骤")

                if onDelete != nil {
                    Button(action: { showingDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("删除此组合")
                }
            }
        }
        .padding()
        .background(.bar)
        .confirmationDialog("确定删除 \(pipeline.name) 吗？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                onDelete?()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销")
        }
    }

    // MARK: - 流程说明

    private var pipelineStepsSection: some View {
        VStack(alignment: .leading, spacing: Design.spacingMedium) {
            Label("执行流程", systemImage: "arrow.right.circle")
                .font(.headline)

            if isEditing {
                pipelineEditorView
            } else {
                PipelineFlowView(
                    pipeline: pipeline,
                    actions: Array(actions),
                    currentStep: runner.currentStep,
                    totalSteps: runner.totalSteps,
                    isRunning: runner.isRunning,
                    hasError: !runner.errorOutput.isEmpty
                )
            }

            if isEditing {
                Toggle("自动清理中间文件", isOn: $pipeline.cleanupIntermediates)
                    .font(.caption)
                    .onChange(of: pipeline.cleanupIntermediates) {
                        saveContext(modelContext)
                    }
            } else if pipeline.cleanupIntermediates {
                HStack(spacing: Design.spacingSmall) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text("执行完成后自动清理中间文件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Pipeline Editor

    private var pipelineEditorView: some View {
        VStack(spacing: Design.spacingSmall) {
            // Step list
            ForEach(Array(pipeline.pipelineSteps.enumerated()), id: \.element.id) { index, step in
                HStack(spacing: Design.spacingMedium) {
                    // Step number
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(width: 20, height: 20)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(10)

                    // Action picker
                    Picker("", selection: Binding(
                        get: { step.actionName },
                        set: { newName in
                            if let idx = pipeline.pipelineSteps.firstIndex(where: { $0.id == step.id }) {
                                pipeline.pipelineSteps[idx].actionName = newName
                                saveContext(modelContext)
                            }
                        }
                    )) {
                        ForEach(actions) { action in
                            Text("\(action.name) - \(action.label)")
                                .tag(action.name)
                        }
                    }
                    .frame(maxWidth: 250)

                    // Format compatibility indicator
                    if index > 0 {
                        let prevAction = actions.first(where: { $0.name == pipeline.pipelineSteps[index - 1].actionName })
                        let currAction = actions.first(where: { $0.name == step.actionName })
                        if let prev = prevAction, let curr = currAction {
                            if prev.compatibleOutputFormats(for: curr).isEmpty {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                                    .help("格式不兼容")
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    }

                    Spacer()

                    // Move buttons
                    Button {
                        guard index > 0 else { return }
                        pipeline.pipelineSteps.swapAt(index, index - 1)
                        saveContext(modelContext)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(index == 0)

                    Button {
                        guard index < pipeline.pipelineSteps.count - 1 else { return }
                        pipeline.pipelineSteps.swapAt(index, index + 1)
                        saveContext(modelContext)
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(index == pipeline.pipelineSteps.count - 1)

                    // Delete
                    Button {
                        pipeline.pipelineSteps.remove(at: index)
                        saveContext(modelContext)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .disabled(pipeline.pipelineSteps.count <= 1)
                }
                .padding(.horizontal, Design.paddingMedium)
                .padding(.vertical, Design.paddingSmall)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(Design.cornerRadiusSmall)
            }

            // Add step button
            Menu {
                ForEach(actions) { action in
                    Button("\(action.name) - \(action.label)") {
                        let newStep = PipelineStep(actionName: action.name)
                        pipeline.pipelineSteps.append(newStep)
                        saveContext(modelContext)
                    }
                }
            } label: {
                Label("添加步骤", systemImage: "plus.circle")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Design.paddingSmall)
        }
        .padding(Design.paddingMedium)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .cornerRadius(Design.cornerRadius)
    }

    // MARK: - 输入区

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: Design.spacingMedium) {
            // 根据第一个 step 决定输入类型
            let firstAction = actions.first(where: { $0.name == pipeline.steps.first })
            let inputLabel = firstAction?.inputConfig.label ?? "输入"
            let inputType = firstAction?.inputConfig.type ?? .string

            Label(inputLabel, systemImage: iconForInputType(inputType))
                .font(.headline)

            HStack(alignment: .top, spacing: Design.spacingMedium) {
                TextEditor(text: $inputValue)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 60, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(Design.paddingMedium)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(Design.cornerRadiusMedium)
                    .overlay(
                        RoundedRectangle(cornerRadius: Design.cornerRadiusMedium)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )

                if inputType == .file || inputType == .directory {
                    Button("选择...") {
                        showingFilePicker = true
                    }
                    .padding(.top, Design.paddingMedium)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    inputValue = url.path
                }
            }
        }
    }

    private func iconForInputType(_ type: InputConfig.InputType) -> String {
        switch type {
        case .file: return "doc"
        case .directory: return "folder"
        case .url: return "globe"
        case .string: return "text.cursor"
        }
    }

    // MARK: - 输出区

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: Design.spacingLarge) {
            // 输出格式选择（如果最后一步有多种输出格式）
            if finalOutputFormats.count > 1 {
                VStack(alignment: .leading, spacing: Design.spacingMedium) {
                    Label("输出格式", systemImage: "doc.badge.gearshape")
                        .font(.headline)

                    Picker("输出格式", selection: $selectedFinalFormat) {
                        ForEach(finalOutputFormats, id: \.format) { format in
                            Text(format.format.displayName)
                                .tag(Optional(format))
                        }
                    }
                    .pickerStyle(.segmented)
                    .onAppear {
                        if selectedFinalFormat == nil {
                            selectedFinalFormat = finalOutputFormats.first
                        }
                    }
                    .onChange(of: pipeline.steps.last) { _, _ in
                        selectedFinalFormat = finalOutputFormats.first
                    }
                }
            }

            // 输出目录
            VStack(alignment: .leading, spacing: Design.spacingMedium) {
                Label("输出目录", systemImage: "folder.badge.plus")
                    .font(.headline)

                HStack(alignment: .top, spacing: Design.spacingMedium) {
                    TextEditor(text: $outputValue)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 40, maxHeight: 80)
                        .scrollContentBackground(.hidden)
                        .padding(Design.paddingMedium)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(Design.cornerRadiusMedium)
                        .overlay(
                            RoundedRectangle(cornerRadius: Design.cornerRadiusMedium)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )

                    Button("选择...") {
                        showingOutputPicker = true
                    }
                    .padding(.top, Design.paddingMedium)
                }
                .fileImporter(
                    isPresented: $showingOutputPicker,
                    allowedContentTypes: [.folder],
                    allowsMultipleSelection: false
                ) { result in
                    if case .success(let urls) = result, let url = urls.first {
                        outputValue = url.path
                    }
                }
            }
        }
    }

    // MARK: - 执行区

    private var executeSection: some View {
        HStack {
            Button(action: execute) {
                HStack {
                    if runner.isRunning {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("执行中 (\(runner.currentStep)/\(runner.totalSteps))")
                    } else {
                        Image(systemName: "play.fill")
                        Text("执行")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputValue.isEmpty || runner.isRunning)

            if runner.isRunning {
                Button("取消") {
                    runner.cancel()
                }
                .buttonStyle(.bordered)
            }

            // 保存为定时任务
            Button {
                quickCommandName = pipeline.label
                showingSaveAsQuickCommand = true
            } label: {
                Label("保存为定时任务", systemImage: "clock.badge.plus")
            }
            .buttonStyle(.bordered)
            .disabled(inputValue.isEmpty)

            Spacer()
        }
        .sheet(isPresented: $showingSaveAsQuickCommand) {
            SaveAsPipelineQuickCommandSheet(
                name: $quickCommandName,
                pipeline: pipeline,
                presetInput: inputValue,
                presetOutput: outputValue.isEmpty ? nil : outputValue,
                presetFormatOptions: selectedFinalFormat?.requiredOptions
            )
        }
    }

    // MARK: - 输出结果

    private var outputResultSection: some View {
        VStack(alignment: .leading, spacing: Design.spacingMedium) {
            HStack {
                Label("执行输出", systemImage: "text.alignleft")
                    .font(.headline)

                Spacer()

                if runner.isRunning {
                    Text("正在执行: \(runner.currentStepName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(action: {
                    runner.output = ""
                    runner.errorOutput = ""
                }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("清除输出")
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Design.spacingMedium) {
                        if !runner.output.isEmpty {
                            Text(runner.output)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if !runner.errorOutput.isEmpty {
                            Text(runner.errorOutput)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.red)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(Design.paddingLarge)
                }
                .frame(minHeight: 200, maxHeight: 400)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(Design.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Design.cornerRadius)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .onChange(of: runner.output) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - 方法

    private func execute() {
        Task {
            do {
                _ = try await runner.run(
                    pipeline: pipeline,
                    actions: Array(actions),
                    input: inputValue,
                    finalOutput: outputValue.isEmpty ? nil : outputValue,
                    finalOutputFormat: selectedFinalFormat
                )
            } catch {
                await MainActor.run {
                    runner.errorOutput += "\n执行出错: \(error.localizedDescription)"
                }
            }
        }
    }
}
