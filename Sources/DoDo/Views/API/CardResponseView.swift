import SwiftUI

/// 卡片/表格响应视图（自动根据 JSON 结构转换）
struct CardResponseView: View {
    let json: Any?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let json = json {
                    AutoCardView(value: json, title: nil)
                } else {
                    Text("无数据")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 自动卡片视图（根据数据类型决定展示方式）
struct AutoCardView: View {
    let value: Any
    let title: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            if let title = title, !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            // 根据类型决定展示方式
            contentView
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if let dict = value as? [String: Any] {
            DictCardView(dict: dict)
        } else if let array = value as? [Any] {
            ArrayCardView(array: array, title: title)
        } else {
            Text(stringValue(value))
                .textSelection(.enabled)
        }
    }

    private func stringValue(_ value: Any) -> String {
        if let string = value as? String {
            return string
        } else if let number = value as? NSNumber {
            return number.stringValue
        } else if value is NSNull {
            return "-"
        } else {
            return String(describing: value)
        }
    }
}

/// 字典卡片视图
struct DictCardView: View {
    let dict: [String: Any]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 分离简单字段和复杂字段
            let (simpleFields, complexFields) = separateFields(dict)

            // 简单字段显示为键值对卡片
            if !simpleFields.isEmpty {
                KeyValueCard(fields: simpleFields)
            }

            // 复杂字段递归显示
            ForEach(Array(complexFields.keys.sorted()), id: \.self) { key in
                if let value = complexFields[key] {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(formatKey(key))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        AutoCardView(value: value, title: nil)
                    }
                }
            }
        }
    }

    /// 分离简单字段和复杂字段
    private func separateFields(_ dict: [String: Any]) -> ([String: Any], [String: Any]) {
        var simple: [String: Any] = [:]
        var complex: [String: Any] = [:]

        for (key, value) in dict {
            if value is [String: Any] || value is [Any] {
                complex[key] = value
            } else {
                simple[key] = value
            }
        }

        return (simple, complex)
    }

    /// 格式化键名
    private func formatKey(_ key: String) -> String {
        // 将驼峰转为空格分隔，或直接返回中文
        if key.contains(where: { $0.isLetter && !$0.isASCII }) {
            return key
        }

        // 驼峰转空格
        var result = ""
        for char in key {
            if char.isUppercase && !result.isEmpty {
                result += " "
            }
            result += String(char)
        }
        return result.capitalized
    }
}

/// 键值对卡片
struct KeyValueCard: View {
    let fields: [String: Any]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(fields.keys.sorted()), id: \.self) { key in
                HStack(alignment: .top, spacing: 12) {
                    Text(formatKey(key))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 80, alignment: .leading)

                    Text(stringValue(fields[key]))
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func formatKey(_ key: String) -> String {
        if key.contains(where: { $0.isLetter && !$0.isASCII }) {
            return key
        }
        var result = ""
        for char in key {
            if char.isUppercase && !result.isEmpty {
                result += " "
            }
            result += String(char)
        }
        return result.capitalized
    }

    private func stringValue(_ value: Any?) -> String {
        guard let value = value else { return "-" }
        if let string = value as? String {
            return string.isEmpty ? "-" : string
        } else if let number = value as? NSNumber {
            return number.stringValue
        } else if value is NSNull {
            return "-"
        } else {
            return String(describing: value)
        }
    }
}

/// 数组卡片视图
struct ArrayCardView: View {
    let array: [Any]
    let title: String?

    @State private var isExpanded = false

