import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.dodo.app", category: "persistence")

/// 诊断日志文件路径
private let diagLogURL: URL = {
    let dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support")
    return dir.appendingPathComponent("DoDo-diag.log")
}()

/// 写入诊断日志
func diagLog(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: diagLogURL.path) {
            if let handle = try? FileHandle(forWritingTo: diagLogURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: diagLogURL)
        }
    }
}

/// 统一的 SwiftData 保存方法，带错误日志
func saveContext(_ context: ModelContext, caller: String = #function) {
    guard context.hasChanges else { return }
    do {
        try context.save()
        diagLog("✅ 保存成功 (\(caller))")
    } catch {
        let msg = "❌ 保存失败 (\(caller)): \(error)"
        diagLog(msg)
        logger.error("\(msg)")
    }
}

/// AppDelegate - 控制应用行为
class AppDelegate: NSObject, NSApplicationDelegate {
    /// 关闭最后一个窗口时不退出应用
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// 点击 Dock 图标时重新打开窗口
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // 没有可见窗口时，打开主窗口
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }

    /// 应用退出前保存数据
    func applicationWillTerminate(_ notification: Notification) {
        NSLog("📦 [SwiftData] 应用退出，尝试最终保存...")
        // 由 DoDoApp 处理最终保存
        NotificationCenter.default.post(name: .doDoWillTerminate, object: nil)
    }
}

extension Notification.Name {
    static let doDoWillTerminate = Notification.Name("doDoWillTerminate")
}

// MARK: - 页面文本复制支持

struct CopyablePageTextKey: FocusedValueKey {
    typealias Value = String
}

extension FocusedValues {
    var copyablePageText: String? {
        get { self[CopyablePageTextKey.self] }
        set { self[CopyablePageTextKey.self] = newValue }
    }
}

@main
struct DoDoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var scheduler = SchedulerService.shared
    @FocusedValue(\.copyablePageText) var pageText

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Action.self,
            Execution.self,
            Pipeline.self,
            QuickCommand.self,
            APIEndpoint.self,
            APIPipeline.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            NSLog("✅ [SwiftData] ModelContainer 创建成功")
            NSLog("📂 [SwiftData] 存储位置: %@", modelConfiguration.url.path)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    setupScheduler()
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(after: .pasteboard) {
                Button("复制页面全部文本") {
                    if let text = pageText, !text.isEmpty {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentMinSize)

        // 菜单栏图标
        MenuBarExtra("DoDo", systemImage: "bolt.circle.fill") {
            MenuBarView()
                .modelContainer(sharedModelContainer)
        }
    }

    private func setupScheduler() {
        let context = sharedModelContainer.mainContext
        scheduler.configure(with: context)
        scheduler.start()

        // 延迟执行启动任务，确保数据加载完成
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            await scheduler.runLaunchTasks()
        }

        // 监听退出通知，执行最终保存
        NotificationCenter.default.addObserver(
            forName: .doDoWillTerminate,
            object: nil,
            queue: .main
        ) { _ in
            let ctx = self.sharedModelContainer.mainContext
            if ctx.hasChanges {
                NSLog("📦 [SwiftData] 退出前保存未保存的更改...")
                saveContext(ctx, caller: "applicationWillTerminate")
            }
        }
    }
}
