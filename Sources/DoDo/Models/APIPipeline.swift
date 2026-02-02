import Foundation
import SwiftData

/// API 组合步骤
struct APIPipelineStep: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var endpointId: UUID
    var inputMappings: [String: String]  // 变量名 -> 参数位置（如 "companyId" -> "{{companyId}}"）

    init(endpointId: UUID, inputMappings: [String: String] = [:]) {
        self.id = UUID()
        self.endpointId = endpointId
        self.inputMappings = inputMappings
    }
}

/// API 组合
@Model
final class APIPipeline {
    var id: UUID = UUID()
    var name: String = ""
    var descriptionText: String?
    var stepsData: Data?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(name: String = "", description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.descriptionText = description
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Computed Properties

    var steps: [APIPipelineStep] {
        get {
            guard let data = stepsData else { return [] }
            return (try? JSONDecoder().decode([APIPipelineStep].self, from: data)) ?? []
        }
        set {
            stepsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// 添加步骤
    func addStep(_ step: APIPipelineStep) {
        var currentSteps = steps
        currentSteps.append(step)
        steps = currentSteps
    }

    /// 移除步骤
    func removeStep(at index: Int) {
        var currentSteps = steps
        guard index >= 0 && index < currentSteps.count else { return }
        currentSteps.remove(at: index)
        steps = currentSteps
    }

    /// 移动步骤
    func moveStep(from source: Int, to destination: Int) {
        var currentSteps = steps
        guard source >= 0 && source < currentSteps.count else { return }
        guard destination >= 0 && destination <= currentSteps.count else { return }
        let step = currentSteps.remove(at: source)
        currentSteps.insert(step, at: destination > source ? destination - 1 : destination)
        steps = currentSteps
    }
}

// MARK: - Export/Import

extension APIPipeline {
    struct ExportData: Codable {
        var name: String
        var description: String?
        var steps: [APIPipelineStep]
    }

    func toExportData() -> ExportData {
        ExportData(
            name: name,
            description: descriptionText,
            steps: steps
        )
    }

    static func fromExportData(_ data: ExportData) -> APIPipeline {
        let pipeline = APIPipeline(name: data.name, description: data.description)
        pipeline.steps = data.steps
        return pipeline
    }
}
