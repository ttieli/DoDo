import Foundation
import SwiftData

/// 执行状态
enum ExecutionStatus: String, Codable {
    case pending
    case running
    case success
    case failed
    case cancelled
}

/// 执行记录
@Model
final class Execution {
    var id: UUID
    var actionId: UUID
    var actionName: String     // 冗余存储，方便显示
    var command: String        // 实际执行的完整命令
    var status: ExecutionStatus
    var stdout: String
    var stderr: String
    var exitCode: Int?
    var startedAt: Date
    var finishedAt: Date?
    var batchId: UUID?         // 批量任务组 ID

    init(
        id: UUID = UUID(),
        actionId: UUID,
        actionName: String,
        command: String,
        status: ExecutionStatus = .pending,
        stdout: String = "",
        stderr: String = "",
        exitCode: Int? = nil,
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        batchId: UUID? = nil
    ) {
        self.id = id
        self.actionId = actionId
        self.actionName = actionName
        self.command = command
        self.status = status
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.batchId = batchId
    }

    /// 执行耗时（秒）
    var duration: TimeInterval? {
        guard let finishedAt = finishedAt else { return nil }
        return finishedAt.timeIntervalSince(startedAt)
    }

    /// 格式化的耗时显示
    var durationText: String {
        guard let duration = duration else { return "-" }
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
}
