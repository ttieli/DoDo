import Foundation

/// AI Prompt 生成器
class PromptGenerator {
    static let shared = PromptGenerator()

    private init() {}

    /// 生成 AI Prompt
    func generatePrompt(command: String, helpText: String, parsedHelp: ParsedHelp) -> String {
        let jsonExample = """
        {
          "name": "命令名",
          "label": "中文标签",
          "command": "实际命令",
          "input": {
            "type": "file|url|directory|string",
            "label": "输入标签",
            "allowMultiple": true/false,
            "placeholder": "提示文字"
          },
          "output": {
            "flag": "-o",
            "label": "输出目录",
            "default": ""
          },
          "options": [
            { "flag": "--option", "type": "bool", "label": "选项说明" },
            { "flag": "-f", "type": "string", "label": "选项说明", "placeholder": "示例" },
            { "flag": "-t", "type": "enum", "label": "选项说明", "choices": ["a", "b", "c"], "default": "a" }
          ]
        }
        """

        var prompt = """
        # 请为以下命令生成 DoDo 应用的配置 JSON

        ## 命令名称
        `\(command)`

        ## Help 输出
        ```
        \(helpText.prefix(3000))
        ```

        ## 自动分析参考信息
        \(parsedHelp.toReferenceText())

        ## 要求
        1. 根据 help 输出生成一个合理的 JSON 配置
        2. `name` 使用命令名
        3. `label` 用简短的中文描述命令功能
        4. `input.type` 根据命令用途选择：file（文件）、url（网址）、directory（目录）、string（文本）
        5. `options` 只选择最常用的 5-10 个选项，不要全部列出
        6. 选项类型：bool（开关）、string（文本）、enum（枚举，需提供 choices）
        7. 所有 label 用中文

        ## JSON 格式
        ```json
        \(jsonExample)
        ```

        ## 请直接返回 JSON，不要其他解释
        """

        return prompt
    }

    /// 生成简化版 Prompt（用于复制）
    func generateCopyablePrompt(command: String, helpText: String, parsedHelp: ParsedHelp) -> String {
        // 限制 help 文本长度
        let truncatedHelp = String(helpText.prefix(2500))

        return """
        请为命令 `\(command)` 生成 DoDo 应用的配置 JSON。

        Help 输出:
        ```
        \(truncatedHelp)
        ```

        分析参考:
        - 推断输入类型: \(parsedHelp.inferredInputType)
        - 输出选项: \(parsedHelp.outputFlag ?? "无")
        - 识别到 \(parsedHelp.options.count) 个选项

        JSON 格式要求:
        ```json
        {
          "name": "命令名",
          "label": "中文标签",
          "command": "实际命令",
          "input": { "type": "file|url|directory|string", "label": "输入标签", "allowMultiple": false, "placeholder": "提示" },
          "output": { "flag": "-o", "label": "输出目录", "default": "" },
          "options": [
            { "flag": "--xxx", "type": "bool|string|enum", "label": "中文说明" }
          ]
        }
        ```

        要求:
        1. label 用中文
        2. options 只选最常用的 5-10 个
        3. type: bool=开关, string=文本, enum=枚举(需加choices)
        4. 直接返回 JSON，无需解释
        """
    }
}
