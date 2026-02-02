import Foundation

/// 内置 Pipeline 配置（示例）
/// Built-in pipeline configurations (examples)
struct BuiltInPipelines {
    static var all: [Pipeline] {
        [
            downloadAndConvert
        ]
    }

    /// 下载并转换：curl -> convert
    static var downloadAndConvert: Pipeline {
        Pipeline(
            name: "download-convert",
            label: "下载并转图片",
            steps: ["curl", "convert"],
            stepOptions: ["convert": ["-resize", "800x600"]],
            cleanupIntermediates: true
        )
    }
}
