import Foundation

/// 批量执行器
@MainActor
class BatchRunner: ObservableObject {
    @Published var execution = BatchExecution()

    private let maxConcurrency = 3
    private var isCancelled = false

    /// 批量执行命令
    func runCommands(
        inputs: [String],
        buildCommand: @escaping (String, String) -> String,  // (input, output) -> command
        outputDirectory: String?,  // nil 表示同输入目录
        outputExtension: String
    ) async {
        isCancelled = false
        execution.setItems(from: inputs)
        execution.isRunning = true

        await withTaskGroup(of: Void.self) { group in
            var runningCount = 0
            var index = 0

            while index < execution.items.count || runningCount > 0 {
                // 启动新任务直到达到并发上限
                while runningCount < maxConcurrency && index < execution.items.count && !isCancelled {
                    let item = execution.items[index]
                    index += 1
                    runningCount += 1

                    group.addTask { [weak self] in
                        await self?.executeCommand(
                            item: item,
                            buildCommand: buildCommand,
                            outputDirectory: outputDirectory,
                            outputExtension: outputExtension
                        )
                    }
                }

                // 等待一个任务完成
                if runningCount > 0 {
                    await group.next()
                    runningCount -= 1
                }
            }
        }

        execution.isRunning = false
    }

    /// 执行单个命令
    private func executeCommand(
        item: BatchItem,
        buildCommand: @escaping (String, String) -> String,
        outputDirectory: String?,
        outputExtension: String
    ) async {
        guard !isCancelled else { return }

        execution.updateItem(id: item.id, status: .running)

        // 生成输出路径
        let outputPath = generateOutputPath(
            input: item.input,
            outputDirectory: outputDirectory,
            outputExtension: outputExtension
        )

        let command = buildCommand(item.input, outputPath)

        do {
            let runner = CommandRunner()
            let (stdout, stderr, exitCode) = try await runner.run(command)

            if exitCode == 0 {
                let result = stdout.isEmpty ? "完成" : stdout
                execution.updateItem(id: item.id, status: .success, result: result, output: outputPath)
            } else {
                let error = stderr.isEmpty ? "退出码: \(exitCode)" : stderr
                execution.updateItem(id: item.id, status: .failed, result: error)
            }
        } catch {
            execution.updateItem(id: item.id, status: .failed, result: error.localizedDescription)
        }
    }

    /// 批量执行 API
    func runAPIs(
        inputs: [String],
        variableName: String,
        endpoint: APIEndpoint,
        baseVariables: [String: String] = [:]
    ) async {
        isCancelled = false
        execution.setItems(from: inputs)
        execution.isRunning = true

        await withTaskGroup(of: Void.self) { group in
            var runningCount = 0
            var index = 0

            while index < execution.items.count || runningCount > 0 {
                while runningCount < maxConcurrency && index < execution.items.count && !isCancelled {
                    let item = execution.items[index]
                    index += 1
                    runningCount += 1

                    group.addTask { [weak self] in
                        await self?.executeAPI(
                            item: item,
                            variableName: variableName,
                            endpoint: endpoint,
                            baseVariables: baseVariables
                        )
                    }
                }

                if runningCount > 0 {
                    await group.next()
                    runningCount -= 1
                }
            }
        }

        execution.isRunning = false
    }

    /// 执行单个 API
    private func executeAPI(
        item: BatchItem,
        variableName: String,
        endpoint: APIEndpoint,
        baseVariables: [String: String]
    ) async {
        guard !isCancelled else { return }

        execution.updateItem(id: item.id, status: .running)

        var variables = baseVariables
        variables[variableName] = item.input

        do {
            let runner = APIRunner()
            let response = try await runner.run(endpoint: endpoint, variables: variables)

            if response.statusCode >= 200 && response.statusCode < 300 {
                execution.updateItem(id: item.id, status: .success, result: response.jsonString, response: response)
            } else {
                execution.updateItem(id: item.id, status: .failed, result: "HTTP \(response.statusCode)", response: response)
            }
        } catch {
            execution.updateItem(id: item.id, status: .failed, result: error.localizedDescription)
        }
    }

    /// 导出 API 结果
    func exportAPIResults(to directory: String) throws {
        let fileManager = FileManager.default

        // 确保目录存在
        try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)

        for item in execution.items where item.status == .success {
            guard let response = item.response else { continue }

            // 生成安全的文件名
            let safeName = item.input
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "\\", with: "_")
                .replacingOccurrences(of: ":", with: "_")
                .prefix(50)

            let fileName = "\(safeName).json"
            let filePath = (directory as NSString).appendingPathComponent(String(fileName))

            // 写入 JSON
            try response.jsonString.write(toFile: filePath, atomically: true, encoding: .utf8)
        }
    }

    /// 取消执行
    func cancel() {
        isCancelled = true
        execution.isRunning = false
    }

    /// 重置
    func reset() {
        isCancelled = false
        execution.reset()
    }

    // MARK: - Helper

    /// 生成输出路径
    private func generateOutputPath(input: String, outputDirectory: String?, outputExtension: String) -> String {
        let inputURL = URL(fileURLWithPath: input)
        let baseName = inputURL.deletingPathExtension().lastPathComponent

        let directory: String
        if let outputDir = outputDirectory, !outputDir.isEmpty {
            directory = outputDir
        } else {
            directory = inputURL.deletingLastPathComponent().path
        }

        var outputPath = (directory as NSString).appendingPathComponent("\(baseName).\(outputExtension)")

        // 处理重名
        var counter = 1
        while FileManager.default.fileExists(atPath: outputPath) {
            outputPath = (directory as NSString).appendingPathComponent("\(baseName)-\(counter).\(outputExtension)")
            counter += 1
        }

        return outputPath
    }
}
