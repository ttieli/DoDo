import Foundation

/// Help 输出解析器
class HelpParser {
    static let shared = HelpParser()

    private init() {}

    /// 检查命令是否存在
    func commandExists(_ command: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which \(command)"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// 获取命令的 help 输出
    func getHelpOutput(_ command: String) -> (output: String, success: Bool) {
        // 尝试 --help，如果失败尝试 -h
        var output = runCommand("\(command) --help")
        if output.isEmpty || output.contains("unknown option") || output.contains("invalid option") {
            let altOutput = runCommand("\(command) -h")
            if !altOutput.isEmpty {
                output = altOutput
            }
        }

        // 如果还是空的，尝试不带参数运行（有些命令这样会显示帮助）
        if output.isEmpty {
            output = runCommand(command)
        }

        return (output, !output.isEmpty)
    }

    private func runCommand(_ command: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            var result = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            // 有些命令把帮助输出到 stderr
            if result.isEmpty && !errorOutput.isEmpty {
                result = errorOutput
            }

            return result
        } catch {
            return ""
        }
    }

    /// 解析 help 输出，提取参考信息
    func parseHelp(_ helpText: String, command: String) -> ParsedHelp {
        var result = ParsedHelp(command: command)

        // 提取描述（通常在开头）
        let lines = helpText.components(separatedBy: "\n")
        for line in lines.prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("-") && !trimmed.lowercased().hasPrefix("usage") {
                result.description = trimmed
                break
            }
        }

        // 提取 usage 模式
        let usagePattern = #"(?i)usage:\s*(.+)"#
        if let match = helpText.range(of: usagePattern, options: .regularExpression) {
            let usageLine = String(helpText[match])
            result.usagePattern = usageLine.replacingOccurrences(of: "(?i)usage:\\s*", with: "", options: .regularExpression)
        }

        // 解析选项
        result.options = parseOptions(helpText)

        // 推断输入类型
        result.inferredInputType = inferInputType(helpText)

        // 推断是否有输出选项
        result.outputFlag = inferOutputFlag(helpText)

