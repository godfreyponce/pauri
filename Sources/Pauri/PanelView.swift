import AppKit
import SwiftUI

struct PanelView: View {
    let hotKey: HotKey
    @State private var draft = ""
    @State private var showsSettings = false
    @FocusState private var focused: Bool
    @AppStorage(Transparency.key) private var transparency = Transparency.default

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button { showsSettings = true } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.borderless)
                    .help("Settings")
                    .popover(isPresented: $showsSettings) { SettingsView(hotKey: hotKey) }
            }
            Spacer()
            TextField("Ask Pauri", text: $draft)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
        }
        .padding()
        .background {
            Color(nsColor: .windowBackgroundColor).opacity(1 - transparency).ignoresSafeArea()
        }
        // The panel becomes key on every show. The settings popover is a window that also becomes
        // key, and moving focus to the text field then would close the popover.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            if note.object is FloatingPanel { focused = true }
        }
    }
}
