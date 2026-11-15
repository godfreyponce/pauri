import AppKit
import SwiftUI

/// The OpenAI Blossom and model name on a capsule, then the effort bars.
/// Sizes come from variant A of design-directions/issue-17.html.
struct ModelPicker: View {
    let chat: Chat

    @Environment(\.colorScheme) private var colorScheme

    /// The official files, unmodified (https://openai.com/brand/). Nil under `swift test`, which has no app bundle.
    @MainActor private static let blossomBlack = blossom("OAI_OpenAI-Blossom_Black")
    @MainActor private static let blossomWhite = blossom("OAI_OpenAI-Blossom_White")

    private static func blossom(_ name: String) -> NSImage? {
        Bundle.main.url(forResource: name, withExtension: "svg").flatMap(NSImage.init(contentsOf:))
    }

    /// The Blossom already says OpenAI, so a leading "GPT" is dropped. Display only: Codex still gets the model's id.
    nonisolated static func label(_ name: String?) -> String {
        guard let name else { return "Codex default" }
        for prefix in ["GPT-", "GPT "] where name.count > prefix.count && name.uppercased().hasPrefix(prefix) {
            return String(name.dropFirst(prefix.count))
        }
        return name
    }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                if let logo = colorScheme == .dark ? Self.blossomWhite : Self.blossomBlack {
                    // The whole 716 canvas, so the logo keeps its clear space.
                    Image(nsImage: logo)
                        .resizable()
                        .frame(width: 22, height: 22)
                        .accessibilityHidden(true)
                }
                Menu {
                    ForEach(chat.modelChoices) { choice in
                        // By id, so the current model stays checked after an effort change.
                        Toggle(Self.label(choice.name), isOn: Binding(get: { chat.model?.id == choice.id }, set: { _ in chat.model = choice }))
                            .help(choice.help)
                    }
                } label: {
                    Text(Self.label(chat.model?.name))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Model")
                .disabled(chat.modelChoices.isEmpty)
            }
            .padding(.leading, 1)
            .padding(.trailing, 9)
            .frame(height: 24)
            // Keeps the Blossom off a busy window behind the see-through panel.
            .background(.regularMaterial, in: Capsule())
            if let model = chat.model, !model.efforts.isEmpty {
                effortBars(model)
            }
        }
        // A change mid-turn would not reach the running turn.
        .disabled(chat.isAnswering || chat.isWritingHandoff)
    }

    private func effortBars(_ model: ModelChoice) -> some View {
        let levels = model.efforts
        let current = levels.firstIndex { $0.reasoningEffort == model.effort }
        let description = current.map { levels[$0].description } ?? ""
        return Button {
            chat.model = model.nextEffort()
        } label: {
            HStack(spacing: 6) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(levels.indices, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(barColor(index, current: current, last: levels.count - 1, effort: model.effort))
                            .frame(width: 3, height: (12 * (0.45 + 0.55 * Double(index + 1) / Double(levels.count))).rounded())
                    }
                }
                Text(model.effort)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Reasoning: \(model.effort). \(description)")
        .accessibilityLabel("Reasoning effort")
        .accessibilityValue(model.effort)
    }

    /// Filled up to the current level; a filled top bar is `ultra`, the most usage, so it is orange.
    private func barColor(_ index: Int, current: Int?, last: Int, effort: String) -> Color {
        guard let current, index <= current else { return .primary.opacity(0.22) }
        return index == last && effort == "ultra" ? .orange : .primary
    }
}