        return result
    }

    /// 解析选项
    private func parseOptions(_ helpText: String) -> [ParsedOption] {
        var options: [ParsedOption] = []

        // 常见的选项格式：
        // -o, --output FILE    描述
        // --flag               描述
        // -f FILE              描述
        // -v, --verbose        描述

        let patterns = [
            // -o, --output ARG    desc
            #"^\s*(-\w),?\s*(--[\w-]+)(?:\s+[<\[\(]?(\w+)[>\]\)]?)?\s+(.+)$"#,
            // --output ARG    desc
            #"^\s*(--[\w-]+)(?:\s+[<\[\(]?(\w+)[>\]\)]?)?\s{2,}(.+)$"#,
            // -o ARG    desc
            #"^\s*(-\w)(?:\s+[<\[\(]?(\w+)[>\]\)]?)?\s{2,}(.+)$"#,
            // --flag    desc (无参数)
            #"^\s*(--[\w-]+)\s{2,}(.+)$"#,
        ]

        let lines = helpText.components(separatedBy: "\n")

        for line in lines {
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

                    var option = ParsedOption()

                    // 根据匹配的 pattern 提取信息
                    if match.numberOfRanges >= 3 {
                        if let range = Range(match.range(at: 1), in: line) {
                            option.shortFlag = String(line[range])
                        }
                    }

                    // 尝试提取长选项
                    for i in 1..<match.numberOfRanges {
                        if let range = Range(match.range(at: i), in: line) {
                            let part = String(line[range])
                            if part.hasPrefix("--") {
                                option.longFlag = part
                            } else if part.hasPrefix("-") && part.count == 2 {
                                option.shortFlag = part
                            } else if !part.hasPrefix("-") && part.count < 20 {
                                // 可能是参数名
                                if option.argument == nil && !part.contains(" ") {
                                    option.argument = part
                                }
                            } else {
                                // 描述
                                option.description = part.trimmingCharacters(in: .whitespaces)
                            }
                        }
                    }

                    // 推断类型
                    option.inferredType = inferOptionType(option)

                    if option.shortFlag != nil || option.longFlag != nil {
                        options.append(option)
                    }

                    break
                }
            }
        }

        return options
    }

    /// 推断选项类型
    private func inferOptionType(_ option: ParsedOption) -> String {
        let flag = (option.longFlag ?? option.shortFlag ?? "").lowercased()
        let arg = (option.argument ?? "").lowercased()
        let desc = (option.description ?? "").lowercased()

        // 布尔类型的常见标志
        let boolKeywords = ["verbose", "quiet", "debug", "force", "recursive", "help", "version", "dry-run", "no-"]
        for keyword in boolKeywords {
            if flag.contains(keyword) || desc.contains(keyword) {
                return "bool"
            }
        }

        // 如果没有参数，可能是布尔
        if option.argument == nil {
            return "bool"
        }

        // 枚举类型（描述中有选项列表）
        if desc.contains("one of") || desc.contains("可选") || desc.contains("{") {
            return "enum"
        }

        return "string"
    }

    /// 推断输入类型
    private func inferInputType(_ helpText: String) -> String {
        let text = helpText.lowercased()

        if text.contains("url") || text.contains("http") || text.contains("网址") {
            return "url"
        }
        if text.contains("directory") || text.contains("folder") || text.contains("目录") || text.contains("文件夹") {
            return "directory"
        }
        if text.contains("file") || text.contains("文件") || text.contains("path") || text.contains("路径") {
            return "file"
        }

        return "string"
    }

    /// 推断输出选项
    private func inferOutputFlag(_ helpText: String) -> String? {
        let patterns = [
            #"-o[,\s]|--output"#,
            #"--out[^p]"#,
            #"-O[,\s]"#,
        ]

        for pattern in patterns {
            if helpText.range(of: pattern, options: .regularExpression) != nil {
                // 确定具体是哪个 flag
                if helpText.contains("--output") {
                    return "--output"
                } else if helpText.contains("-o ") || helpText.contains("-o,") {
                    return "-o"
                } else if helpText.contains("-O ") {
                    return "-O"
                }
            }
        }

        return nil
    }
}

/// 解析后的帮助信息
struct ParsedHelp {
    var command: String
    var description: String?
    var usagePattern: String?
    var options: [ParsedOption] = []
    var inferredInputType: String = "string"
    var outputFlag: String?

    /// 生成参考信息文本
    func toReferenceText() -> String {
        var text = "## 命令分析结果\n\n"

        text += "**命令**: `\(command)`\n\n"

        if let desc = description {
            text += "**描述**: \(desc)\n\n"
        }

        if let usage = usagePattern {
            text += "**用法**: `\(usage)`\n\n"
        }

        text += "**推断的输入类型**: \(inferredInputType)\n\n"

        if let outFlag = outputFlag {
            text += "**输出选项**: `\(outFlag)`\n\n"
        }

        if !options.isEmpty {
            text += "**识别到的选项** (\(options.count) 个):\n\n"
            for opt in options.prefix(20) { // 最多显示 20 个
                var line = "- "
                if let short = opt.shortFlag {
                    line += "`\(short)`"
                }
                if let long = opt.longFlag {
                    if opt.shortFlag != nil { line += ", " }
                    line += "`\(long)`"
                }
                if let arg = opt.argument {
                    line += " `<\(arg)>`"
                }
                line += " [\(opt.inferredType)]"
                if let desc = opt.description {
                    line += " - \(desc)"
                }
                text += line + "\n"
            }
            if options.count > 20 {
                text += "- ... 还有 \(options.count - 20) 个选项\n"
            }
        }

        return text
    }
}

/// 解析后的单个选项
struct ParsedOption {
    var shortFlag: String?
    var longFlag: String?
    var argument: String?
    var description: String?
    var inferredType: String = "string"
}