    private let defaultRowCount = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 检查是否是对象数组（可以显示为表格）
            if let firstDict = array.first as? [String: Any],
               isTableCompatible(array) {
                tableView(array.compactMap { $0 as? [String: Any] }, columns: Array(firstDict.keys.sorted()))
            } else {
                // 简单数组或混合数组
                listView
            }
        }
    }

    /// 检查数组是否可以显示为表格（所有元素都是相同结构的字典）
    private func isTableCompatible(_ array: [Any]) -> Bool {
        guard let firstDict = array.first as? [String: Any] else { return false }
        let firstKeys = Set(firstDict.keys)

        for item in array.dropFirst() {
            guard let dict = item as? [String: Any] else { return false }
            // 允许键不完全相同，但至少有交集
            let keys = Set(dict.keys)
            if keys.intersection(firstKeys).isEmpty {
                return false
            }
        }

        return true
    }

    /// 表格视图
    @ViewBuilder
    private func tableView(_ items: [[String: Any]], columns: [String]) -> some View {
        let displayItems = isExpanded ? items : Array(items.prefix(defaultRowCount))
        let hasMore = items.count > defaultRowCount

        VStack(alignment: .leading, spacing: 0) {
            // 表头
            HStack(spacing: 0) {
                ForEach(columns, id: \.self) { column in
                    Text(formatColumnName(column))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 数据行
            ForEach(Array(displayItems.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 0) {
                    ForEach(columns, id: \.self) { column in
                        Text(stringValue(item[column]))
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }
                }
                .background(index % 2 == 0 ? Color.clear : Color(nsColor: .controlBackgroundColor).opacity(0.5))
            }

            // 展开/收起按钮
            if hasMore {
                Divider()

                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if isExpanded {
                            Text("收起")
                            Image(systemName: "chevron.up")
                        } else {
                            Text("展开更多 \(items.count - defaultRowCount) 条")
                            Image(systemName: "chevron.down")
                        }
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    /// 列表视图（用于简单数组）
    @ViewBuilder
    private var listView: some View {
        let displayItems = isExpanded ? array : Array(array.prefix(defaultRowCount))
        let hasMore = array.count > defaultRowCount

        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(displayItems.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)

                    if let dict = item as? [String: Any] {
                        AutoCardView(value: dict, title: nil)
                    } else {
                        Text(stringValue(item))
                            .textSelection(.enabled)
                    }
                }
            }

            if hasMore {
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        if isExpanded {
                            Text("收起")
                            Image(systemName: "chevron.up")
                        } else {
                            Text("展开更多 \(array.count - defaultRowCount) 条")
                            Image(systemName: "chevron.down")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func formatColumnName(_ name: String) -> String {
        if name.contains(where: { $0.isLetter && !$0.isASCII }) {
            return name
        }
        var result = ""
        for char in name {
            if char.isUppercase && !result.isEmpty {
                result += " "
            }
            result += String(char)
        }
        return result.capitalized
    }

    private func stringValue(_ value: Any?) -> String {
        guard let value = value else { return "-" }
        if let string = value as? String {
            return string.isEmpty ? "-" : string
        } else if let number = value as? NSNumber {
            return number.stringValue
        } else if value is NSNull {
            return "-"
        } else if let dict = value as? [String: Any] {
            return "{\(dict.count) 项}"
        } else if let array = value as? [Any] {
            return "[\(array.count) 项]"
        } else {
            return String(describing: value)
        }
    }
}

#Preview {
    CardResponseView(
        json: [
            "Status": "200",
            "Message": "success",
            "Result": [
                "Name": "腾讯科技",
                "OperName": "马化腾",
                "StartDate": "1998-11-11",
                "Partners": [
                    ["Name": "黄惠卿", "StockPercent": "54.29%", "Amount": "3252万"],
                    ["Name": "马化腾", "StockPercent": "28.57%", "Amount": "1714万"],
                    ["Name": "许晨晔", "StockPercent": "5.71%", "Amount": "343万"],
                    ["Name": "陈一丹", "StockPercent": "5.71%", "Amount": "343万"],
                    ["Name": "张志东", "StockPercent": "5.71%", "Amount": "343万"],
                    ["Name": "测试1", "StockPercent": "0%", "Amount": "0"],
                    ["Name": "测试2", "StockPercent": "0%", "Amount": "0"]
                ]
            ] as [String : Any]
        ] as [String : Any]
    )
    .frame(width: 500, height: 600)
}
