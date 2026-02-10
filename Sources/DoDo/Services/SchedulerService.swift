import Foundation
import SwiftData
import Combine

/// 调度服务 - 管理定时任务和启动任务
@MainActor
class SchedulerService: ObservableObject {
    static let shared = SchedulerService()

    @Published var runningTasks: Set<UUID> = []
    @Published var lastResults: [UUID: (success: Bool, output: String)] = [:]

    private var timer: Timer?
    private var modelContext: ModelContext?

    private init() {}

    /// 配置 ModelContext
    func configure(with context: ModelContext) {
        self.modelContext = context
    }

    /// 启动调度器
    func start() {
        // 启动定时器，每分钟检查一次
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkAndRunScheduledTasks()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)

        print("📅 调度服务已启动")
    }

    /// 停止调度器
    func stop() {
        timer?.invalidate()
        timer = nil
        print("📅 调度服务已停止")
    }

    /// 执行启动时任务
    func runLaunchTasks() async {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<QuickCommand>(
            predicate: #Predicate { $0.runOnLaunch == true }
        )

        do {
            let tasks = try context.fetch(descriptor)
            print("📅 找到 \(tasks.count) 个启动任务")

            for task in tasks {
                await runTask(task)
            }
        } catch {
            print("📅 获取启动任务失败: \(error)")
        }
    }

    /// 检查并执行定时任务
    func checkAndRunScheduledTasks() async {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<QuickCommand>(
            predicate: #Predicate { $0.repeatInterval != nil }
        )

        do {
            let tasks = try context.fetch(descriptor)

            for task in tasks where task.shouldRunNow {
                await runTask(task)
            }
        } catch {
            print("📅 检查定时任务失败: \(error)")
        }
    }

    /// 执行单个任务
    func runTask(_ task: QuickCommand) async {
        let taskId = task.id
        let taskName = task.name
        let taskType = task.type
        let taskCommand = task.command

        guard !runningTasks.contains(taskId) else {
            print("📅 任务 \(taskName) 正在执行中，跳过")
            return
        }

        runningTasks.insert(taskId)
        print("📅 执行任务: \(taskName) (类型: \(taskType))")

        do {
            switch taskType {
            case .command:
                // 直接执行命令
                let runner = CommandRunner()
                let result = try await runner.run(taskCommand)

                // await 后重新获取模型对象，避免跨悬挂点访问已失效的对象
                if let context = modelContext {
                    let descriptor = FetchDescriptor<QuickCommand>(
                        predicate: #Predicate { $0.id == taskId }
                    )
                    if let freshTask = try? context.fetch(descriptor).first {
                        freshTask.lastRunAt = Date()
                        try? context.save()
                    }
                }

                let success = result.exitCode == 0
                lastResults[taskId] = (success, result.stdout)
                print("📅 任务 \(taskName) 完成，退出码: \(result.exitCode)")

            case .pipeline:
                // 执行 Pipeline
                try await runPipelineTask(task)
            }
        } catch {
            lastResults[taskId] = (false, error.localizedDescription)
            print("📅 任务 \(taskName) 失败: \(error)")
        }

        runningTasks.remove(taskId)
    }

    /// 执行 Pipeline 类型的任务
    private func runPipelineTask(_ task: QuickCommand) async throws {
        guard let context = modelContext,
              let pipelineId = task.pipelineId,
              let input = task.presetInput else {
            throw SchedulerError.invalidPipelineConfig
        }

        let taskId = task.id
        let taskName = task.name
        let presetOutput = task.presetOutput
        let presetFormatOptions = task.presetFormatOptions

        // 获取 Pipeline
        let pipelineDescriptor = FetchDescriptor<Pipeline>(
            predicate: #Predicate { $0.id == pipelineId }
        )
        guard let pipeline = try context.fetch(pipelineDescriptor).first else {
            throw SchedulerError.pipelineNotFound
        }

        // 获取所有 Action
        let actionDescriptor = FetchDescriptor<Action>()
        let actions = try context.fetch(actionDescriptor)

        // 构建输出格式配置
        var finalFormat: OutputFormatConfig?
        if let options = presetFormatOptions, !options.isEmpty {
            // 尝试从最后一个 action 找到匹配的格式
            if let lastStepName = pipeline.steps.last,
               let lastAction = actions.first(where: { $0.name == lastStepName }) {
                finalFormat = lastAction.supportedOutputFormats.first { config in
                    config.requiredOptions == options
                }
            }
        }

        // 执行 Pipeline
        let runner = PipelineRunner()
        let result = try await runner.run(
            pipeline: pipeline,
            actions: actions,
            input: input,
            finalOutput: presetOutput,
            finalOutputFormat: finalFormat
        )

        // await 后重新获取模型对象
        let taskDescriptor = FetchDescriptor<QuickCommand>(
            predicate: #Predicate { $0.id == taskId }
        )
        if let freshTask = try? context.fetch(taskDescriptor).first {
            freshTask.lastRunAt = Date()
            try? context.save()
        }

        let success = result.exitCode == 0
        lastResults[taskId] = (success, result.stdout)
        print("📅 Pipeline 任务 \(taskName) 完成，退出码: \(result.exitCode)")
    }
}

enum SchedulerError: LocalizedError {
    case invalidPipelineConfig
    case pipelineNotFound

    var errorDescription: String? {
        switch self {
        case .invalidPipelineConfig:
            return "无效的 Pipeline 配置"
        case .pipelineNotFound:
            return "找不到指定的 Pipeline"
        }
    }
}
