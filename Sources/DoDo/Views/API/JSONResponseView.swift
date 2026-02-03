import SwiftUI

/// JSON 响应视图（格式化显示）
struct JSONResponseView: View {
    let json: Any?
    let rawData: Data?

    @State private var expandedPaths: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let json = json {
                    JSONNodeView(
                        value: json,
                        path: "$",
                        expandedPaths: $expandedPaths,
                        indentLevel: 0
                    )
                } else if let data = rawData,
                          let text = String(data: data, encoding: .utf8) {
                    Text(text)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                } else {
                    Text("无数据")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Design.paddingLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(Design.cornerRadius)
    }
}

/// JSON 节点视图
struct JSONNodeView: View {
    let value: Any
    let path: String
    @Binding var expandedPaths: Set<String>
    let indentLevel: Int

    private let indent: CGFloat = 16

    var body: some View {
        Group {
            if let dict = value as? [String: Any] {
                objectView(dict)
            } else if let array = value as? [Any] {
                arrayView(array)
            } else {
                primitiveView(value)
            }
        }
    }

    // MARK: - Object View

    private func objectView(_ dict: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: Design.spacingTight) {
            if dict.isEmpty {
                Text("{}")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                let isExpanded = expandedPaths.contains(path) || indentLevel == 0

                HStack(spacing: Design.spacingSmall) {
                    Button {
                        toggleExpanded()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Text("{")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)

                    if !isExpanded {
                        Text("\(dict.count) 项")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("}")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                if isExpanded {
                    ForEach(Array(dict.keys.sorted()), id: \.self) { key in
                        HStack(alignment: .top, spacing: 0) {
                            Spacer().frame(width: indent)

                            Text("\"\(key)\"")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.blue)

                            Text(": ")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)

                            JSONNodeView(
                                value: dict[key]!,
                                path: "\(path).\(key)",
                                expandedPaths: $expandedPaths,
                                indentLevel: indentLevel + 1
                            )
                        }
                    }

                    Text("}")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Array View

    private func arrayView(_ array: [Any]) -> some View {
        VStack(alignment: .leading, spacing: Design.spacingTight) {
            if array.isEmpty {
                Text("[]")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                let isExpanded = expandedPaths.contains(path)

                HStack(spacing: Design.spacingSmall) {
                    Button {
                        toggleExpanded()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Text("[")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)

                    if !isExpanded {
                        Text("\(array.count) 项")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("]")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                if isExpanded {
                    ForEach(Array(array.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 0) {
                            Spacer().frame(width: indent)

                            Text("\(index): ")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)

                            JSONNodeView(
                                value: item,
                                path: "\(path)[\(index)]",
                                expandedPaths: $expandedPaths,
                                indentLevel: indentLevel + 1
                            )
                        }
                    }

                    Text("]")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Primitive View

    private func primitiveView(_ value: Any) -> some View {
        Group {
            if let string = value as? String {
                Text("\"\(string)\"")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.green)
                    .textSelection(.enabled)
            } else if let number = value as? NSNumber {
                if CFGetTypeID(number) == CFBooleanGetTypeID() {
                    Text(number.boolValue ? "true" : "false")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.orange)
                } else {
                    Text("\(number)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.purple)
                }
            } else if value is NSNull {
                Text("null")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.red)
            } else {
                Text(String(describing: value))
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    // MARK: - Actions

    private func toggleExpanded() {
        if expandedPaths.contains(path) {
            expandedPaths.remove(path)
        } else {
            expandedPaths.insert(path)
        }
    }
}

#Preview {
    JSONResponseView(
        json: [
            "Status": "200",
            "Message": "success",
            "Result": [
                "Name": "腾讯",
                "KeyNo": "abc123",
                "Items": [
                    ["name": "股东1", "ratio": "50%"],
                    ["name": "股东2", "ratio": "30%"]
                ]
            ] as [String : Any]
        ] as [String : Any],
        rawData: nil
    )
    .frame(width: 400, height: 300)
}
