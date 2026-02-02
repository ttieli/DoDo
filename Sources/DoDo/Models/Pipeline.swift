import Foundation
import SwiftData

/// Pipeline 步骤配置
struct PipelineStep: Codable, Identifiable {
    var id: UUID
    var actionName: String           // Action 名称
    var outputFormat: FileFormat?    // 选择的输出格式（nil 表示使用默认）
    var extraOptions: [String]       // 额外选项

    init(
        id: UUID = UUID(),
        actionName: String,
        outputFormat: FileFormat? = nil,
        extraOptions: [String] = []
    ) {
        self.id = id
        self.actionName = actionName
        self.outputFormat = outputFormat
        self.extraOptions = extraOptions
    }
}

/// Pipeline 配置（组合命令）
@Model
final class Pipeline {
    var id: UUID
    var name: String
    var label: String
    var pipelineSteps: [PipelineStep]  // 步骤配置（包含格式选择）
    var cleanupIntermediates: Bool
    var createdAt: Date
    var updatedAt: Date

    /// 兼容旧代码：返回步骤名称列表
    var steps: [String] {
        pipelineSteps.map { $0.actionName }
    }

    /// 兼容旧代码：返回步骤选项字典
    var stepOptions: [String: [String]] {
        var result: [String: [String]] = [:]
        for step in pipelineSteps where !step.extraOptions.isEmpty {
            result[step.actionName] = step.extraOptions
        }
        return result
    }

    init(
        id: UUID = UUID(),
        name: String,
        label: String,
        steps: [String],
        stepOptions: [String: [String]] = [:],
        cleanupIntermediates: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.label = label
        self.pipelineSteps = steps.map { actionName in
            PipelineStep(
                actionName: actionName,
                extraOptions: stepOptions[actionName] ?? []
            )
        }
        self.cleanupIntermediates = cleanupIntermediates
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 新的初始化方法：使用 PipelineStep
    init(
        id: UUID = UUID(),
        name: String,
        label: String,
        pipelineSteps: [PipelineStep],
        cleanupIntermediates: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.label = label
        self.pipelineSteps = pipelineSteps
        self.cleanupIntermediates = cleanupIntermediates
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Pipeline 配置文件格式
struct PipelineConfig: Codable {
    var name: String
    var label: String
    var type: String  // "pipeline"
    var steps: [String]
    var cleanupIntermediates: Bool?

    func toPipeline() -> Pipeline {
        Pipeline(
            name: name,
            label: label,
            steps: steps,
            cleanupIntermediates: cleanupIntermediates ?? true
        )
    }

    static func from(_ pipeline: Pipeline) -> PipelineConfig {
        PipelineConfig(
            name: pipeline.name,
            label: pipeline.label,
            type: "pipeline",
            steps: pipeline.steps,
            cleanupIntermediates: pipeline.cleanupIntermediates
        )
    }
}
