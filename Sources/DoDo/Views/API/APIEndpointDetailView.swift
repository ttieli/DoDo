import SwiftUI
import SwiftData

/// API 端点详情视图
struct APIEndpointDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var endpoint: APIEndpoint
    var onDelete: () -> Void

    @StateObject private var runner = APIRunner()
    @StateObject private var batchRunner = BatchRunner()

    @State private var showingDeleteConfirm = false
    @State private var isEditing = false
    @State private var inputVariables: String = ""
    @State private var responseViewMode: ResponseViewMode = .json

    // 批量模式状态
    @State private var batchMode: BatchInputMode = .single
    @State private var batchInputs: [String] = []
    @State private var batchVariableName: String = ""
    @State private var batchResponseViewMode: APIResponseViewMode = .json

    enum ResponseViewMode: String, CaseIterable {
        case json = "JSON"
        case card = "卡片"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            headerSection

            Divider()

            // 内容区
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 基本信息
                    basicInfoSection

                    // 认证配置
                    authSection

                    // 输出提取配置
                    if isEditing {
                        outputExtractionSection
                    }

                    // 执行区域
                    executeSection

                    // 响应区域
                    if batchMode == .multiple && (!batchRunner.execution.items.isEmpty || batchRunner.execution.isRunning) {
                        // 批量结果
                        batchResponseSection
                    } else if runner.response != nil || runner.error != nil {
                        // 单项结果
                        responseSection
                    }
                }
                .padding(20)
            }
        }
        .confirmationDialog("确定删除此 API？", isPresented: $showingDeleteConfirm) {
            Button("删除", role: .destructive) {
                onDelete()
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "network")
                .font(.title2)
                .foregroundStyle(.blue)

            if isEditing {
                TextField("名称", text: $endpoint.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
            } else {
                Text(endpoint.name.isEmpty ? "未命名 API" : endpoint.name)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    isEditing.toggle()
                    if !isEditing {
                        endpoint.updatedAt = Date()
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

    // MARK: - Basic Info

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基本信息")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                // 方法和 URL
                HStack(spacing: 12) {
                    Picker("方法", selection: $endpoint.method) {
                        ForEach(HTTPMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .frame(width: 100)
                    .disabled(!isEditing)

                    TextField("URL", text: $endpoint.url)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!isEditing)
                }

                // Headers
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Headers")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if isEditing {
                            Button {
                                var headers = endpoint.headers
                                headers[""] = ""
                                endpoint.headers = headers
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    if endpoint.headers.isEmpty {
                        Text("无")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(Array(endpoint.headers.keys.sorted()), id: \.self) { key in
                            HeaderRow(
                                headers: Binding(
                                    get: { endpoint.headers },
                                    set: { endpoint.headers = $0 }
                                ),
                                key: key,
                                isEditing: isEditing
                            )
                        }
                    }
                }

                // Body
                if endpoint.method != .GET {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Body")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if isEditing {
                            TextEditor(text: Binding(
                                get: { endpoint.bodyTemplate ?? "" },
                                set: { endpoint.bodyTemplate = $0.isEmpty ? nil : $0 }
                            ))
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                        } else {
                            Text(endpoint.bodyTemplate ?? "无")
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(nsColor: .textBackgroundColor))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Auth

    private var authSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("认证配置")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Picker("类型", selection: $endpoint.authType) {
                    Text("无认证").tag(APIAuthType.none)
                    Text("API Key").tag(APIAuthType.apiKey)
                    Text("Token 生成").tag(APIAuthType.token)
                    Text("Bearer Token").tag(APIAuthType.bearer)
                    Text("自定义").tag(APIAuthType.custom)
                }
                .disabled(!isEditing)

                // 根据认证类型显示不同配置
                switch endpoint.authType {
                case .none:
                    EmptyView()

                case .apiKey:
                    apiKeyAuthConfig

                case .token:
                    tokenAuthConfig

                case .bearer:
                    bearerAuthConfig

                case .custom:
                    customAuthConfig
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private var apiKeyAuthConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Key 名称")
                    .frame(width: 80, alignment: .leading)
                TextField("如 X-Api-Key", text: authConfigBinding("key"))
                    .textFieldStyle(.roundedBorder)
                    .disabled(!isEditing)
            }
            HStack {
                Text("Value")
                    .frame(width: 80, alignment: .leading)
                SecureField("API Key 值", text: authConfigBinding("value"))
                    .textFieldStyle(.roundedBorder)
                    .disabled(!isEditing)
            }
            HStack {
                Text("位置")
                    .frame(width: 80, alignment: .leading)
                Picker("", selection: authConfigBinding("location")) {
                    Text("Header").tag("header")
                    Text("Query").tag("query")
                }
                .pickerStyle(.segmented)
                .disabled(!isEditing)
            }
        }
    }

    private var tokenAuthConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本地计算 Token（基于密钥+时间戳）")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Key")
                    .frame(width: 80, alignment: .leading)
                TextField("API Key", text: authConfigBinding("key"))
                    .textFieldStyle(.roundedBorder)
                    .disabled(!isEditing)
            }
            HStack {
                Text("Secret")
                    .frame(width: 80, alignment: .leading)
                SecureField("Secret Key", text: authConfigBinding("secret"))
                    .textFieldStyle(.roundedBorder)
                    .disabled(!isEditing)
            }
            HStack {
                Text("算法")
                    .frame(width: 80, alignment: .leading)
                TextField("如 MD5(Key+Timestamp+Secret)", text: authConfigBinding("algorithm"))
                    .textFieldStyle(.roundedBorder)
                    .disabled(!isEditing)
            }

            Divider()

            Text("Header 配置")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Token Header")
                    .frame(width: 80, alignment: .leading)
                TextField("如 Token", text: authConfigBinding("headerName"))
                    .textFieldStyle(.roundedBorder)
                    .disabled(!isEditing)
            }
            HStack {
                Text("Key Header")
                    .frame(width: 80, alignment: .leading)
                TextField("如 Key（可选）", text: authConfigBinding("keyHeader"))
                    .textFieldStyle(.roundedBorder)
                    .disabled(!isEditing)
            }
            HStack {
                Text("时间戳 Header")
                    .frame(width: 80, alignment: .leading)
                TextField("如 Timespan（可选）", text: authConfigBinding("timestampHeader"))
                    .textFieldStyle(.roundedBorder)
                    .disabled(!isEditing)
            }
        }
    }

    private var bearerAuthConfig: some View {
        HStack {
            Text("Token")
                .frame(width: 80, alignment: .leading)
            SecureField("Bearer Token", text: authConfigBinding("token"))
                .textFieldStyle(.roundedBorder)
                .disabled(!isEditing)
        }
    }

    private var customAuthConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自定义 Headers（每行一个，格式: Key: Value）")
                .font(.caption)
                .foregroundStyle(.secondary)

            // 简化显示，直接编辑 headers
            ForEach(Array(endpoint.authConfig.keys.sorted()), id: \.self) { key in
                HStack {
                    TextField("Key", text: .constant(key))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .disabled(true)

                    TextField("Value", text: authConfigBinding(key))
                        .textFieldStyle(.roundedBorder)
                        .disabled(!isEditing)
                }
            }

            if isEditing {
                Button {
                    var config = endpoint.authConfig
                    config["NewHeader"] = ""
                    endpoint.authConfig = config
                } label: {
                    Label("添加", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func authConfigBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { endpoint.authConfig[key] ?? "" },
            set: {
                var config = endpoint.authConfig
                config[key] = $0
                endpoint.authConfig = config
            }
        )
    }

    // MARK: - Output Extraction

    private var outputExtractionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("输出提取")
                    .font(.headline)

                Spacer()

                Button {
                    var extractions = endpoint.outputExtractions
                    extractions.append(OutputExtraction(jsonPath: "", variableName: ""))
                    endpoint.outputExtractions = extractions
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("从响应中提取值，用于 API 组合")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Array(endpoint.outputExtractions.enumerated()), id: \.offset) { index, extraction in
                HStack {
                    TextField("JSONPath (如 $.Result.KeyNo)", text: Binding(
                        get: { extraction.jsonPath },
                        set: {
                            var extractions = endpoint.outputExtractions
                            extractions[index].jsonPath = $0
                            endpoint.outputExtractions = extractions
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)

                    TextField("变量名", text: Binding(
                        get: { extraction.variableName },
                        set: {
                            var extractions = endpoint.outputExtractions
                            extractions[index].variableName = $0
                            endpoint.outputExtractions = extractions
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)

                    Button {
                        var extractions = endpoint.outputExtractions
                        extractions.remove(at: index)
                        endpoint.outputExtractions = extractions
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Execute

    private var executeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("执行")
                    .font(.headline)

                Spacer()

                // 批量模式切换
                if batchMode == .single {
                    Button("批量模式") {
                        batchMode = .multiple
                        // 从 URL 中提取变量名
                        extractVariableNames()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button("退出批量") {
                        batchMode = .single
                        batchInputs = []
                        batchRunner.reset()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if batchMode == .single {
                // 单项模式：输入变量
                singleExecuteSection
            } else {
                // 批量模式：批量输入
                batchExecuteSection
            }
        }
    }

    private var singleExecuteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("变量（JSON 格式，如 {\"input\": \"腾讯\"}）")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("变量", text: $inputVariables)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button {
                    Task {
                        await runAPI()
                    }
                } label: {
                    HStack {
                        if runner.isRunning {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(runner.isRunning ? "请求中..." : "发送请求")
                    }
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .disabled(runner.isRunning || endpoint.url.isEmpty)

                if runner.isRunning {
                    Button("取消") {
                        runner.cancel()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var batchExecuteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 选择批量变量
            HStack {
                Text("批量变量:")
                    .foregroundStyle(.secondary)

                Picker("", selection: $batchVariableName) {
                    ForEach(detectedVariables, id: \.self) { varName in
                        Text(varName).tag(varName)
                    }
                }
                .frame(width: 150)

                Text("（从 URL/Body 中检测）")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // 批量输入列表
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("输入列表 (\(batchInputs.count) 项)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Menu {
                        Button("粘贴多行文本") {
                            pasteMultipleLines()
                        }
                        Button("从文件读取") {
                            loadFromFile()
                        }
                        Button("清空") {
                            batchInputs.removeAll()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                }

                // 输入列表
                if batchInputs.isEmpty {
                    Text("点击右上角菜单添加输入")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(Array(batchInputs.enumerated()), id: \.offset) { index, input in
                                HStack {
                                    Text(input)
                                        .font(.system(.body, design: .monospaced))
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Spacer()

                                    Button {
                                        batchInputs.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                        .padding(8)
                    }
                    .frame(minHeight: 100, maxHeight: 200)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            // 执行按钮
            HStack {
                Button {
                    Task {
                        await runBatchAPI()
                    }
                } label: {
                    HStack {
                        if batchRunner.execution.isRunning {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(batchRunner.execution.isRunning ? "执行中..." : "批量执行 (\(batchInputs.count))")
                    }
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .disabled(batchRunner.execution.isRunning || batchInputs.isEmpty || batchVariableName.isEmpty)

                if batchRunner.execution.isRunning {
                    Button("取消") {
                        batchRunner.cancel()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // 从 URL 和 Body 中检测变量名
    private var detectedVariables: [String] {
        var variables: Set<String> = []

        // 从 URL 中检测 {{varName}}
        let urlPattern = try? NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}")
        let urlRange = NSRange(endpoint.url.startIndex..., in: endpoint.url)
        urlPattern?.enumerateMatches(in: endpoint.url, range: urlRange) { match, _, _ in
            if let range = match?.range(at: 1), let swiftRange = Range(range, in: endpoint.url) {
                variables.insert(String(endpoint.url[swiftRange]))
            }
        }

        // 从 Body 中检测
        if let body = endpoint.bodyTemplate {
            let bodyRange = NSRange(body.startIndex..., in: body)
            urlPattern?.enumerateMatches(in: body, range: bodyRange) { match, _, _ in
                if let range = match?.range(at: 1), let swiftRange = Range(range, in: body) {
                    variables.insert(String(body[swiftRange]))
                }
            }
        }

        // 排除内置变量
        variables.remove("timestamp")

        return Array(variables).sorted()
    }

    private func extractVariableNames() {
        let vars = detectedVariables
        if batchVariableName.isEmpty && !vars.isEmpty {
            batchVariableName = vars.first ?? ""
        }
    }

    private func pasteMultipleLines() {
        let alert = NSAlert()
        alert.messageText = "粘贴多行输入"
        alert.informativeText = "每行一个值"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        textView.isEditable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        alert.accessoryView = scrollView

        if alert.runModal() == .alertFirstButtonReturn {
            let text = textView.string
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            batchInputs.append(contentsOf: lines)
        }
    }

    private func loadFromFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.plainText, .json]

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)

                // 尝试解析为 JSON 数组
                if let data = content.data(using: .utf8),
                   let array = try? JSONSerialization.jsonObject(with: data) as? [String] {
                    batchInputs.append(contentsOf: array)
                } else {
                    // 按行解析
                    let lines = content.components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    batchInputs.append(contentsOf: lines)
                }
            } catch {
                print("读取文件失败: \(error)")
            }
        }
    }

    // MARK: - Batch Response

    private var batchResponseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("批量结果")
                    .font(.headline)

                Spacer()

                // 导出按钮
                if !batchRunner.execution.isRunning && batchRunner.execution.completedCount > 0 {
                    Button("导出 JSON") {
                        exportBatchResults()
                    }
                    .buttonStyle(.bordered)
                }
            }

            BatchAPIResultView(execution: batchRunner.execution)
                .frame(minHeight: 300)
        }
    }

    private func exportBatchResults() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "选择导出目录"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try batchRunner.exportAPIResults(to: url.path)

                // 显示成功提示
                let alert = NSAlert()
                alert.messageText = "导出成功"
                alert.informativeText = "已导出 \(batchRunner.execution.completedCount) 个 JSON 文件到 \(url.path)"
                alert.alertStyle = .informational
                alert.runModal()
            } catch {
                let alert = NSAlert()
                alert.messageText = "导出失败"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }

    // MARK: - Response

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("响应")
                    .font(.headline)

                if let response = runner.response {
                    Text("状态: \(response.statusCode)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(response.statusCode < 400 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .cornerRadius(4)
                }

                Spacer()

                Picker("", selection: $responseViewMode) {
                    ForEach(ResponseViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            if let error = runner.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            } else if let response = runner.response {
                // 提取的变量
                if !response.extractedVariables.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("提取的变量")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(Array(response.extractedVariables.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text(key)
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                Text("=")
                                    .foregroundStyle(.secondary)
                                Text(response.extractedVariables[key] ?? "")
                                    .font(.caption)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }

                // 响应内容
                Group {
                    switch responseViewMode {
                    case .json:
                        JSONResponseView(json: response.json, rawData: response.data)
                            .frame(minHeight: 200)

                    case .card:
                        CardResponseView(json: response.json)
                            .frame(minHeight: 200)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func runAPI() async {
        // 解析输入变量
        var variables: [String: String] = [:]
        if !inputVariables.isEmpty,
           let data = inputVariables.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (key, value) in dict {
                if let str = value as? String {
                    variables[key] = str
                } else if let num = value as? NSNumber {
                    variables[key] = num.stringValue
                }
            }
        }

        do {
            _ = try await runner.run(endpoint: endpoint, variables: variables)
        } catch {
            runner.error = error.localizedDescription
        }
    }

    private func runBatchAPI() async {
        // 解析基础变量（除了批量变量外的其他变量）
        var baseVariables: [String: String] = [:]
        if !inputVariables.isEmpty,
           let data = inputVariables.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (key, value) in dict {
                if key != batchVariableName {
                    if let str = value as? String {
                        baseVariables[key] = str
                    } else if let num = value as? NSNumber {
                        baseVariables[key] = num.stringValue
                    }
                }
            }
        }

        await batchRunner.runAPIs(
            inputs: batchInputs,
            variableName: batchVariableName,
            endpoint: endpoint,
            baseVariables: baseVariables
        )
    }
}

/// Header 行视图
struct HeaderRow: View {
    @Binding var headers: [String: String]
    let key: String
    let isEditing: Bool

    @State private var editKey: String
    @State private var editValue: String

    init(headers: Binding<[String: String]>, key: String, isEditing: Bool) {
        self._headers = headers
        self.key = key
        self.isEditing = isEditing
        self._editKey = State(initialValue: key)
        self._editValue = State(initialValue: headers.wrappedValue[key] ?? "")
    }

    var body: some View {
        HStack {
            if isEditing {
                TextField("Key", text: $editKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .onChange(of: editKey) { _, newKey in
                        if newKey != key {
                            headers.removeValue(forKey: key)
                            headers[newKey] = editValue
                        }
                    }

                TextField("Value", text: $editValue)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: editValue) { _, newValue in
                        headers[editKey] = newValue
                    }

                Button {
                    headers.removeValue(forKey: editKey)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            } else {
                Text(key)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 120, alignment: .leading)

                Text(headers[key] ?? "")
                    .font(.caption)
                    .textSelection(.enabled)
            }
        }
    }
}

#Preview {
    APIEndpointDetailView(
        endpoint: APIEndpoint(
            name: "Weather Search",
            url: "https://api.example.com/weather",
            method: .GET
        ),
        onDelete: {}
    )
    .frame(width: 700, height: 800)
}
