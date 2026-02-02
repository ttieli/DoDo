import Foundation

/// 命令执行器
@MainActor
class CommandRunner: ObservableObject {
    @Published var isRunning = false
    @Published var output = ""
    @Published var errorOutput = ""
    @Published var exitCode: Int?

    private var process: Process?

    /// 执行命令
    func run(_ command: String) async throws -> (stdout: String, stderr: String, exitCode: Int) {
        isRunning = true
        output = ""
        errorOutput = ""
        exitCode = nil

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // 继承当前环境变量
        process.environment = ProcessInfo.processInfo.environment

        self.process = process

        // 实时读取 stdout
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                Task { @MainActor [weak self] in
                    self?.output += str
                }
            }
        }

        // 实时读取 stderr
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                Task { @MainActor [weak self] in
                    self?.errorOutput += str
                }
            }
        }

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            process.terminationHandler = { proc in
                // 清理 handler
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                // 读取剩余数据
                let remainingOutput = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let remainingError = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let outputStr = String(data: remainingOutput, encoding: .utf8) ?? ""
                let errorStr = String(data: remainingError, encoding: .utf8) ?? ""
                let code = Int(proc.terminationStatus)

                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.output += outputStr
                    self.errorOutput += errorStr
                    self.exitCode = code
                    self.isRunning = false

                    continuation.resume(returning: (self.output, self.errorOutput, code))
                }
            }

            do {
                try process.run()
            } catch {
                Task { @MainActor [weak self] in
                    self?.isRunning = false
                }
                continuation.resume(throwing: error)
            }
        }
    }

    /// 取消执行
    func cancel() {
        process?.terminate()
        isRunning = false
    }

    /// 构建完整命令字符串
    static func buildCommand(
        base: String,
        input: String,
        output: String?,
        outputFlag: String?,
        options: [(flag: String, value: String?)],
        mode: CommandMode = .standard
    ) -> String {
        switch mode {
        case .standard:
            return buildStandardCommand(
                base: base,
                input: input,
                output: output,
                outputFlag: outputFlag,
                options: options
            )
        case .pipe:
            return buildPipeCommand(
                base: base,
                input: input,
                output: output,
                options: options
            )
        }
    }

    /// 构建标准模式命令: 命令 [选项] 输入 -o 输出
    private static func buildStandardCommand(
        base: String,
        input: String,
        output: String?,
        outputFlag: String?,
        options: [(flag: String, value: String?)]
    ) -> String {
        var parts = [base]

        // 添加选项
        for (flag, value) in options {
            if let value = value, !value.isEmpty {
                parts.append(flag)
                // 如果值包含空格，加引号
                parts.append(value.contains(" ") ? "\"\(value)\"" : value)
            } else {
                // bool 选项，只添加 flag
                parts.append(flag)
            }
        }

        // 添加输入（处理空格和特殊字符）
        if !input.isEmpty {
            let quotedInput = input.contains(" ") || input.contains("&") ? "\"\(input)\"" : input
            parts.append(quotedInput)
        }

        // 添加输出
        if let output = output, !output.isEmpty, let flag = outputFlag, !flag.isEmpty {
            let quotedOutput = output.contains(" ") ? "\"\(output)\"" : output
            parts.append(flag)
            parts.append(quotedOutput)
        } else if let output = output, !output.isEmpty {
            // 没有 flag 的情况，直接作为位置参数
            let quotedOutput = output.contains(" ") ? "\"\(output)\"" : output
            parts.append(quotedOutput)
        }

        return parts.joined(separator: " ")
    }

    /// 构建管道模式命令: cat 输入 | 命令 [选项] > 输出
    private static func buildPipeCommand(
        base: String,
        input: String,
        output: String?,
        options: [(flag: String, value: String?)]
    ) -> String {
        var parts: [String] = []

        // 输入部分
        if !input.isEmpty {
            let quotedInput = input.contains(" ") || input.contains("&") ? "\"\(input)\"" : input
            parts.append("cat \(quotedInput) |")
        }

        // 命令
        parts.append(base)

        // 添加选项
        for (flag, value) in options {
            if let value = value, !value.isEmpty {
                parts.append(flag)
                // 字符串参数总是加引号（更安全，避免中文、特殊字符问题）
                let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
                parts.append("\"\(escaped)\"")
            } else if value == nil {
                // bool 选项，只添加 flag
                parts.append(flag)
            }
        }

        // 输出重定向
        if let output = output, !output.isEmpty {
            let quotedOutput = output.contains(" ") ? "\"\(output)\"" : output
            parts.append("> \(quotedOutput)")
        }

        return parts.joined(separator: " ")
    }
}
