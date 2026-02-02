import Foundation

/// 批量执行项状态
enum BatchItemStatus: String {
    case pending    // 等待中
    case running    // 执行中
    case success    // 成功
    case failed     // 失败
}

/// 批量执行单项
struct BatchItem: Identifiable {
    var id: UUID = UUID()
    var input: String              // 输入路径/URL/参数值
    var output: String?            // 输出路径
    var status: BatchItemStatus = .pending
    var result: String?            // 输出内容或错误信息
    var response: APIResponse?     // API 响应（仅 API 批量）
    var startedAt: Date?
    var finishedAt: Date?

    var duration: TimeInterval? {
        guard let start = startedAt, let end = finishedAt else { return nil }
        return end.timeIntervalSince(start)
    }

    var durationText: String {
        guard let duration = duration else { return "" }
        return String(format: "%.1fs", duration)
    }
}

/// 批量执行管理器
@MainActor
class BatchExecution: ObservableObject {
    @Published var items: [BatchItem] = []
    @Published var isRunning = false
    @Published var selectedItemId: UUID?

    var completedCount: Int {
        items.filter { $0.status == .success }.count
    }

    var failedCount: Int {
        items.filter { $0.status == .failed }.count
    }

    var runningCount: Int {
        items.filter { $0.status == .running }.count
    }

    var pendingCount: Int {
        items.filter { $0.status == .pending }.count
    }

    var progress: String {
        let done = completedCount + failedCount
        return "\(done)/\(items.count)"
    }

    var selectedItem: BatchItem? {
        guard let id = selectedItemId else { return items.first }
        return items.first { $0.id == id }
    }

    func reset() {
        items = []
        isRunning = false
        selectedItemId = nil
    }

    func setItems(from inputs: [String]) {
        items = inputs.map { BatchItem(input: $0) }
        selectedItemId = items.first?.id
    }

    func updateItem(id: UUID, status: BatchItemStatus, result: String? = nil, output: String? = nil, response: APIResponse? = nil) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = status
        if status == .running {
            items[index].startedAt = Date()
        }
        if status == .success || status == .failed {
            items[index].finishedAt = Date()
        }
        if let result = result {
            items[index].result = result
        }
        if let output = output {
            items[index].output = output
        }
        if let response = response {
            items[index].response = response
        }
    }
}
