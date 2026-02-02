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
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
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
                    .padding(.vertical, 4)
            } else {
                Text("定时任务 (\(scheduledTasks.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 4)

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

/// 任务菜单项
struct TaskMenuItem: View {
    let task: QuickCommand
    @StateObject private var runner = CommandRunner()

    var body: some View {
        Button {
            Task {
                await SchedulerService.shared.runTask(task)
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

                    HStack(spacing: 4) {
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

                // 运行状态
                if SchedulerService.shared.runningTasks.contains(task.id) {
                    ProgressView()
                        .scaleEffect(0.5)
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
