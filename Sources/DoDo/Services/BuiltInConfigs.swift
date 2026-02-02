import Foundation

/// 内置命令配置（示例命令）
/// Built-in command configurations (example commands)
///
/// 你可以通过 iCloud 配置文件夹添加自己的命令：
/// ~/Library/Mobile Documents/com~apple~CloudDocs/DoDo/configs/
///
/// You can add your own commands via the iCloud config folder:
/// ~/Library/Mobile Documents/com~apple~CloudDocs/DoDo/configs/
enum BuiltInConfigs {

    /// 所有内置命令
    static var all: [Action] {
        [curl, ffmpeg, imagemagick]
    }

    // MARK: - curl (HTTP Client)

    static var curl: Action {
        Action(
            name: "curl",
            label: "HTTP 请求",
            command: "curl",
            inputConfig: InputConfig(
                type: .url,
                label: "URL",
                allowMultiple: false,
                placeholder: "https://api.example.com/data"
            ),
            outputConfig: OutputConfig(
                flag: "-o",
                label: "输出文件",
                defaultValue: ""
            ),
            options: [
                ActionOption(
                    flag: "-s",
                    type: .bool,
                    label: "静默模式"
                ),
                ActionOption(
                    flag: "-L",
                    type: .bool,
                    label: "跟随重定向"
                ),
                ActionOption(
                    flag: "-H",
                    type: .string,
                    label: "Header",
                    placeholder: "Content-Type: application/json"
                ),
                ActionOption(
                    flag: "--connect-timeout",
                    type: .string,
                    label: "超时(秒)",
                    placeholder: "30"
                )
            ],
            supportedInputFormats: [.url],
            supportedOutputFormats: [OutputFormatConfig(.json), OutputFormatConfig(.text)]
        )
    }

    // MARK: - ffmpeg (Media Converter)

    static var ffmpeg: Action {
        Action(
            name: "ffmpeg",
            label: "媒体转换",
            command: "ffmpeg",
            inputConfig: InputConfig(
                type: .file,
                label: "输入文件",
                allowMultiple: false,
                placeholder: "选择音视频文件"
            ),
            outputConfig: OutputConfig(
                flag: "",
                label: "输出文件",
                defaultValue: ""
            ),
            options: [
                ActionOption(
                    flag: "-y",
                    type: .bool,
                    label: "覆盖输出文件"
                ),
                ActionOption(
                    flag: "-vcodec",
                    type: .enum,
                    label: "视频编码",
                    choices: ["libx264", "libx265", "copy"],
                    defaultValue: "libx264"
                ),
                ActionOption(
                    flag: "-acodec",
                    type: .enum,
                    label: "音频编码",
                    choices: ["aac", "mp3", "copy"],
                    defaultValue: "aac"
                )
            ],
            supportedInputFormats: [.md, .text],  // 代表通用文件
            supportedOutputFormats: [OutputFormatConfig(.md), OutputFormatConfig(.text)]
        )
    }

    // MARK: - convert (ImageMagick)

    static var imagemagick: Action {
        Action(
            name: "convert",
            label: "图片转换",
            command: "convert",
            inputConfig: InputConfig(
                type: .file,
                label: "输入图片",
                allowMultiple: true,
                placeholder: "选择图片文件"
            ),
            outputConfig: OutputConfig(
                flag: "",
                label: "输出文件",
                defaultValue: ""
            ),
            options: [
                ActionOption(
                    flag: "-resize",
                    type: .string,
                    label: "调整大小",
                    placeholder: "800x600"
                ),
                ActionOption(
                    flag: "-quality",
                    type: .string,
                    label: "质量",
                    placeholder: "85"
                ),
                ActionOption(
                    flag: "-strip",
                    type: .bool,
                    label: "移除元数据"
                )
            ],
            supportedInputFormats: [.png, .jpg, .pdf],
            supportedOutputFormats: [
                OutputFormatConfig(.png),
                OutputFormatConfig(.jpg),
                OutputFormatConfig(.pdf)
            ]
        )
    }
}
