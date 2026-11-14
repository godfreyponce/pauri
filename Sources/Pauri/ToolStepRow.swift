import SwiftUI

/// One gray line per step, from variant A of `design-directions/issue-5.html`. A click shows the
/// command and its output.
struct ToolStepRow: View {
    let step: ToolStep
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button { isExpanded.toggle() } label: {
                HStack(spacing: 5) {
                    Group {
                        if step.status == .inProgress {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                    }
                    .frame(width: 10)
                    Text(stepLabel(step.label))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isExpanded {
                StepDetail(step: step)
                    .padding(.leading, 15)
            }
        }
    }
}

private struct StepDetail: View {
    let step: ToolStep
    @State private var outputHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(step.detail)
            if !step.output.isEmpty {
                Divider()
                ScrollView {
                    Text(step.output)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { outputHeight = $0 }
                }
                .frame(height: min(outputHeight, 120))
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }
}

/// The part between the first and last backtick, as in "Ran `git status`", shows in monospace.
func stepLabel(_ label: String) -> AttributedString {
    guard let open = label.firstIndex(of: "`"), let close = label.lastIndex(of: "`"), open < close else {
        return AttributedString(label)
    }
    var code = AttributedString(label[label.index(after: open)..<close])
    code.font = .system(size: 11, design: .monospaced)
    return AttributedString(label[..<open]) + code + AttributedString(label[label.index(after: close)...])
}
