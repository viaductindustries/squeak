import AppKit
import SqueekCore
import SwiftUI

/// A button that records the next key combination typed.
struct ShortcutRecorder: View {
    @Binding var shortcut: KeyShortcut?
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var id = UUID()

    /// Only one recorder listens at a time; starting another stops this one.
    private static var active: (id: UUID, stop: () -> Void)?

    var body: some View {
        Button(action: toggle) {
            Text(isRecording ? "Type Shortcut…" : shortcut?.displayName ?? "Record Shortcut")
                .monospacedDigit()
                .frame(minWidth: 100)
        }
        .help(isRecording ? "Press Escape to cancel" : "")
        .onDisappear(perform: stop)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            stop()
        }
    }

    static func stopActive() {
        active?.stop()
    }

    private func toggle() {
        isRecording ? stop() : start()
    }

    private func start() {
        Self.active?.stop()
        Self.active = (id, stop)
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = KeyModifiers(event.modifierFlags)
            if event.keyCode == Self.escape, modifiers.isEmpty {
                stop()
                return nil
            }
            shortcut = KeyShortcut(keyCode: event.keyCode, modifiers: modifiers, keyName: Self.keyName(for: event))
            stop()
            return nil
        }
    }

    private func stop() {
        if Self.active?.id == id { Self.active = nil }
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }

    private static let escape: UInt16 = 53

    private static let specialKeys: [UInt16: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 76: "⌤", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
        106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
    ]

    private static func keyName(for event: NSEvent) -> String {
        if let name = specialKeys[event.keyCode] { return name }
        let characters = event.characters(byApplyingModifiers: []) ?? ""
        return characters.isEmpty ? "Key \(event.keyCode)" : characters.uppercased()
    }
}

extension KeyModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.command) { insert(.command) }
    }
}
