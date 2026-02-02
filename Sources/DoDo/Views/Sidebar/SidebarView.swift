import SwiftUI
import SwiftData

/// 侧边栏选中项类型
enum SidebarSelection: Hashable {
    case action(Action)
    case pipeline(Pipeline)
    case quickCommand(QuickCommand)
    case apiEndpoint(APIEndpoint)
    case apiPipeline(APIPipeline)
}

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Action.name) private var actions: [Action]
    @Query(sort: \Pipeline.name) private var pipelines: [Pipeline]
    @Query(sort: \QuickCommand.name) private var quickCommands: [QuickCommand]
    @Query(sort: \APIEndpoint.name) private var apiEndpoints: [APIEndpoint]
    @Query(sort: \APIPipeline.name) private var apiPipelines: [APIPipeline]
    @Binding var selection: SidebarSelection?
    @Binding var importingCommand: String?
    @State private var showingImportSheet = false
    @State private var showingCommandInput = false
    @State private var showingPipelineInput = false
    @State private var showingQuickCommandInput = false
    @State private var showingAPIEndpointInput = false
    @State private var showingAPIPipelineInput = false
    @State private var newCommandName = ""

    var body: some View {
        List(selection: $selection) {
            // 组合命令
            if !pipelines.isEmpty {
                Section("组合命令") {
                    ForEach(pipelines) { pipeline in
                        PipelineRowView(pipeline: pipeline)
                            .tag(SidebarSelection.pipeline(pipeline))
                            .contextMenu {
                                Button("删除", role: .destructive) {
                                    deletePipeline(pipeline)
                                }
                            }
                    }
                }
            }

            // 单个命令
            Section("我的命令") {
                ForEach(actions) { action in
                    ActionRowView(action: action)
                        .tag(SidebarSelection.action(action))
                        .contextMenu {
                            Button("删除", role: .destructive) {
                                deleteAction(action)
                            }
                        }
                }
                .onDelete(perform: deleteActions)
            }

            // 快捷命令
            if !quickCommands.isEmpty {
                Section("快捷命令") {
                    ForEach(quickCommands) { quickCommand in
                        QuickCommandRowView(quickCommand: quickCommand)
                            .tag(SidebarSelection.quickCommand(quickCommand))
                            .contextMenu {
                                Button("删除", role: .destructive) {
                                    deleteQuickCommand(quickCommand)
                                }
                            }
                    }
                }
            }

            // API 端点
            if !apiEndpoints.isEmpty {
                Section("API") {
                    ForEach(apiEndpoints) { endpoint in
                        APIEndpointRowView(endpoint: endpoint)
                            .tag(SidebarSelection.apiEndpoint(endpoint))
                            .contextMenu {
                                Button("导出") {
                                    exportAPIEndpoint(endpoint)
                                }
                                Divider()
                                Button("删除", role: .destructive) {
                                    deleteAPIEndpoint(endpoint)
                                }
                            }
                    }
                }
            }

            // API 组合
            if !apiPipelines.isEmpty {
                Section("API 组合") {
                    ForEach(apiPipelines) { pipeline in
                        APIPipelineRowView(pipeline: pipeline)
                            .tag(SidebarSelection.apiPipeline(pipeline))
                            .contextMenu {
                                Button("导出") {
                                    exportAPIPipeline(pipeline)
                                }
                                Divider()
                                Button("删除", role: .destructive) {
                                    deleteAPIPipeline(pipeline)
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Menu {
                        Section("命令") {
                            Button {
                                showingCommandInput = true
                            } label: {
                                Label("命令", systemImage: "terminal")
                            }

                            Button {
                                showingPipelineInput = true
                            } label: {
                                Label("组合", systemImage: "arrow.triangle.branch")
                            }

                            Button {
                                showingQuickCommandInput = true
                            } label: {
                                Label("快捷", systemImage: "bolt.fill")
                            }
                        }

                        Section("API") {
                            Button {
                                showingAPIEndpointInput = true
                            } label: {
                                Label("API", systemImage: "network")
                            }

                            Button {
                                showingAPIPipelineInput = true
                            } label: {
                                Label("API 组合", systemImage: "point.3.connected.trianglepath.dotted")
                            }
                        }
                    } label: {
                        Label("添加", systemImage: "plus.circle.fill")
                            .font(.body)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(.bar)
        }
        .toolbar {
            ToolbarItem {
                Menu {
                    Button("导入配置文件...") {
                        showingImportSheet = true
                    }
                    Divider()
                    Button("重新加载内置命令") {
                        reloadBuiltIn()
                    }
                    Button("加载内置组合") {
                        loadBuiltInPipelines()
                    }
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                }
            }
        }
        .fileImporter(
            isPresented: $showingImportSheet,
            allowedContentTypes: [.json],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showingCommandInput) {
            CommandInputSheet(
                commandName: $newCommandName,
                onImport: { command in
                    selection = nil
                    importingCommand = command
                    newCommandName = ""
                }
            )
        }
        .sheet(isPresented: $showingPipelineInput) {
            PipelineInputSheet(actions: Array(actions)) { pipeline in
                modelContext.insert(pipeline)
                saveContext(modelContext)
                selection = .pipeline(pipeline)
            }
        }
        .sheet(isPresented: $showingQuickCommandInput) {
            QuickCommandInputSheet { quickCommand in
                modelContext.insert(quickCommand)
                saveContext(modelContext)
                selection = .quickCommand(quickCommand)
            }
        }
        .sheet(isPresented: $showingAPIEndpointInput) {
            APIEndpointInputSheet { endpoint in
                modelContext.insert(endpoint)
                saveContext(modelContext)
                selection = .apiEndpoint(endpoint)
            }
        }
        .sheet(isPresented: $showingAPIPipelineInput) {
            APIPipelineInputSheet(endpoints: Array(apiEndpoints)) { pipeline in
                modelContext.insert(pipeline)
                saveContext(modelContext)
                selection = .apiPipeline(pipeline)
            }
        }
    }

    private func deleteAction(_ action: Action) {
        if case .action(let selected) = selection, selected == action {
            selection = nil
        }
        modelContext.delete(action)
        saveContext(modelContext)
    }

    private func deletePipeline(_ pipeline: Pipeline) {
        if case .pipeline(let selected) = selection, selected == pipeline {
            selection = nil
        }
        modelContext.delete(pipeline)
        saveContext(modelContext)
    }

    private func deleteQuickCommand(_ quickCommand: QuickCommand) {
        if case .quickCommand(let selected) = selection, selected == quickCommand {
            selection = nil
        }
        modelContext.delete(quickCommand)
        saveContext(modelContext)
    }

    private func deleteAPIEndpoint(_ endpoint: APIEndpoint) {
        if case .apiEndpoint(let selected) = selection, selected == endpoint {
            selection = nil
        }
        modelContext.delete(endpoint)
        saveContext(modelContext)
    }

    private func deleteAPIPipeline(_ pipeline: APIPipeline) {
        if case .apiPipeline(let selected) = selection, selected == pipeline {
            selection = nil
        }
        modelContext.delete(pipeline)
        saveContext(modelContext)
    }

    private func exportAPIEndpoint(_ endpoint: APIEndpoint) {
        let exportData = APIExportWrapper(
            version: "1.0",
            type: "api_endpoints",
            data: [endpoint.toExportData()]
        )

        guard let jsonData = try? JSONEncoder().encode(exportData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(endpoint.name).json"
        panel.allowedContentTypes = [.json]

        if panel.runModal() == .OK, let url = panel.url {
            try? jsonString.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func exportAPIPipeline(_ pipeline: APIPipeline) {
        let exportData = APIPipelineExportWrapper(
            version: "1.0",
            type: "api_pipelines",
            data: [pipeline.toExportData()]
        )

        guard let jsonData = try? JSONEncoder().encode(exportData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(pipeline.name).json"
        panel.allowedContentTypes = [.json]

        if panel.runModal() == .OK, let url = panel.url {
            try? jsonString.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func deleteActions(at offsets: IndexSet) {
        for index in offsets {
            let action = actions[index]
            if case .action(let selected) = selection, selected == action {
                selection = nil
            }
            modelContext.delete(action)
        }
        saveContext(modelContext)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                do {
                    let action = try ConfigLoader.loadFromFile(url)
                    modelContext.insert(action)
                } catch {
                    print("导入失败: \(error)")
                }
            }
            saveContext(modelContext)

        case .failure(let error):
            print("选择文件失败: \(error)")
        }
    }

    private func reloadBuiltIn() {
        let builtInNames = Set(BuiltInConfigs.all.map { $0.name })
        for action in actions where builtInNames.contains(action.name) {
            modelContext.delete(action)
        }

        for action in BuiltInConfigs.all {
            modelContext.insert(action)
        }

        saveContext(modelContext)
    }

    private func loadBuiltInPipelines() {
        let builtInPipelines = BuiltInPipelines.all
        let existingNames = Set(pipelines.map { $0.name })

        for pipeline in builtInPipelines where !existingNames.contains(pipeline.name) {
            modelContext.insert(pipeline)
        }

        saveContext(modelContext)
    }
}

/// 命令行视图
struct ActionRowView: View {
    let action: Action

    var body: some View {
        HStack {
            Image(systemName: iconForAction(action))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(action.name)
                    .font(.body)
                Text(action.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func iconForAction(_ action: Action) -> String {
        switch action.inputConfig.type {
        case .file: return "doc"
        case .directory: return "folder"
        case .url: return "globe"
        case .string: return "terminal"
        }
    }
}

/// Pipeline 行视图
struct PipelineRowView: View {
    let pipeline: Pipeline

    var body: some View {
        HStack {
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(.orange)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(pipeline.name)
                    .font(.body)
                Text(pipeline.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// 命令输入弹窗
struct CommandInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var commandName: String
    var onImport: (String) -> Void

    @State private var errorMessage: String?
    @State private var isChecking = false

    var body: some View {
        VStack(spacing: 16) {
            Text("导入新命令")
                .font(.headline)

            TextField("输入命令名称", text: $commandName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
                .onSubmit {
                    checkAndImport()
                }

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Text("例如: ffmpeg, pandoc, magick")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("导入") {
                    checkAndImport()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(commandName.isEmpty || isChecking)
            }
        }
        .padding(24)
        .frame(width: 320)
    }

    private func checkAndImport() {
        let cmd = commandName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }

        isChecking = true
        errorMessage = nil

        DispatchQueue.global().async {
            let exists = HelpParser.shared.commandExists(cmd)

            DispatchQueue.main.async {
                isChecking = false
                if exists {
                    dismiss()
                    onImport(cmd)
                } else {
                    errorMessage = "命令 '\(cmd)' 不存在，请检查是否已安装"
                }
            }
        }
    }
}

/// Pipeline 输入弹窗
struct PipelineInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    let actions: [Action]
    var onCreate: (Pipeline) -> Void

    @State private var name = ""
    @State private var label = ""
    @State private var pipelineSteps: [PipelineStep] = []
    @State private var cleanupIntermediates = true
    @State private var showingFormatPicker = false
    @State private var pendingAction: Action?
    @State private var compatibleFormats: [OutputFormatConfig] = []

    private var actionsDict: [String: Action] {
        Dictionary(uniqueKeysWithValues: actions.map { ($0.name, $0) })
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("创建组合命令")
                .font(.headline)

            Form {
                TextField("名称", text: $name)
                TextField("中文标签", text: $label)

                Section("选择步骤（按顺序）") {
                    ForEach(actions) { action in
                        HStack {
                            if let index = pipelineSteps.firstIndex(where: { $0.actionName == action.name }) {
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(Circle())
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(action.name)
                                    Text(action.label)
                                        .foregroundStyle(.secondary)
                                }
                                // 显示格式信息
                                if !action.supportedInputFormats.isEmpty || !action.supportedOutputFormats.isEmpty {
                                    HStack(spacing: 4) {
                                        if !action.supportedInputFormats.isEmpty {
                                            Text("入:")
                                                .foregroundStyle(.secondary)
                                            Text(action.supportedInputFormats.map { $0.rawValue }.joined(separator: "/"))
                                                .foregroundStyle(.green)
                                        }
                                        if !action.supportedOutputFormats.isEmpty {
                                            Text("出:")
                                                .foregroundStyle(.secondary)
                                            Text(action.supportedOutputFormats.map { $0.format.rawValue }.joined(separator: "/"))
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    .font(.caption2)
                                }
                            }

                            Spacer()

                            let isSelected = pipelineSteps.contains { $0.actionName == action.name }
                            Button(isSelected ? "移除" : "添加") {
                                if isSelected {
                                    pipelineSteps.removeAll { $0.actionName == action.name }
                                } else {
                                    addStep(action)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                if !pipelineSteps.isEmpty {
                    Section("执行顺序") {
                        ForEach(Array(pipelineSteps.enumerated()), id: \.element.id) { index, step in
                            HStack {
                                Text("\(index + 1). \(step.actionName)")
                                if let format = step.outputFormat {
                                    Text("→ \(format.displayName)")
                                        .foregroundStyle(.orange)
                                }
                                if !step.extraOptions.isEmpty {
                                    Text("(\(step.extraOptions.joined(separator: " ")))")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                            .font(.caption)
                        }
                    }
                }

                Toggle("自动清理中间文件", isOn: $cleanupIntermediates)
            }
            .frame(width: 450, height: 350)

            HStack(spacing: 12) {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("创建") {
                    let pipeline = Pipeline(
                        name: name,
                        label: label,
                        pipelineSteps: pipelineSteps,
                        cleanupIntermediates: cleanupIntermediates
                    )
                    dismiss()
                    onCreate(pipeline)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || label.isEmpty || pipelineSteps.count < 2)
            }
        }
        .padding(24)
        .sheet(isPresented: $showingFormatPicker) {
            FormatPickerSheet(
                action: pendingAction!,
                formats: compatibleFormats,
                onSelect: { format in
                    let step = PipelineStep(
                        actionName: pendingAction!.name,
                        outputFormat: format.format,
                        extraOptions: format.requiredOptions
                    )
                    pipelineSteps.append(step)
                    pendingAction = nil
                    compatibleFormats = []
                }
            )
        }
    }

    private func addStep(_ action: Action) {
        // 第一步：直接添加，不需要检查兼容性
        if pipelineSteps.isEmpty {
            // 如果有多种输出格式，让用户选择
            if action.supportedOutputFormats.count > 1 {
                pendingAction = action
                compatibleFormats = action.supportedOutputFormats
                showingFormatPicker = true
            } else {
                let format = action.supportedOutputFormats.first
                let step = PipelineStep(
                    actionName: action.name,
                    outputFormat: format?.format,
                    extraOptions: format?.requiredOptions ?? []
                )
                pipelineSteps.append(step)
            }
            return
        }

        // 后续步骤：检查与前一步的格式兼容性
        guard let lastStep = pipelineSteps.last,
              let lastAction = actionsDict[lastStep.actionName] else {
            return
        }

        // 获取兼容的输出格式
        let compatible = lastAction.compatibleOutputFormats(for: action)

        if compatible.isEmpty {
            // 没有兼容格式，显示警告但仍允许添加
            let step = PipelineStep(actionName: action.name)
            pipelineSteps.append(step)
        } else if compatible.count == 1 {
            // 只有一种兼容格式，自动选择
            let format = compatible[0]
            // 更新前一步的输出格式
            if var lastStep = pipelineSteps.last {
                lastStep.outputFormat = format.format
                lastStep.extraOptions = format.requiredOptions
                pipelineSteps[pipelineSteps.count - 1] = lastStep
            }
            // 添加新步骤
            let step = PipelineStep(actionName: action.name)
            pipelineSteps.append(step)
        } else {
            // 多种兼容格式，让用户选择
            pendingAction = action
            compatibleFormats = compatible
            showingFormatPicker = true
        }
    }
}

/// 格式选择弹窗
struct FormatPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let action: Action
    let formats: [OutputFormatConfig]
    var onSelect: (OutputFormatConfig) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("选择输出格式")
                .font(.headline)

            Text("添加 \(action.name) 需要选择前一步的输出格式")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(formats, id: \.format) { format in
                    Button {
                        dismiss()
                        onSelect(format)
                    } label: {
                        HStack {
                            Text(format.format.displayName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if !format.requiredOptions.isEmpty {
                                Text(format.requiredOptions.joined(separator: " "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 250)

            Button("取消") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(24)
    }
}

/// 快捷命令行视图
struct QuickCommandRowView: View {
    let quickCommand: QuickCommand

    var body: some View {
        HStack {
            // 根据类型显示不同图标
            Group {
                if quickCommand.type == .pipeline {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.purple)
                }
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(quickCommand.name)
                        .font(.body)

                    // 显示调度标记
                    if quickCommand.runOnLaunch || quickCommand.repeatInterval != nil {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }

                if quickCommand.type == .command {
                    Text(quickCommand.command)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let input = quickCommand.presetInput {
                    Text(input)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// 快捷命令输入弹窗
struct QuickCommandInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (QuickCommand) -> Void

    @State private var name = ""
    @State private var command = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("添加快捷命令")
                .font(.headline)

            Form {
                TextField("名称", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("命令", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }
            .frame(width: 350)

            Text("例如: npm i -g @anthropic-ai/claude-code")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("添加") {
                    let quickCommand = QuickCommand(name: name, command: command)
                    dismiss()
                    onCreate(quickCommand)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || command.isEmpty)
            }
        }
        .padding(24)
    }
}

/// API 端点行视图
struct APIEndpointRowView: View {
    let endpoint: APIEndpoint

    var body: some View {
        HStack {
            Image(systemName: "network")
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(endpoint.name.isEmpty ? "未命名" : endpoint.name)
                    .font(.body)

                Text("\(endpoint.methodRaw) \(endpoint.url)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

/// API 组合行视图
struct APIPipelineRowView: View {
    let pipeline: APIPipeline

    var body: some View {
        HStack {
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(.cyan)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(pipeline.name.isEmpty ? "未命名" : pipeline.name)
                    .font(.body)

                Text("\(pipeline.steps.count) 个步骤")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// API 端点输入弹窗
struct APIEndpointInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (APIEndpoint) -> Void

    @State private var name = ""
    @State private var url = ""
    @State private var method: HTTPMethod = .GET

    var body: some View {
        VStack(spacing: 16) {
            Text("添加 API")
                .font(.headline)

            Form {
                TextField("名称", text: $name)
                    .textFieldStyle(.roundedBorder)

                Picker("方法", selection: $method) {
                    ForEach(HTTPMethod.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }

                TextField("URL", text: $url)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(width: 350)

            Text("创建后可在详情页配置认证和参数")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("添加") {
                    let endpoint = APIEndpoint(name: name, url: url, method: method)
                    dismiss()
                    onCreate(endpoint)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding(24)
    }
}

/// API 组合输入弹窗
struct APIPipelineInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    let endpoints: [APIEndpoint]
    var onCreate: (APIPipeline) -> Void

    @State private var name = ""
    @State private var description = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("创建 API 组合")
                .font(.headline)

            Form {
                TextField("名称", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("描述（可选）", text: $description)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(width: 350)

            if endpoints.isEmpty {
                Text("请先添加 API 端点")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("创建后可在详情页添加步骤")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("创建") {
                    let pipeline = APIPipeline(
                        name: name,
                        description: description.isEmpty ? nil : description
                    )
                    dismiss()
                    onCreate(pipeline)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding(24)
    }
}

/// API 导出包装器
struct APIExportWrapper: Codable {
    var version: String
    var type: String
    var data: [APIEndpoint.ExportData]
}

/// API Pipeline 导出包装器
struct APIPipelineExportWrapper: Codable {
    var version: String
    var type: String
    var data: [APIPipeline.ExportData]
}

#Preview {
    SidebarView(selection: .constant(nil), importingCommand: .constant(nil))
        .modelContainer(for: [Action.self, Pipeline.self, QuickCommand.self, APIEndpoint.self, APIPipeline.self], inMemory: true)
        .frame(width: 220)
}
