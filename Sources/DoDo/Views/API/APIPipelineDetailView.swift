import SwiftUI
import SwiftData

/// API 组合详情视图
struct APIPipelineDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \APIEndpoint.name) private var endpoints: [APIEndpoint]
    @Bindable var pipeline: APIPipeline
    var onDelete: () -> Void

    @StateObject private var runner = APIRunner()
    @State private var showingDeleteConfirm = false
    @State private var isEditing = false
    @State private var inputVariables: String = ""
    @State private var responseViewMode: ResponseViewMode = .json

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
                VStack(alignment: .leading, spacing: Design.spacingSection) {
                    // 描述
                    if isEditing || (pipeline.descriptionText != nil && !pipeline.descriptionText!.isEmpty) {
                        descriptionSection
                    }

                    // 步骤
                    stepsSection

                    // 执行区域
                    executeSection

                    // 响应区域
                    if runner.response != nil || runner.error != nil {
                        responseSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: runner.isRunning)
                .padding(Design.paddingXXL)
            }
        }
        .confirmationDialog("确定删除此 API 组合？", isPresented: $showingDeleteConfirm) {
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
        parts.append("[\(pipeline.name)]")
        if let desc = pipeline.descriptionText, !desc.isEmpty { parts.append(desc) }
        if let error = runner.error { parts.append("错误: \(error)") }
        if let response = runner.response {
            parts.append("状态: \(response.statusCode)")
            if let json = response.json,
               let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: data, encoding: .utf8) {
                parts.append("响应:\n\(str)")
            } else if let str = String(data: response.data, encoding: .utf8) {
                parts.append("响应:\n\(str)")
            }
        }
        return parts.joined(separator: "\n\n")
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "arrow.triangle.branch")
                .font(.title2)
                .foregroundStyle(.orange)

            if isEditing {
                TextField("名称", text: $pipeline.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
            } else {
                Text(pipeline.name.isEmpty ? "未命名组合" : pipeline.name)
                    .font(.title2)
                    .fontWeight(.semibold)
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

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: Design.spacingMedium) {
            Text("描述")
                .font(.headline)

            if isEditing {
                TextField("描述（可选）", text: Binding(
                    get: { pipeline.descriptionText ?? "" },
                    set: { pipeline.descriptionText = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            } else if let desc = pipeline.descriptionText {
                Text(desc)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: Design.spacingLarge) {
            HStack {
                Text("步骤")
                    .font(.headline)

                Text("(\(pipeline.steps.count))")
                    .foregroundStyle(.secondary)

                Spacer()

                if isEditing {
                    Menu {
                        ForEach(endpoints) { endpoint in
                            Button(endpoint.name.isEmpty ? "未命名" : endpoint.name) {
                                let step = APIPipelineStep(endpointId: endpoint.id)
                                pipeline.addStep(step)
                            }
                        }
                    } label: {
                        Label("添加步骤", systemImage: "plus")
                    }
                    .disabled(endpoints.isEmpty)
                }
            }

            if pipeline.steps.isEmpty {
                Text("暂无步骤，请添加 API 端点")
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(Design.cornerRadius)
            } else {
                VStack(spacing: Design.spacingLarge) {
                    ForEach(Array(pipeline.steps.enumerated()), id: \.element.id) { index, step in
                        StepCard(
                            step: step,
                            index: index,
                            endpoint: endpoints.first { $0.id == step.endpointId },
                            isEditing: isEditing,
                            isRunning: runner.isRunning && runner.currentStep == index + 1,
                            onRemove: {
                                pipeline.removeStep(at: index)
                            },
                            onUpdateMappings: { mappings in
                                var steps = pipeline.steps
                                steps[index].inputMappings = mappings
                                pipeline.steps = steps
                            }
                        )

                        // 箭头（除了最后一个）
                        if index < pipeline.steps.count - 1 {
                            Image(systemName: "arrow.down")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Execute

    private var executeSection: some View {
        VStack(alignment: .leading, spacing: Design.spacingLarge) {
            Text("执行")
                .font(.headline)

            // 输入变量
            VStack(alignment: .leading, spacing: Design.spacingMedium) {
                Text("初始变量（JSON 格式，如 {\"input\": \"腾讯\"}）")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("变量", text: $inputVariables)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button {
                    Task {
                        await runPipeline()
                    }
                } label: {
                    HStack {
                        if runner.isRunning {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(runner.isRunning ? "执行中..." : "执行组合")
                    }
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(runner.isRunning || pipeline.steps.isEmpty)

                if runner.isRunning {
                    Text("步骤 \(runner.currentStep)/\(runner.totalSteps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("取消") {
                        runner.cancel()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Response

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: Design.spacingLarge) {
            HStack {
                Text("响应")
                    .font(.headline)

                if let response = runner.response {
                    Text("状态: \(response.statusCode)")
                        .font(.caption)
                        .padding(.horizontal, Design.paddingMedium)
                        .padding(.vertical, Design.paddingXS)
                        .background(response.statusCode < 400 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .cornerRadius(Design.cornerRadiusSmall)
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
                    .padding(Design.paddingLarge)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(Design.cornerRadius)
            } else if let response = runner.response {
                // 提取的变量
                if !response.extractedVariables.isEmpty {
                    VStack(alignment: .leading, spacing: Design.spacingSmall) {
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
                    .padding(Design.paddingMedium)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(Design.cornerRadiusMedium)
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

    private func runPipeline() async {
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
            _ = try await runner.runPipeline(
                pipeline: pipeline,
                endpoints: Array(endpoints),
                initialVariables: variables
            )
        } catch {
            runner.error = error.localizedDescription
        }
    }
}

/// 步骤卡片
struct StepCard: View {
    let step: APIPipelineStep
    let index: Int
    let endpoint: APIEndpoint?
    let isEditing: Bool
    let isRunning: Bool
    let onRemove: () -> Void
    let onUpdateMappings: ([String: String]) -> Void

    @State private var showMappings = false

    var body: some View {
        VStack(alignment: .leading, spacing: Design.spacingMedium) {
            HStack {
                // 步骤序号
                Text("\(index + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(isRunning ? Color.orange : Color.blue)
                    .cornerRadius(Design.cornerRadiusLarge)

                if isRunning {
                    ProgressView()
                        .scaleEffect(0.6)
                }

                // API 名称
                if let endpoint = endpoint {
                    VStack(alignment: .leading, spacing: Design.spacingTight) {
                        Text(endpoint.name.isEmpty ? "未命名" : endpoint.name)
                            .fontWeight(.medium)

                        Text("\(endpoint.methodRaw) \(endpoint.url)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("API 已删除")
                        .foregroundStyle(.red)
                }

                Spacer()

                // 输入映射按钮
                Button {
                    showMappings.toggle()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundStyle(step.inputMappings.isEmpty ? Color.secondary : Color.blue)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // 删除按钮
                if isEditing {
                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // 输入映射
            if showMappings {
                VStack(alignment: .leading, spacing: Design.spacingMedium) {
                    HStack {
                        Text("输入映射")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            var mappings = step.inputMappings
                            mappings[""] = ""
                            onUpdateMappings(mappings)
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }

                    if step.inputMappings.isEmpty {
                        Text("无映射（使用上一步提取的变量）")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(Array(step.inputMappings.keys.sorted()), id: \.self) { key in
                            MappingRow(
                                mappings: step.inputMappings,
                                key: key,
                                onUpdate: onUpdateMappings
                            )
                        }
                    }
                }
                .padding(Design.paddingMedium)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(Design.cornerRadiusMedium)
            }

            // 输出提取预览
            if let endpoint = endpoint, !endpoint.outputExtractions.isEmpty {
                HStack(spacing: Design.spacingSmall) {
                    Image(systemName: "arrow.right.circle")
                        .font(.caption)
                        .foregroundStyle(.green)

                    Text("提取: ")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(endpoint.outputExtractions.map { $0.variableName }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(Design.paddingLarge)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Design.cornerRadius)
                .stroke(isRunning ? Color.orange : Color.clear, lineWidth: 2)
        )
    }
}

/// 映射行
struct MappingRow: View {
    let mappings: [String: String]
    let key: String
    let onUpdate: ([String: String]) -> Void

    @State private var editKey: String
    @State private var editValue: String

    init(mappings: [String: String], key: String, onUpdate: @escaping ([String: String]) -> Void) {
        self.mappings = mappings
        self.key = key
        self.onUpdate = onUpdate
        self._editKey = State(initialValue: key)
        self._editValue = State(initialValue: mappings[key] ?? "")
    }

    var body: some View {
        HStack {
            TextField("变量名", text: $editKey)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .onChange(of: editKey) { _, newKey in
                    var newMappings = mappings
                    newMappings.removeValue(forKey: key)
                    newMappings[newKey] = editValue
                    onUpdate(newMappings)
                }

            Text("=")
                .foregroundStyle(.secondary)

            TextField("值（如 {{step1.KeyNo}}）", text: $editValue)
                .textFieldStyle(.roundedBorder)
                .onChange(of: editValue) { _, newValue in
                    var newMappings = mappings
                    newMappings[editKey] = newValue
                    onUpdate(newMappings)
                }

            Button {
                var newMappings = mappings
                newMappings.removeValue(forKey: editKey)
                onUpdate(newMappings)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    APIPipelineDetailView(
        pipeline: APIPipeline(name: "Stock API Query", description: "Search → Get Details"),
        onDelete: {}
    )
    .frame(width: 700, height: 800)
}
