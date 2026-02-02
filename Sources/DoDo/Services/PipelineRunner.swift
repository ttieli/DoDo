import Foundation

/// Pipeline 执行器
class PipelineRunner: ObservableObject {
    @Published var currentStep = 0
    @Published var totalSteps = 0
    @Published var isRunning = false
    @Published var output = ""
    @Published var errorOutput = ""
    @Published var currentStepName = ""

    private var intermediateFiles: [String] = []
    private var process: Process?

    /// 执行 Pipeline
    func run(
        pipeline: Pipeline,
        actions: [Action],
        input: String,
        finalOutput: String?,
        finalOutputFormat: OutputFormatConfig? = nil
    ) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        var pipelineSteps = pipeline.pipelineSteps
        let stepCount = pipelineSteps.count

        // 如果指定了最后一步的输出格式，更新最后一步的配置
        if let format = finalOutputFormat, !pipelineSteps.isEmpty {
            var lastStep = pipelineSteps[pipelineSteps.count - 1]
            lastStep.outputFormat = format.format
            lastStep.extraOptions = format.requiredOptions
            pipelineSteps[pipelineSteps.count - 1] = lastStep
        }

        await MainActor.run {
            isRunning = true
            currentStep = 0
            totalSteps = stepCount
            output = ""
            errorOutput = ""
            intermediateFiles = []
        }

        defer {
            Task { @MainActor in
                isRunning = false
            }
        }

        // 创建临时目录
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DoDo_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var currentInput = input
        var allStdout = ""
        var allStderr = ""
        var finalExitCode: Int32 = 0

        // 按顺序执行每个 step
        for (index, pipelineStep) in pipelineSteps.enumerated() {
            let stepName = pipelineStep.actionName
            guard let action = actions.first(where: { $0.name == stepName }) else {
                let error = "找不到命令: \(stepName)"
                await MainActor.run {
                    errorOutput += error + "\n"
                }
                throw PipelineError.actionNotFound(stepName)
            }

            let actionLabel = action.label
            let actionCommand = action.command
            let actionOutputConfig = action.outputConfig
            let actionCommandMode = action.commandMode

            await MainActor.run {
                currentStep = index + 1
                currentStepName = actionLabel
                output += "\n=== 步骤 \(index + 1)/\(stepCount): \(actionLabel) ===\n"
            }

            // 确定这一步的输出位置
            let isLastStep = index == stepCount - 1
            var stepOutput: String

            if isLastStep && finalOutput != nil && !finalOutput!.isEmpty {
                // 检查 finalOutput 是目录还是文件
                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: finalOutput!, isDirectory: &isDir)

                if exists && isDir.boolValue {
                    // 是目录，需要生成文件名
                    let inputFileName = (currentInput as NSString).lastPathComponent
                    let baseName = (inputFileName as NSString).deletingPathExtension

                    // 根据输出格式确定扩展名
                    let outputExt: String
                    if let format = pipelineStep.outputFormat {
                        outputExt = format.rawValue
                    } else if let firstFormat = action.supportedOutputFormats.first {
                        outputExt = firstFormat.format.rawValue
                    } else {
                        outputExt = "output"
                    }

                    stepOutput = (finalOutput! as NSString).appendingPathComponent("\(baseName).\(outputExt)")
                } else {
                    stepOutput = finalOutput!
                }
            } else {
                // 中间步骤，使用临时目录
                stepOutput = tempDir.appendingPathComponent("step_\(index + 1)").path
                try FileManager.default.createDirectory(atPath: stepOutput, withIntermediateDirectories: true)
                intermediateFiles.append(stepOutput)
            }

            // 获取这一步的额外选项（从 PipelineStep 获取）
            let extraOptions = pipelineStep.extraOptions

            // 构建命令
            let command = buildCommand(
                command: actionCommand,
                input: currentInput,
                output: stepOutput,
                outputFlag: actionOutputConfig?.flag,
                extraOptions: extraOptions,
                mode: actionCommandMode
            )

            await MainActor.run {
                output += "$ \(command)\n"
            }

            // 执行命令
            let (stdout, stderr, exitCode) = try await executeCommand(command)

