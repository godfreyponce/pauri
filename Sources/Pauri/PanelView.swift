import AppKit
import SwiftUI

struct PanelView: View {
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack {
            Spacer()
            TextField("Ask Pauri", text: $draft)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
        }
        .padding()
        // The panel is the app's only window that can become key, and it does so on every show.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            focused = true
        }
    }
}
