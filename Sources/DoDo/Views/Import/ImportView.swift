import SwiftUI

/// 导入命令视图
struct ImportView: View {
    let command: String
    var onCancel: () -> Void
    var onImport: (Action) -> Void

    @State private var isLoading = true
    @State private var helpText = ""
    @State private var parsedHelp: ParsedHelp?
    @State private var aiPrompt = ""
    @State private var jsonInput = ""
    @State private var errorMessage: String?
    @State private var showCopiedTip = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text("导入命令: \(command)")
                    .font(.headline)

                Spacer()
            }
            .padding()
            .background(.bar)

            Divider()

            if isLoading {
                Spacer()
                ProgressView("正在分析命令...")
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Help 原文
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Help 输出")
                                        .font(.headline)
                                    Spacer()
                                    Button("复制") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(helpText, forType: .string)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }

                                ScrollView {
                                    Text(helpText)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxHeight: 200)
                            }
                        }

                        // 参考信息
                        if let parsed = parsedHelp {
                            GroupBox {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("分析结果")
                                        .font(.headline)

                                    Text(parsed.toReferenceText())
                                        .font(.caption)
                                        .textSelection(.enabled)
                                }
                            }
                        }

                        // AI Prompt
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("AI Prompt")
                                        .font(.headline)
                                    Spacer()
                                    Button(showCopiedTip ? "已复制!" : "复制 Prompt") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(aiPrompt, forType: .string)
                                        showCopiedTip = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            showCopiedTip = false
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }

                                Text("复制此 Prompt 发给 AI (如 Claude)，获取配置 JSON")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                ScrollView {
                                    Text(aiPrompt)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxHeight: 150)
                                .background(Color(nsColor: .textBackgroundColor))
                                .cornerRadius(4)
                            }
                        }

                        // 导入配置
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("粘贴 JSON 配置")
                                    .font(.headline)

                                TextEditor(text: $jsonInput)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(minHeight: 120, maxHeight: 200)
                                    .border(Color.gray.opacity(0.3))

                                if let error = errorMessage {
                                    Text(error)
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                }

                                HStack {
                                    Spacer()
                                    Button("导入配置") {
                                        importConfig()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(jsonInput.isEmpty)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 500)
        .onAppear {
            loadHelp()
        }
    }

    private func loadHelp() {
        isLoading = true

        DispatchQueue.global().async {
            let result = HelpParser.shared.getHelpOutput(command)
            let parsed = HelpParser.shared.parseHelp(result.output, command: command)
            let prompt = PromptGenerator.shared.generateCopyablePrompt(
                command: command,
                helpText: result.output,
                parsedHelp: parsed
            )

            DispatchQueue.main.async {
                helpText = result.output
                parsedHelp = parsed
                aiPrompt = prompt
                isLoading = false
            }
        }
    }

    private func importConfig() {
        errorMessage = nil

        do {
            let config = try ConfigManager.shared.parseConfig(from: jsonInput)

            // 保存到 iCloud
            try ConfigManager.shared.saveConfig(config, name: config.name)

            // 转换为 Action 并导入
            let action = config.toAction()
            onImport(action)
        } catch {
            errorMessage = "JSON 解析失败: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ImportView(
        command: "ffmpeg",
        onCancel: {},
        onImport: { _ in }
    )
    .frame(width: 600, height: 700)
}
