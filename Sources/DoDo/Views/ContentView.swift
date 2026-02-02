import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Action.name) private var actions: [Action]
    @Query(sort: \Pipeline.name) private var pipelines: [Pipeline]
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
            loadBuiltInConfigs()
            loadUserConfigs()
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

    /// 加载内置配置（首次启动时）
    private func loadBuiltInConfigs() {
        // 如果数据库已有数据，跳过
        guard actions.isEmpty else { return }

        // 加载内置的配置
        let builtInConfigs = BuiltInConfigs.all
        for action in builtInConfigs {
            modelContext.insert(action)
        }

        saveContext(modelContext)
    }

    /// 加载用户配置（从 iCloud）
    private func loadUserConfigs() {
        let userConfigs = ConfigManager.shared.loadAllConfigs()
        let existingNames = Set(actions.map { $0.name })

        for config in userConfigs {
            // 避免重复导入
            if !existingNames.contains(config.name) {
                let action = config.toAction()
                modelContext.insert(action)
            }
        }

        saveContext(modelContext)
    }
}

/// 空状态视图
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("选择一个命令开始")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("从左侧列表选择命令，或点击 + 添加新命令")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Action.self, Execution.self, Pipeline.self, QuickCommand.self, APIEndpoint.self, APIPipeline.self], inMemory: true)
}
