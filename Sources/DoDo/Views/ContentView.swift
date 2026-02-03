import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Action.name) private var actions: [Action]
    @Query(sort: \Pipeline.name) private var pipelines: [Pipeline]
    @Query(sort: \QuickCommand.name) private var quickCommands: [QuickCommand]
    @State private var selection: SidebarSelection?
    @State private var importingCommand: String?
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selection, importingCommand: $importingCommand)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            if let command = importingCommand {
                ImportView(
                    command: command,
                    onCancel: { importingCommand = nil },
                    onImport: { action in
                        modelContext.insert(action)
                        saveContext(modelContext)
                        importingCommand = nil
                        selection = .action(action)
                    }
                )
            } else if let sel = selection {
                switch sel {
                case .action(let action):
                    ActionDetailView(action: action, onDelete: {
                        modelContext.delete(action)
                        saveContext(modelContext)
                        selection = nil
                    })
                case .pipeline(let pipeline):
                    PipelineDetailView(pipeline: pipeline, onDelete: {
                        modelContext.delete(pipeline)
                        saveContext(modelContext)
                        selection = nil
                    })
                case .quickCommand(let quickCommand):
                    QuickCommandDetailView(quickCommand: quickCommand, onDelete: {
                        modelContext.delete(quickCommand)
                        saveContext(modelContext)
                        selection = nil
                    })
                case .apiEndpoint(let endpoint):
                    APIEndpointDetailView(endpoint: endpoint, onDelete: {
                        modelContext.delete(endpoint)
                        saveContext(modelContext)
                        selection = nil
                    })
                case .apiPipeline(let pipeline):
                    APIPipelineDetailView(pipeline: pipeline, onDelete: {
                        modelContext.delete(pipeline)
                        saveContext(modelContext)
                        selection = nil
                    })
                }
            } else {
                EmptyStateView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            loadAllOnStartup()
            // 默认选中第一个
            if selection == nil {
                if let first = pipelines.first {
                    selection = .pipeline(first)
                } else if let first = actions.first {
                    selection = .action(first)
                }
            }
        }
    }

    /// 启动时统一加载所有配置（内置 + iCloud 用户配置）
    private func loadAllOnStartup() {
        var changed = false

        // 1. 首次启动加载内置命令和组合
        if actions.isEmpty {
            for action in BuiltInConfigs.all {
                modelContext.insert(action)
            }
            for pipeline in BuiltInPipelines.all {
                modelContext.insert(pipeline)
            }
            changed = true
        }

        // 2. 从 iCloud 加载用户命令配置
        let existingActionNames = Set(actions.map { $0.name })
        for config in ConfigManager.shared.loadAllConfigs() {
            if !existingActionNames.contains(config.name) {
                modelContext.insert(config.toAction())
                changed = true
            }
        }

        // 3. 从 iCloud 加载用户 Pipeline 配置
        let existingPipelineNames = Set(pipelines.map { $0.name })
        for config in ConfigManager.shared.loadAllPipelineConfigs() {
            if !existingPipelineNames.contains(config.name) {
                modelContext.insert(config.toPipeline())
                changed = true
            }
        }

        // 4. 从 iCloud 加载用户快捷命令配置
        let existingQCNames = Set(quickCommands.map { $0.name })
        for config in ConfigManager.shared.loadAllQuickCommandConfigs() {
            if !existingQCNames.contains(config.name) {
                modelContext.insert(config.toQuickCommand())
                changed = true
            }
        }

        if changed {
            saveContext(modelContext)
        }
    }
}

/// 空状态视图
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: Design.spacingSection) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary.opacity(0.6))

            VStack(spacing: Design.spacingMedium) {
                Text("欢迎使用 DoDo")
                    .font(.title2)
                    .fontWeight(.medium)
                Text("从左侧选择命令，或按以下步骤开始")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: Design.spacingLarge) {
                quickStartRow(step: 1, icon: "plus.circle.fill", color: .blue,
                              title: "添加命令", detail: "点击左下角 + 导入 CLI 工具")
                quickStartRow(step: 2, icon: "slider.horizontal.3", color: .orange,
                              title: "配置参数", detail: "自动解析 --help 生成图形界面")
                quickStartRow(step: 3, icon: "play.fill", color: .green,
                              title: "执行", detail: "一键运行，或保存为快捷命令")
            }
            .padding(Design.paddingXL)
            .background(Color(.controlBackgroundColor).opacity(0.5))
            .cornerRadius(Design.cornerRadiusLarge)
        }
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func quickStartRow(step: Int, icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: Design.spacingLarge) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: Design.spacingTight) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Action.self, Execution.self, Pipeline.self, QuickCommand.self, APIEndpoint.self, APIPipeline.self], inMemory: true)
}
