import SwiftUI
import UniformTypeIdentifiers

/// 批量输入模式
enum BatchInputMode {
    case single     // 单项输入（默认）
    case multiple   // 多项输入
}

/// 批量输入视图
struct BatchInputView: View {
    @Binding var singleInput: String
    @Binding var batchInputs: [String]
    @Binding var mode: BatchInputMode

    var inputLabel: String = "输入"
    var placeholder: String = ""
    var allowedExtensions: [String] = []  // 文件夹选择时过滤的扩展名

    @State private var batchText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Design.spacingMedium) {
            // 标签行
            HStack {
                Text(inputLabel)
                    .font(.headline)

                Spacer()

                if mode == .multiple {
                    Text("批量模式 (\(batchInputs.count) 项)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("退出批量") {
                        exitBatchMode()
                    }
                    .font(.caption)
                }
            }

            // 输入区域
            if mode == .single {
                singleInputView
            } else {
                batchInputListView
            }
        }
    }

    // MARK: - 单项输入

    private var singleInputView: some View {
        HStack(alignment: .top, spacing: Design.spacingMedium) {
            // 使用 TextEditor 保持原有高度
            TextEditor(text: $singleInput)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 60, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(Design.paddingMedium)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(Design.cornerRadiusMedium)
                .overlay(
                    RoundedRectangle(cornerRadius: Design.cornerRadiusMedium)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if singleInput.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, Design.paddingLarge)
                            .padding(.vertical, Design.paddingLarge)
                            .allowsHitTesting(false)
                    }
                }

            // 菜单按钮
            Menu {
                Button("选择文件夹（批量）") {
                    selectFolder()
                }
                Button("多行输入（批量）") {
                    enterBatchMode()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
            .padding(.top, Design.paddingMedium)
        }
    }

    // MARK: - 批量输入列表

    private var batchInputListView: some View {
        VStack(alignment: .leading, spacing: Design.spacingMedium) {
            // 输入列表
            ScrollView {
                VStack(alignment: .leading, spacing: Design.spacingSmall) {
                    ForEach(Array(batchInputs.enumerated()), id: \.offset) { index, input in
                        HStack {
                            Text(input)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button {
                                batchInputs.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, Design.paddingMedium)
                        .padding(.vertical, Design.paddingSmall)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(Design.cornerRadiusSmall)
                    }
                }
                .padding(Design.paddingMedium)
            }
            .frame(minHeight: 100, maxHeight: 200)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(Design.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: Design.cornerRadiusMedium)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )

            // 添加更多
            HStack {
                Menu {
                    Button("添加文件") {
                        addFiles()
                    }
                    Button("选择文件夹") {
                        selectFolder()
                    }
                    Button("粘贴多行文本") {
                        pasteMultipleLines()
                    }
                } label: {
                    Label("添加更多...", systemImage: "plus.circle")
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)

                Spacer()

                Button("清空") {
                    batchInputs.removeAll()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
    }

    // MARK: - Actions

    private func enterBatchMode() {
        mode = .multiple
        if !singleInput.isEmpty {
            batchInputs = [singleInput]
        }
        pasteMultipleLines()
    }

    private func exitBatchMode() {
        mode = .single
        singleInput = batchInputs.first ?? ""
        batchInputs = []
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            loadFilesFromFolder(url)
        }
    }

    private func addFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true

        if !allowedExtensions.isEmpty {
            panel.allowedContentTypes = allowedExtensions.compactMap {
                UTType(filenameExtension: $0)
            }
        }

        if panel.runModal() == .OK {
            let newInputs = panel.urls.map { $0.path }
            batchInputs.append(contentsOf: newInputs)
            if mode == .single {
                mode = .multiple
            }
        }
    }

    private func loadFilesFromFolder(_ folderURL: URL) {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var files: [String] = []

        while let fileURL = enumerator.nextObject() as? URL {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true else {
                continue
            }

            // 过滤扩展名
            if allowedExtensions.isEmpty || allowedExtensions.contains(fileURL.pathExtension.lowercased()) {
                files.append(fileURL.path)
            }
        }

        files.sort()
        batchInputs = files
        mode = .multiple
    }

    private func pasteMultipleLines() {
        let alert = NSAlert()
        alert.messageText = "粘贴多行输入"
        alert.informativeText = "每行一个输入（文件路径或 URL）"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        textView.isEditable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        alert.accessoryView = scrollView

        if alert.runModal() == .alertFirstButtonReturn {
            let text = textView.string
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            if !lines.isEmpty {
                batchInputs.append(contentsOf: lines)
                mode = .multiple
            }
        }
    }
}