            allStdout += stdout
            allStderr += stderr

            await MainActor.run {
                if !stdout.isEmpty {
                    output += stdout
                }
                if !stderr.isEmpty {
                    errorOutput += stderr
                }
            }

            if exitCode != 0 {
                finalExitCode = exitCode
                await MainActor.run {
                    errorOutput += "\n步骤 \(index + 1) 执行失败 (exit \(exitCode))\n"
                }
                break
            }

            // 找到这一步的输出文件，作为下一步的输入
            if !isLastStep {
                currentInput = findOutputFile(in: stepOutput) ?? currentInput
            }
        }

        // 清理中间文件
        if pipeline.cleanupIntermediates && finalExitCode == 0 {
            await MainActor.run {
                output += "\n=== 清理中间文件 ===\n"
            }

            for file in intermediateFiles {
                do {
                    try FileManager.default.removeItem(atPath: file)
                    await MainActor.run {
                        output += "已删除: \(file)\n"
                    }
                } catch {
                    await MainActor.run {
                        errorOutput += "删除失败: \(file) - \(error.localizedDescription)\n"
                    }
                }
            }
        }

        // 清理临时目录（如果还存在）
        try? FileManager.default.removeItem(at: tempDir)

        await MainActor.run {
            output += "\n=== Pipeline 执行完成 ===\n"
        }

        return (allStdout, allStderr, finalExitCode)
    }

    /// 在目录中查找输出文件
    private func findOutputFile(in directory: String) -> String? {
        let fileManager = FileManager.default

        // 检查是否是文件而不是目录
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: directory, isDirectory: &isDir) {
            if !isDir.boolValue {
                return directory  // 已经是文件
            }
        }

        // 是目录，查找里面的文件
        guard let files = try? fileManager.contentsOfDirectory(atPath: directory) else {
            return nil
        }

        // 过滤掉隐藏文件，优先返回常见输出格式
        let visibleFiles = files.filter { !$0.hasPrefix(".") }

        // 优先级：.md > .png > .jpg > .pdf > .docx > 其他
        let priorities = [".md", ".png", ".jpg", ".jpeg", ".pdf", ".docx"]
        for ext in priorities {
            if let file = visibleFiles.first(where: { $0.lowercased().hasSuffix(ext) }) {
                return (directory as NSString).appendingPathComponent(file)
            }
        }

        // 返回第一个文件
        if let first = visibleFiles.first {
            return (directory as NSString).appendingPathComponent(first)
        }

        return nil
    }

    private func buildCommand(
        command: String,
        input: String,
        output: String,
        outputFlag: String?,
        extraOptions: [String],
        mode: CommandMode = .standard
    ) -> String {
        switch mode {
        case .standard:
            var parts = [command]

            // 添加输入
            parts.append(quoteIfNeeded(input))

            // 添加额外选项
            parts.append(contentsOf: extraOptions)

            // 添加输出
            if let flag = outputFlag, !flag.isEmpty {
                parts.append(flag)
                parts.append(quoteIfNeeded(output))
            }

            return parts.joined(separator: " ")

        case .pipe:
            var parts: [String] = []

            // 输入部分
            parts.append("cat \(quoteIfNeeded(input)) |")

            // 命令
            parts.append(command)

            // 添加额外选项
            parts.append(contentsOf: extraOptions)

            // 输出重定向
            parts.append("> \(quoteIfNeeded(output))")

            return parts.joined(separator: " ")
        }
    }

    private func quoteIfNeeded(_ path: String) -> String {
        if path.contains(" ") || path.contains("'") || path.contains("\"") {
            return "\"\(path.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        return path
    }

    private func executeCommand(_ command: String) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", command]

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            self.process = process

            do {
                try process.run()
                process.waitUntilExit()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                continuation.resume(returning: (stdout, stderr, process.terminationStatus))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func cancel() {
        process?.terminate()
        isRunning = false
    }
}

enum PipelineError: LocalizedError {
    case actionNotFound(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .actionNotFound(let name):
            return "找不到命令: \(name)"
        case .executionFailed(let message):
            return "执行失败: \(message)"
        }
    }
}
