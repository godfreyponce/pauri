import SwiftUI

/// Asks before a write or any other command runs, from variant A of
/// `design-directions/issue-5.html`. No button answers Return, so a Return meant for the text
/// field never approves.
struct ApprovalCard: View {
    let request: ApprovalRequest
    /// Nil when Pauri never saw the item's `item/started`.
    let step: ToolStep?
    let decide: (ApprovalChoice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let step {
                Text(stepLabel(step.label))
                    .fontWeight(.semibold)
                codeBox(Text(step.detail))
                // A file step's output is its diff; a command waiting here has no output yet.
                if !step.output.isEmpty {
                    codeBox(Text(diff(step.output)).foregroundStyle(.secondary))
                }
            }
            Text(request.reason ?? "Codex wants to run a command or change a file.")
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Spacer()
                Button("Deny") { decide(.deny) }
                Button("Allow for this chat") { decide(.allowForChat) }
                Button("Allow") { decide(.allow) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(10)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.2)))
    }

    private func codeBox(_ text: Text) -> some View {
        text
            .font(.system(size: 11, design: .monospaced))
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }

    private func diff(_ output: String) -> AttributedString {
        var result = AttributedString()
        for (index, line) in output.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            var part = AttributedString((index == 0 ? "" : "\n") + line)
            if line.hasPrefix("+") { part.foregroundColor = .green }
            if line.hasPrefix("-") { part.foregroundColor = .red }
            result += part
        }
        return result
    }
}
