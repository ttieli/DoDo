import Foundation

/// 配置文件管理器 - 处理 iCloud 配置文件夹的读写
class ConfigManager {
    static let shared = ConfigManager()

    /// iCloud 配置文件夹路径
    var configDirectory: URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let iCloudPath = homeDir
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/DoDo/configs")
        return iCloudPath
    }

    private init() {
        ensureConfigDirectoryExists()
    }

    /// 确保配置文件夹存在
    func ensureConfigDirectoryExists() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: configDirectory.path) {
            try? fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        }
    }

    /// 保存配置到文件
    func saveConfig(_ config: ActionConfig, name: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let fileURL = configDirectory.appendingPathComponent("\(name).json")
        try data.write(to: fileURL)
    }

    /// 从文件加载配置
    func loadConfig(name: String) throws -> ActionConfig {
        let fileURL = configDirectory.appendingPathComponent("\(name).json")
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode(ActionConfig.self, from: data)
    }

    /// 加载所有用户配置
    func loadAllConfigs() -> [ActionConfig] {
        ensureConfigDirectoryExists()
        let fileManager = FileManager.default
        var configs: [ActionConfig] = []

        guard let files = try? fileManager.contentsOfDirectory(at: configDirectory, includingPropertiesForKeys: nil) else {
            return configs
        }

        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let config = try? JSONDecoder().decode(ActionConfig.self, from: data) {
                configs.append(config)
            }
        }

        return configs
    }

    /// 删除配置文件
    func deleteConfig(name: String) throws {
        let fileURL = configDirectory.appendingPathComponent("\(name).json")
        try FileManager.default.removeItem(at: fileURL)
    }

    /// 检查配置是否存在
    func configExists(name: String) -> Bool {
        let fileURL = configDirectory.appendingPathComponent("\(name).json")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// 从 JSON 字符串解析配置
    func parseConfig(from jsonString: String) throws -> ActionConfig {
        guard let data = jsonString.data(using: .utf8) else {
            throw ConfigError.invalidJSON
        }
        return try JSONDecoder().decode(ActionConfig.self, from: data)
    }

    /// 将配置转为 JSON 字符串
    func configToJSON(_ config: ActionConfig) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

/// 配置错误
enum ConfigError: LocalizedError {
    case invalidJSON
    case fileNotFound
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .invalidJSON: return "无效的 JSON 格式"
        case .fileNotFound: return "配置文件不存在"
        case .saveFailed: return "保存配置失败"
        }
    }
}

/// 用于 JSON 导入导出的配置结构（与 Action 模型对应但可独立序列化）
struct ActionConfig: Codable {
    var name: String
    var label: String
    var command: String
    var input: InputConfigData
    var output: OutputConfigData?
    var options: [OptionData]?

    struct InputConfigData: Codable {
        var type: String
        var label: String
        var allowMultiple: Bool?
        var placeholder: String?
    }

    struct OutputConfigData: Codable {
        var flag: String
        var label: String
        var `default`: String?
    }

    struct OptionData: Codable {
        var flag: String
        var type: String
        var label: String
        var choices: [String]?
        var `default`: String?
        var placeholder: String?
    }

    /// 转换为 Action 模型
    func toAction() -> Action {
        let inputType: InputConfig.InputType
        switch input.type.lowercased() {
        case "file": inputType = .file
        case "directory": inputType = .directory
        case "url": inputType = .url
        default: inputType = .string
        }

        let inputConfig = InputConfig(
            type: inputType,
            label: input.label,
            allowMultiple: input.allowMultiple ?? false,
            placeholder: input.placeholder
        )

        var outputConfig: OutputConfig? = nil
        if let out = output {
            outputConfig = OutputConfig(
                flag: out.flag,
                label: out.label,
                defaultValue: out.default
            )
        }

        var actionOptions: [ActionOption] = []
        if let opts = options {
            for opt in opts {
                let optType: ActionOption.OptionType
                switch opt.type.lowercased() {
                case "bool": optType = .bool
                case "enum": optType = .enum
                default: optType = .string
                }

                actionOptions.append(ActionOption(
                    flag: opt.flag,
                    type: optType,
                    label: opt.label,
                    choices: opt.choices,
                    defaultValue: opt.default,
                    placeholder: opt.placeholder
                ))
            }
        }

        return Action(
            name: name,
            label: label,
            command: command,
            inputConfig: inputConfig,
            outputConfig: outputConfig,
            options: actionOptions
        )
    }

    /// 从 Action 模型创建
    static func from(_ action: Action) -> ActionConfig {
        let inputData = InputConfigData(
            type: action.inputConfig.type.rawValue,
            label: action.inputConfig.label,
            allowMultiple: action.inputConfig.allowMultiple,
            placeholder: action.inputConfig.placeholder
        )

        var outputData: OutputConfigData? = nil
        if let out = action.outputConfig {
            outputData = OutputConfigData(
                flag: out.flag,
                label: out.label,
                default: out.defaultValue
            )
        }

        var optionsData: [OptionData]? = nil
        if !action.options.isEmpty {
            optionsData = action.options.map { opt in
                OptionData(
                    flag: opt.flag,
                    type: opt.type.rawValue,
                    label: opt.label,
                    choices: opt.choices,
                    default: opt.defaultValue,
                    placeholder: opt.placeholder
                )
            }
        }

        return ActionConfig(
            name: action.name,
            label: action.label,
            command: action.command,
            input: inputData,
            output: outputData,
            options: optionsData
        )
    }
}
