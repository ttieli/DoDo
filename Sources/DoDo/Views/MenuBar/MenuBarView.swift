import SwiftUI
import SwiftData

/// 菜单栏视图
struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \QuickCommand.name) private var quickCommands: [QuickCommand]

    private var scheduledTasks: [QuickCommand] {
        quickCommands.filter { $0.runOnLaunch || $0.repeatInterval != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 打开主窗口
            Button {
                openWindow(id: "main")
                NSApplication.shared.activate()
            } label: {
                Label("打开 DoDo", systemImage: "macwindow")
            }
            .keyboardShortcut("o")

            Divider()

            // 定时任务状态
            if scheduledTasks.isEmpty {
                Text("暂无定时任务")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, Design.paddingSmall)
            } else {
                Text("定时任务 (\(scheduledTasks.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, Design.paddingSmall)

                ForEach(scheduledTasks.prefix(5)) { task in
                    TaskMenuItem(task: task)
                }

                if scheduledTasks.count > 5 {
                    Text("还有 \(scheduledTasks.count - 5) 个...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }

            Divider()

            // 退出
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("退出 DoDo", systemImage: "power")
            }
            .keyboardShortcut("q")
        }
    }
}

/// 任务菜单项（带子菜单显示运行结果）
struct TaskMenuItem: View {
    let task: QuickCommand

    private var lastResult: (success: Bool, output: String)? {
        SchedulerService.shared.lastResults[task.id]
    }

    private var isRunning: Bool {
        SchedulerService.shared.runningTasks.contains(task.id)
    }

    var body: some View {
        Menu {
            // 立即执行
            Button {
                Task {
                    await SchedulerService.shared.runTask(task)
                }
            } label: {
                Label(isRunning ? "执行中..." : "立即执行", systemImage: "play.fill")
            }
            .disabled(isRunning)

            Divider()

            // 上次运行结果
            if let result = lastResult {
                let statusIcon = result.success ? "checkmark.circle.fill" : "xmark.circle.fill"
                let statusText = result.success ? "上次成功" : "上次失败"
                let timeText = task.lastRunAt.map { $0.formatted(date: .omitted, time: .shortened) } ?? ""

                Label("\(statusText) \(timeText)", systemImage: statusIcon)

                // 输出预览 — 点击复制到剪贴板
                if !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let preview = String(result.output.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result.output, forType: .string)
                    } label: {
                        Label("复制输出", systemImage: "doc.on.doc")
                    }

                    // 输出预览（纯展示）
                    Text(preview)
                        .font(.caption)
                        .lineLimit(3)
                }
            } else {
                Label("尚未运行", systemImage: "clock")
                    .foregroundStyle(.secondary)
            }
        } label: {
            HStack {
                // 类型图标
                if task.type == .pipeline {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.purple)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(task.name)
                        .lineLimit(1)

                    HStack(spacing: Design.spacingSmall) {
                        if task.runOnLaunch {
                            Image(systemName: "power")
                                .font(.caption2)
                        }
                        if let interval = task.repeatInterval {
                            Text(formatInterval(interval))
                                .font(.caption2)
                        }
                        if let lastRun = task.lastRunAt {
                            Text("· \(lastRun.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2)
                        }
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // 运行状态指示
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.5)
                } else if let result = lastResult {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.success ? .green : .red)
                        .font(.caption)
                }
            }
        }
    }

    private func formatInterval(_ seconds: Int) -> String {
        switch seconds {
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
        default: return "每\(seconds)秒"
        }
    }
}
