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
                        Toggle(choice.name, isOn: Binding(get: { chat.model.id == choice.id }, set: { _ in chat.model = choice }))
                            .help(choice.help)
                    }
                } label: {
                    Text(chat.model.name)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Model")
            }
            .padding(.leading, 1)
            .padding(.trailing, 9)
            .frame(height: 24)
            // Keeps the Blossom off a busy window behind the see-through panel.
            .background(.regularMaterial, in: Capsule())
            if !chat.model.efforts.isEmpty {
                effortBars
            }
        }
        // A change mid-turn would not reach the running turn.
        .disabled(chat.isAnswering || chat.isWritingHandoff)
    }

    private var effortBars: some View {
        let levels = chat.model.efforts
        let current = levels.firstIndex { $0.reasoningEffort == chat.model.effort }
        let description = current.map { levels[$0].description } ?? ""
        return Button {
            chat.model = chat.model.nextEffort()
        } label: {
            HStack(spacing: 6) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(levels.indices, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(barColor(index, current: current, last: levels.count - 1))
                            .frame(width: 3, height: (12 * (0.45 + 0.55 * Double(index + 1) / Double(levels.count))).rounded())
                    }
                }
                Text(chat.model.effort)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Reasoning: \(chat.model.effort). \(description)")
        .accessibilityLabel("Reasoning effort")
        .accessibilityValue(chat.model.effort)
    }

    /// Filled up to the current level; a filled top bar is `ultra`, the most usage, so it is orange.
    private func barColor(_ index: Int, current: Int?, last: Int) -> Color {
        guard let current, index <= current else { return .primary.opacity(0.22) }
        return index == last && chat.model.effort == "ultra" ? .orange : .primary
    }
}
