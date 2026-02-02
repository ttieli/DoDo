import Foundation

/// 配置加载器（用于从文件加载配置）
class ConfigLoader {

    /// 从 JSON 文件加载配置
    static func loadFromFile(_ url: URL) throws -> Action {
        let data = try Data(contentsOf: url)
        return try loadFromData(data)
    }

    /// 从 JSON 数据加载配置
    static func loadFromData(_ data: Data) throws -> Action {
        let decoder = JSONDecoder()
        let config = try decoder.decode(ActionConfig.self, from: data)
        return config.toAction()
    }

    /// 从 JSON 字符串加载配置
    static func loadFromString(_ json: String) throws -> Action {
        guard let data = json.data(using: .utf8) else {
            throw ConfigError.invalidJSON
        }
        return try loadFromData(data)
    }

    /// 导出 Action 为 JSON
    static func exportToJSON(_ action: Action) throws -> String {
        let config = ActionConfig.from(action)
        return try ConfigManager.shared.configToJSON(config)
    }
}
