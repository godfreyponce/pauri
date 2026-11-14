import AppKit
import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    let hotKey: HotKey

    var body: some View {
        Form {
            LabeledContent("Show or hide Pauri") { ShortcutRecorder(hotKey: hotKey) }
        }
        .padding()
        .frame(width: 320)
    }
}

/// Click, then press the new shortcut. The hotkey is paused while recording, so pressing the
/// current shortcut is recorded instead of hiding the panel.
struct ShortcutRecorder: View {
    let hotKey: HotKey
    @State private var recording = false
    @State private var monitor: Any?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .trailing) {
            Button(recording ? "Type shortcut" : hotKey.shortcut.displayName, action: record)
            if recording {
                Text("Use ⌘, ⌥, or ⌃. Esc cancels.").font(.caption).foregroundStyle(.secondary)
            } else if failed {
                Text("Couldn't use that shortcut. The old one still works.").font(.caption).foregroundStyle(.red)
            }
        }
        .onDisappear { if recording { stop(with: nil) } }
    }

    private func record() {
        guard !recording else { return }
        hotKey.pause()
        failed = false
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                let cancels = event.keyCode == UInt16(kVK_Escape)
                    && event.modifierFlags.isDisjoint(with: [.command, .option, .control])
                if cancels {
                    stop(with: nil)
                } else if let shortcut = Shortcut(keyCode: event.keyCode, flags: event.modifierFlags) {
                    stop(with: shortcut)
                }
            }
            return nil
        }
    }

    private func stop(with shortcut: Shortcut?) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        if let shortcut {
            failed = !hotKey.change(to: shortcut)
        } else {
            hotKey.resume()
        }
    }
}
