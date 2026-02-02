import Foundation
import SwiftData

/// 命令执行模式
enum CommandMode: String, Codable {
    case standard = "standard"  // 标准模式: 命令 [选项] 输入 -o 输出
    case pipe = "pipe"          // 管道模式: cat 输入 | 命令 [选项] > 输出
}

/// 支持的文件格式
enum FileFormat: String, Codable, CaseIterable {
    case url = "url"
    case md = "md"
    case docx = "docx"
    case pdf = "pdf"
    case png = "png"
    case jpg = "jpg"
    case html = "html"
    case text = "text"
    case json = "json"
    case latex = "latex"
    case directory = "directory"

    var displayName: String {
        switch self {
        case .url: return "网址"
        case .md: return "Markdown"
        case .docx: return "Word文档"
        case .pdf: return "PDF"
        case .png: return "PNG图片"
        case .jpg: return "JPG图片"
        case .html: return "HTML"
        case .text: return "纯文本"
        case .json: return "JSON"
        case .latex: return "LaTeX"
        case .directory: return "目录"
        }
    }
}

/// 输出格式配置（格式与对应的命令选项）
struct OutputFormatConfig: Codable, Hashable {
    var format: FileFormat
    var requiredOptions: [String]  // 需要的命令选项，如 ["--image"]

    init(_ format: FileFormat, options: [String] = []) {
        self.format = format
        self.requiredOptions = options
    }
}

/// 命令配置
@Model
final class Action {
    var id: UUID
    var name: String           // 命令名，如 "wf"
    var label: String          // 中文标签，如 "网页抓取"
    var command: String        // 基础命令
    var inputConfig: InputConfig
    var outputConfig: OutputConfig?
    var options: [ActionOption]
    var supportedInputFormats: [FileFormat]      // 支持的输入格式
    var supportedOutputFormats: [OutputFormatConfig]  // 支持的输出格式及对应选项
    var commandModeRaw: String?  // 命令执行模式（可选，nil 表示标准模式）
    var createdAt: Date
    var updatedAt: Date

    /// 命令执行模式
    var commandMode: CommandMode {
        get { CommandMode(rawValue: commandModeRaw ?? "standard") ?? .standard }
        set { commandModeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        label: String,
        command: String,
        inputConfig: InputConfig,
        outputConfig: OutputConfig? = nil,
        options: [ActionOption] = [],
        supportedInputFormats: [FileFormat] = [],
        supportedOutputFormats: [OutputFormatConfig] = [],
        commandMode: CommandMode = .standard,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.label = label
        self.command = command
        self.inputConfig = inputConfig
        self.outputConfig = outputConfig
        self.options = options
        self.commandModeRaw = commandMode.rawValue
        self.supportedInputFormats = supportedInputFormats
        self.supportedOutputFormats = supportedOutputFormats
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 获取与下一步兼容的输出格式
    func compatibleOutputFormats(for nextAction: Action) -> [OutputFormatConfig] {
        let nextInputs = Set(nextAction.supportedInputFormats)
        return supportedOutputFormats.filter { nextInputs.contains($0.format) }
    }
}

/// 输入配置
struct InputConfig: Codable {
    var type: InputType
    var label: String
    var allowMultiple: Bool
    var placeholder: String?

    enum InputType: String, Codable {
        case file
        case directory
        case url
        case string
    }

    init(type: InputType, label: String, allowMultiple: Bool = false, placeholder: String? = nil) {
        self.type = type
        self.label = label
        self.allowMultiple = allowMultiple
        self.placeholder = placeholder
    }
}

/// 输出配置
struct OutputConfig: Codable {
    var flag: String           // 如 "-o"
    var label: String
    var defaultValue: String?

    init(flag: String, label: String, defaultValue: String? = nil) {
        self.flag = flag
        self.label = label
        self.defaultValue = defaultValue
    }
}

/// 命令选项
struct ActionOption: Codable, Identifiable {
    var id: UUID
    var flag: String           // 如 "--ocr"
    var type: OptionType
    var label: String
    var choices: [String]?     // type=enum 时
    var defaultValue: String?
    var placeholder: String?

    enum OptionType: String, Codable {
        case bool
        case string
        case `enum`
    }

    init(
        id: UUID = UUID(),
        flag: String,
        type: OptionType,
        label: String,
        choices: [String]? = nil,
        defaultValue: String? = nil,
        placeholder: String? = nil
    ) {
        self.id = id
        self.flag = flag
        self.type = type
        self.label = label
        self.choices = choices
        self.defaultValue = defaultValue
        self.placeholder = placeholder
    }
}
