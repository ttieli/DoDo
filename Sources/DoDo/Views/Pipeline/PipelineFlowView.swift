import SwiftUI

/// Pipeline 节点执行状态
enum PipelineNodeStatus {
    case idle
    case running
    case success
    case failed
}

/// Pipeline 可视化流程图
struct PipelineFlowView: View {
    let pipeline: Pipeline
    let actions: [Action]

    /// 当前执行到的步骤索引 (nil = 未执行)
    var currentStep: Int?
    /// 总步骤数
    var totalSteps: Int = 0
    /// 是否正在执行
    var isRunning: Bool = false
    /// 执行是否出错
    var hasError: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(pipeline.pipelineSteps.enumerated()), id: \.element.id) { index, step in
                    let action = actions.first(where: { $0.name == step.actionName })
                    let nextAction = index + 1 < pipeline.pipelineSteps.count
                        ? actions.first(where: { $0.name == pipeline.pipelineSteps[index + 1].actionName })
                        : nil

                    // Node
                    PipelineNodeView(
                        step: step,
                        action: action,
                        index: index,
                        status: statusForStep(index)
                    )

                    // Connector to next node
                    if index < pipeline.pipelineSteps.count - 1 {
                        PipelineConnectorView(
                            currentAction: action,
                            nextAction: nextAction,
                            step: step,
                            status: connectorStatus(index)
                        )
                    }
                }

                // Output node
                PipelineOutputNodeView(
                    lastStep: pipeline.pipelineSteps.last,
                    lastAction: actions.first(where: { $0.name == pipeline.pipelineSteps.last?.actionName }),
                    status: outputNodeStatus
                )
            }
            .padding(Design.paddingLarge)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(Design.cornerRadius)
    }

    // MARK: - Status Logic

    private func statusForStep(_ index: Int) -> PipelineNodeStatus {
        guard let current = currentStep, current > 0 else {
            return .idle
        }
        let currentIndex = current - 1 // PipelineRunner uses 1-indexed currentStep
        if isRunning {
            if index < currentIndex { return .success }
            if index == currentIndex { return .running }
            return .idle
        } else {
            // Finished
            if hasError {
                if index < currentIndex { return .success }
                if index == currentIndex { return .failed }
                return .idle
            } else {
                return .success
            }
        }
    }

    private func connectorStatus(_ index: Int) -> PipelineNodeStatus {
        guard let current = currentStep, current > 0 else {
            return .idle
        }
        let currentIndex = current - 1
        if isRunning {
            if index < currentIndex { return .success }
            return .idle
        } else {
            if hasError {
                if index < currentIndex { return .success }
                return .idle
            } else {
                return .success
            }
        }
    }

    private var outputNodeStatus: PipelineNodeStatus {
        guard let current = currentStep, current > 0, !isRunning else { return .idle }
        return hasError ? .failed : .success
    }
}

/// 单个流程节点
struct PipelineNodeView: View {
    let step: PipelineStep
    let action: Action?
    let index: Int
    let status: PipelineNodeStatus

    var body: some View {
        VStack(spacing: Design.spacingSmall) {
            // Main node card
            VStack(spacing: Design.spacingSmall) {
                // Command name
                Text(step.actionName)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)

                // Label
                if let action = action {
                    Text(action.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Input formats
                if let action = action, !action.supportedInputFormats.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(action.supportedInputFormats, id: \.self) { fmt in
                            Text(fmt.rawValue)
                                .font(.system(size: 9))
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(2)
                        }
                    }
                }
            }
            .padding(.horizontal, Design.paddingLarge)
            .padding(.vertical, Design.paddingMedium)
            .frame(minWidth: 80)
            .background(backgroundForStatus)
            .cornerRadius(Design.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: Design.cornerRadiusMedium)
                    .stroke(borderColorForStatus, lineWidth: status == .running ? 2 : 1)
            )

            // Extra options below node
            if !step.extraOptions.isEmpty {
                HStack(spacing: 2) {
                    ForEach(step.extraOptions, id: \.self) { opt in
                        Text(opt)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private var backgroundForStatus: Color {
        switch status {
        case .idle: return Color(nsColor: .controlBackgroundColor)
        case .running: return Color.blue.opacity(0.1)
        case .success: return Color.green.opacity(0.08)
        case .failed: return Color.red.opacity(0.08)
        }
    }

    private var borderColorForStatus: Color {
        switch status {
        case .idle: return Color(nsColor: .separatorColor)
        case .running: return .blue
        case .success: return .green.opacity(0.5)
        case .failed: return .red.opacity(0.5)
        }
    }
}

/// 节点间连接线 + 格式兼容性
struct PipelineConnectorView: View {
    let currentAction: Action?
    let nextAction: Action?
    let step: PipelineStep
    let status: PipelineNodeStatus

    private var isCompatible: Bool {
        guard let current = currentAction, let next = nextAction else { return true }
        return !current.compatibleOutputFormats(for: next).isEmpty
    }

    private var formatLabel: String? {
        step.outputFormat?.displayName
    }

    var body: some View {
        VStack(spacing: 2) {
            // Format label above connector
            if let fmt = formatLabel {
                Text(fmt)
                    .font(.system(size: 9))
                    .foregroundStyle(isCompatible ? .green : .red)
            }

            // Arrow line
            HStack(spacing: 0) {
                Rectangle()
                    .fill(isCompatible ? connectorColor : .clear)
                    .frame(width: 30, height: isCompatible ? 2 : 1)
                    .overlay {
                        if !isCompatible {
                            Rectangle()
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                .foregroundStyle(.red)
                        }
                    }

                Image(systemName: "chevron.right")
                    .font(.system(size: 8))
                    .foregroundStyle(connectorColor)
            }
            .frame(width: 40)

            // Warning if incompatible
            if !isCompatible {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
            }
        }
    }

    private var connectorColor: Color {
        if !isCompatible { return .red }
        switch status {
        case .idle: return Color(nsColor: .separatorColor)
        case .running: return .blue
        case .success: return .green
        case .failed: return .red
        }
    }
}

/// 输出节点
struct PipelineOutputNodeView: View {
    let lastStep: PipelineStep?
    let lastAction: Action?
    let status: PipelineNodeStatus

    var body: some View {
        // Connector
        HStack(spacing: 0) {
            Rectangle()
                .fill(status == .success ? Color.green : Color(nsColor: .separatorColor))
                .frame(width: 30, height: 2)
            Image(systemName: "chevron.right")
                .font(.system(size: 8))
                .foregroundStyle(status == .success ? .green : Color(nsColor: .separatorColor))
        }
        .frame(width: 40)

        // Output node
        VStack(spacing: Design.spacingSmall) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.caption)
                .foregroundStyle(status == .success ? .green : .secondary)

            Text("输出")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let format = lastStep?.outputFormat {
                Text(format.displayName)
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, Design.paddingMedium)
        .padding(.vertical, Design.paddingMedium)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(Design.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: Design.cornerRadiusMedium)
                .stroke(
                    status == .success ? Color.green.opacity(0.5) : Color(nsColor: .separatorColor),
                    lineWidth: 1
                )
        )
    }
}
