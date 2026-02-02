import Foundation
import SwiftData

/// 任务类型
enum QuickCommandType: String, Codable {
    case command   // 直接执行命令字符串
    case pipeline  // 执行 Pipeline
}

/// 快捷命令 - 保存常用的命令或 Pipeline 配置，支持定时执行
@Model
final class QuickCommand {
    var id: UUID
    var name: String           // 显示名称
    var taskType: String       // "command" 或 "pipeline"
    var command: String        // 完整命令（taskType=command 时使用）
    var pipelineId: UUID?      // Pipeline ID（taskType=pipeline 时使用）
    var presetInput: String?   // 预设输入
    var presetOutput: String?  // 预设输出
    var presetFormatOptionsData: Data?  // 预设格式选项（JSON 编码的 [String]）
    var runOnLaunch: Bool      // 启动时执行
    var repeatInterval: Int?   // 重复间隔(秒)，nil=不重复，3600=每小时
    var lastRunAt: Date?       // 上次执行时间
    var createdAt: Date
    var updatedAt: Date

    /// 快捷命令类型
    var type: QuickCommandType {
        get { QuickCommandType(rawValue: taskType) ?? .command }
        set { taskType = newValue.rawValue }
    }

    /// 预设格式选项
    var presetFormatOptions: [String]? {
        get {
            guard let data = presetFormatOptionsData else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        }
        set {
            presetFormatOptionsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// 创建命令类型的快捷命令
    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        runOnLaunch: Bool = false,
        repeatInterval: Int? = nil,
        lastRunAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.taskType = QuickCommandType.command.rawValue
        self.command = command
        self.pipelineId = nil
        self.presetInput = nil
        self.presetOutput = nil
        self.presetFormatOptionsData = nil
        self.runOnLaunch = runOnLaunch
        self.repeatInterval = repeatInterval
        self.lastRunAt = lastRunAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 创建 Pipeline 类型的快捷命令
    init(
        id: UUID = UUID(),
        name: String,
        pipelineId: UUID,
        presetInput: String,
        presetOutput: String?,
        presetFormatOptions: [String]? = nil,
        runOnLaunch: Bool = false,
        repeatInterval: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.taskType = QuickCommandType.pipeline.rawValue
        self.command = ""
        self.pipelineId = pipelineId
        self.presetInput = presetInput
        self.presetOutput = presetOutput
        self.presetFormatOptionsData = try? JSONEncoder().encode(presetFormatOptions)
        self.runOnLaunch = runOnLaunch
        self.repeatInterval = repeatInterval
        self.lastRunAt = nil
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 是否需要执行（基于重复间隔）
    var shouldRunNow: Bool {
        guard let interval = repeatInterval, interval > 0 else { return false }
        guard let lastRun = lastRunAt else { return true }
        return Date().timeIntervalSince(lastRun) >= Double(interval)
    }

    /// 格式化的重复间隔描述
    var repeatIntervalDescription: String {
        guard let interval = repeatInterval else { return "不重复" }
        switch interval {
        case 60: return "每分钟"
        case 300: return "每5分钟"
        case 900: return "每15分钟"
        case 1800: return "每30分钟"
        case 3600: return "每小时"
        case 7200: return "每2小时"
        case 14400: return "每4小时"
        case 28800: return "每8小时"
        case 43200: return "每12小时"
        case 86400: return "每天"
        default: return "每\(interval)秒"
        }
    }
}
