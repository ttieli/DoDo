import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ActionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let action: Action
    var onDelete: (() -> Void)?

    @StateObject private var runner = CommandRunner()
    @StateObject private var batchRunner = BatchRunner()

    // 参数状态
    @State private var inputValue = ""
    @State private var inputFiles: [URL] = []
    @State private var outputValue = ""
    @State private var optionValues: [String: String] = [:]
    @State private var boolOptions: Set<String> = []

    // 批量模式状态
    @State private var batchMode: BatchInputMode = .single
    @State private var batchInputs: [String] = []
    @State private var batchOutputDirectory: String = ""
    @State private var useSameDirectory = true

    // UI 状态
    @State private var showingFilePicker = false
    @State private var showingBatchSheet = false
    @State private var showingOutputPicker = false
    @State private var showingConfig = false
    @State private var configText = ""
    @State private var configError: String?
    @State private var showingDeleteConfirm = false
    @State private var showingSaveAsQuickCommand = false
    @State private var quickCommandName = ""

    var body: some View {
        VStack(spacing: 0) {
            // 标题区
            headerSection

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 输入区
                    inputSection

                    // 输出目录区
                    if action.outputConfig != nil {
                        outputSection
                    }

                    // 选项区
                    if !action.options.isEmpty {
                        optionsSection
                    }

                    // 命令预览
                    commandPreviewSection

                    // 执行按钮区
                    executeSection

                    // 输出区
                    if batchMode == .multiple && (!batchRunner.execution.items.isEmpty || batchRunner.execution.isRunning) {
                        // 批量执行结果
                        batchResultSection
                    } else if !runner.output.isEmpty || !runner.errorOutput.isEmpty || runner.isRunning {
                        // 单项执行结果
                        outputResultSection
                    }

                    // 配置查看区
                    configSection
                }
                .padding()
            }
        }
        .onAppear {
            resetState()
        }
        .onChange(of: action.id) { _, _ in
            resetState()
        }
    }

    // MARK: - 标题区

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(action.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(action.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if onDelete != nil {
                Button(action: { showingDeleteConfirm = true }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("删除此命令")
            }
        }
        .padding()
        .background(.bar)
        .confirmationDialog("确定删除 \(action.name) 吗？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                // 删除 iCloud 配置文件
                try? ConfigManager.shared.deleteConfig(name: action.name)
                // 调用删除回调
                onDelete?()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销")
        }
    }

    // MARK: - 输入区

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 使用 BatchInputView
            BatchInputView(
                singleInput: $inputValue,
                batchInputs: $batchInputs,
                mode: $batchMode,
                inputLabel: action.inputConfig.label,
                placeholder: action.inputConfig.placeholder ?? placeholderForInputType,
                allowedExtensions: allowedExtensionsForInput
            )
        }
    }

    private var placeholderForInputType: String {
        switch action.inputConfig.type {
        case .file: return "选择文件..."
        case .directory: return "选择目录..."
        case .url: return "https://..."
        case .string: return "输入内容..."
        }
    }

    private var allowedExtensionsForInput: [String] {
        action.supportedInputFormats.map { $0.rawValue }
    }


    // MARK: - 输出区

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let outputConfig = action.outputConfig {
                Label(outputConfig.label, systemImage: "folder.badge.plus")
                    .font(.headline)

                // 批量模式：选择输出目录方式
                if batchMode == .multiple {
                    batchOutputSection
                } else {
                    // 单项模式：原有逻辑
                    singleOutputSection(outputConfig: outputConfig)
                }
            }
        }
    }

    private func singleOutputSection(outputConfig: OutputConfig) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                TextEditor(text: $outputValue)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 40, maxHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )

                if outputValue.isEmpty {
                    Text(outputConfig.defaultValue ?? "输出目录（可选）")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Button("选择...") {
                if action.commandMode == .pipe {
                    showSavePanel()
                } else {
                    showingOutputPicker = true
                }
            }
            .padding(.top, 8)
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

    private var batchOutputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 输出目录选择
            HStack {
                Text("输出目录:")
                    .foregroundStyle(.secondary)

                Picker("", selection: $useSameDirectory) {
                    Text("同输入目录").tag(true)
                    Text("指定目录").tag(false)
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
            }

            // 指定目录时显示路径选择
            if !useSameDirectory {
                HStack {
                    TextField("输出目录", text: $batchOutputDirectory)
                        .textFieldStyle(.roundedBorder)

                    Button("选择...") {
                        selectBatchOutputDirectory()
                    }
                }
            }
        }
    }

    private func selectBatchOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            batchOutputDirectory = url.path
        }
    }

    // MARK: - 选项区

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("选项", systemImage: "slider.horizontal.3")
                .font(.headline)

            // 布尔和枚举选项放在 Grid 里
            let boolAndEnumOptions = action.options.filter { $0.type == .bool || $0.type == .enum }
            if !boolAndEnumOptions.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 200), spacing: 12)
                ], spacing: 12) {
                    ForEach(boolAndEnumOptions) { option in
                        optionView(for: option)
                    }
                }
            }

            // 字符串选项单独占满宽度
            let stringOptions = action.options.filter { $0.type == .string }
            ForEach(stringOptions) { option in
                optionView(for: option)
            }
        }
    }

    @ViewBuilder
    private func optionView(for option: ActionOption) -> some View {
        switch option.type {
        case .bool:
            Toggle(option.label, isOn: Binding(
                get: { boolOptions.contains(option.flag) },
                set: { newValue in
                    if newValue {
                        boolOptions.insert(option.flag)
                    } else {
                        boolOptions.remove(option.flag)
                    }
                }
            ))
            .toggleStyle(.checkbox)

        case .enum:
            HStack {
                Text(option.label)
                    .frame(width: 80, alignment: .leading)
                Picker("", selection: Binding(
                    get: { optionValues[option.flag] ?? option.defaultValue ?? "" },
                    set: { optionValues[option.flag] = $0 }
                )) {
                    Text("默认").tag("")
                    ForEach(option.choices ?? [], id: \.self) { choice in
                        Text(choice).tag(choice)
                    }
                }
                .labelsHidden()
            }

        case .string:
            VStack(alignment: .leading, spacing: 4) {
                Text(option.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: Binding(
                    get: { optionValues[option.flag] ?? option.defaultValue ?? "" },
                    set: { optionValues[option.flag] = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 60, maxHeight: 150)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if (optionValues[option.flag] ?? "").isEmpty {
                        Text(option.placeholder ?? "")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    // MARK: - 命令预览

    private var commandPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("命令预览", systemImage: "terminal")
                    .font(.headline)

                Spacer()

                // 复制按钮
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(buildCommand(), forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("复制命令")
            }

            Text(buildCommand())
                .font(.system(.body, design: .monospaced))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .textSelection(.enabled)
        }
    }

    // MARK: - 执行区

    private var executeSection: some View {
        HStack {
            if batchMode == .multiple {
                // 批量执行按钮
                Button(action: executeBatch) {
                    Label(
                        batchRunner.execution.isRunning ? "执行中..." : "批量执行 (\(batchInputs.count))",
                        systemImage: batchRunner.execution.isRunning ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(batchInputs.isEmpty)
            } else {
                // 单项执行按钮
                Button(action: execute) {
                    Label(
                        runner.isRunning ? "执行中..." : "执行",
                        systemImage: runner.isRunning ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputValue.isEmpty && inputFiles.isEmpty)
            }

            // 保存为定时任务（仅单项模式）
            if batchMode == .single {
                Button {
                    quickCommandName = "\(action.label)"
                    showingSaveAsQuickCommand = true
                } label: {
                    Label("保存为定时任务", systemImage: "clock.badge.plus")
                }
                .buttonStyle(.bordered)
                .disabled(inputValue.isEmpty && inputFiles.isEmpty)
            }

            Spacer()

            if runner.isRunning {
                Button("取消") {
                    runner.cancel()
                }
                .buttonStyle(.bordered)
            }

            if batchRunner.execution.isRunning {
                Button("取消") {
                    batchRunner.cancel()
                }
                .buttonStyle(.bordered)
            }
        }
        .sheet(isPresented: $showingSaveAsQuickCommand) {
            SaveAsQuickCommandSheet(
                name: $quickCommandName,
                command: buildCommand(),
                sourceName: action.name
            )
        }
    }

    // MARK: - 批量结果区

    private var batchResultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            BatchCommandResultView(execution: batchRunner.execution) { item in
                // 选中项时可以展开查看详情
            }

            // 选中项的详细输出
            if let selectedItem = batchRunner.execution.selectedItem,
               let result = selectedItem.result,
               !result.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("详细输出")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ScrollView {
                        Text(result)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(maxHeight: 150)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - 输出结果区

    private var outputResultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("输出", systemImage: "text.alignleft")
                    .font(.headline)

                Spacer()

                if let exitCode = runner.exitCode {
                    HStack(spacing: 4) {
                        Image(systemName: exitCode == 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                        Text(exitCode == 0 ? "成功" : "失败 (exit \(exitCode))")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(exitCode == 0 ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(exitCode == 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    )
                }

                if runner.isRunning {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("执行中...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // 清除输出按钮
                if !runner.output.isEmpty || !runner.errorOutput.isEmpty {
                    Button(action: {
                        runner.output = ""
                        runner.errorOutput = ""
                        runner.exitCode = nil
                    }) {
                        Image(systemName: "trash")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("清除输出")
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
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

                        // 用于自动滚动到底部的锚点
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(12)
                }
                .frame(minHeight: 150, maxHeight: 400)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
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

    // MARK: - 配置区

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation {
                    showingConfig.toggle()
                    if showingConfig && configText.isEmpty {
                        loadConfigText()
                    }
                }
            }) {
                HStack {
                    Image(systemName: showingConfig ? "chevron.down" : "chevron.right")
                        .frame(width: 12)
                    Label("查看配置", systemImage: "doc.text")
                        .font(.headline)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            if showingConfig {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $configText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 200, maxHeight: 300)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )

                    if let error = configError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    HStack {
                        Button("复制") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(configText, forType: .string)
                        }
                        .buttonStyle(.bordered)

                        Button("重置") {
                            loadConfigText()
                            configError = nil
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("保存修改") {
                            saveConfig()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 8)
    }

    private func loadConfigText() {
        let config = ActionConfig.from(action)
        if let json = try? ConfigManager.shared.configToJSON(config) {
            configText = json
        }
    }

    private func saveConfig() {
        configError = nil

        do {
            let config = try ConfigManager.shared.parseConfig(from: configText)

            // 更新当前 action
            action.name = config.name
            action.label = config.label
            action.command = config.command

            // 更新 inputConfig
            let inputType: InputConfig.InputType
            switch config.input.type.lowercased() {
            case "file": inputType = .file
            case "directory": inputType = .directory
            case "url": inputType = .url
            default: inputType = .string
            }
            action.inputConfig = InputConfig(
                type: inputType,
                label: config.input.label,
                allowMultiple: config.input.allowMultiple ?? false,
                placeholder: config.input.placeholder
            )

            // 更新 outputConfig
            if let out = config.output {
                action.outputConfig = OutputConfig(
                    flag: out.flag,
                    label: out.label,
                    defaultValue: out.default
                )
            } else {
                action.outputConfig = nil
            }

            // 更新 options
            var newOptions: [ActionOption] = []
            if let opts = config.options {
                for opt in opts {
                    let optType: ActionOption.OptionType
                    switch opt.type.lowercased() {
                    case "bool": optType = .bool
                    case "enum": optType = .enum
                    default: optType = .string
                    }
                    newOptions.append(ActionOption(
                        flag: opt.flag,
                        type: optType,
                        label: opt.label,
                        choices: opt.choices,
                        defaultValue: opt.default,
                        placeholder: opt.placeholder
                    ))
                }
            }
            action.options = newOptions
            action.updatedAt = Date()

            // 保存到 iCloud
            try ConfigManager.shared.saveConfig(config, name: config.name)

            saveContext(modelContext)
        } catch {
            configError = "保存失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 方法

    private func resetState() {
        inputValue = ""
        inputFiles = []
        outputValue = action.outputConfig?.defaultValue ?? ""
        optionValues = [:]
        boolOptions = []

        // 重置批量状态
        batchMode = .single
        batchInputs = []
        batchOutputDirectory = ""
        useSameDirectory = true
        batchRunner.reset()

        // 设置默认值
        for option in action.options {
            if option.type == .bool, option.defaultValue == "true" {
                boolOptions.insert(option.flag)
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            inputFiles = urls
            if let first = urls.first {
                inputValue = first.path
            }
        case .failure(let error):
            print("选择文件失败: \(error)")
        }
    }

    private func showSavePanel() {
        let panel = NSSavePanel()
        panel.title = "选择输出文件"
        panel.nameFieldStringValue = "output.md"
        panel.canCreateDirectories = true

        // 根据支持的输出格式设置默认扩展名
        if let firstFormat = action.supportedOutputFormats.first {
            panel.nameFieldStringValue = "output.\(firstFormat.format.rawValue)"
            // 允许的文件类型
            if let utType = UTType(filenameExtension: firstFormat.format.rawValue) {
                panel.allowedContentTypes = [utType]
            }
        }

        if panel.runModal() == .OK, let url = panel.url {
            outputValue = url.path
        }
    }

    private func buildCommand() -> String {
        var options: [(flag: String, value: String?)] = []

        // 添加 bool 选项
        for flag in boolOptions {
            options.append((flag, nil))
        }

        // 添加其他选项
        for (flag, value) in optionValues where !value.isEmpty {
            options.append((flag, value))
        }

        return CommandRunner.buildCommand(
            base: action.command,
            input: inputValue,
            output: outputValue.isEmpty ? nil : outputValue,
            outputFlag: action.outputConfig?.flag,
            options: options,
            mode: action.commandMode
        )
    }

    private func execute() {
        if runner.isRunning {
            runner.cancel()
            return
        }

        let command = buildCommand()

        // 保存执行记录
        let execution = Execution(
            actionId: action.id,
            actionName: action.name,
            command: command,
            status: .running
        )
        modelContext.insert(execution)

        Task {
            do {
                let (stdout, stderr, exitCode) = try await runner.run(command)

                // 更新执行记录
                execution.stdout = stdout
                execution.stderr = stderr
                execution.exitCode = exitCode
                execution.status = exitCode == 0 ? .success : .failed
                execution.finishedAt = Date()

                saveContext(modelContext)
            } catch {
                execution.stderr = error.localizedDescription
                execution.status = .failed
                execution.finishedAt = Date()
                saveContext(modelContext)
            }
        }
    }

    private func executeBatch() {
        if batchRunner.execution.isRunning {
            batchRunner.cancel()
            return
        }

        // 确定输出扩展名
        let outputExtension = action.supportedOutputFormats.first?.format.rawValue ?? "txt"

        // 确定输出目录
        let outputDir: String? = useSameDirectory ? nil : (batchOutputDirectory.isEmpty ? nil : batchOutputDirectory)

        Task {
            await batchRunner.runCommands(
                inputs: batchInputs,
                buildCommand: { [self] input, output in
                    // 构建单个命令
                    var options: [(flag: String, value: String?)] = []

                    for flag in boolOptions {
                        options.append((flag, nil))
                    }

                    for (flag, value) in optionValues where !value.isEmpty {
                        options.append((flag, value))
                    }

                    return CommandRunner.buildCommand(
                        base: action.command,
                        input: input,
                        output: output,
                        outputFlag: action.outputConfig?.flag,
                        options: options,
                        mode: action.commandMode
                    )
                },
                outputDirectory: outputDir,
                outputExtension: outputExtension
            )
        }
    }
}

#Preview {
    ActionDetailView(action: BuiltInConfigs.all.first!)
        .modelContainer(for: [Action.self, Execution.self], inMemory: true)
        .frame(width: 600, height: 700)
}
