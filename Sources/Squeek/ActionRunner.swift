import AppKit
import SqueekCore

/// Carries out the actions assigned to buttons.
@MainActor
enum ActionRunner {
    static func run(_ mapping: ButtonMapping, phase: ButtonRouter.Phase) {
        switch mapping.action {
        case .keyboardShortcut:
            // Hold the keys for as long as the button is held, so shortcuts
            // like push-to-talk work.
            if let shortcut = mapping.shortcut {
                postKey(shortcut.keyCode, modifiers: CGEventFlags(rawValue: shortcut.modifiers.rawValue), down: phase == .down)
            }
        default:
            guard phase == .down else { return }
            runOnce(mapping)
        }
    }

    private static func runOnce(_ mapping: ButtonMapping) {
        switch mapping.action {
        case .missionControl: sendDockNotification("com.apple.expose.awake", fallbackArgument: nil)
        case .appWindows: sendDockNotification("com.apple.expose.front.awake", fallbackArgument: "2")
        case .showDesktop: sendDockNotification("com.apple.showdesktop.awake", fallbackArgument: "1")
        case .previousDesktop: tapKey(arrowLeft, modifiers: [.maskControl, .maskSecondaryFn])
        case .nextDesktop: tapKey(arrowRight, modifiers: [.maskControl, .maskSecondaryFn])
        case .openApp:
            if let url = mapping.appURL {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
        case .doNothing, .normal, .passToOtherApps, .middleClick, .keyboardShortcut:
            break
        }
    }

    private static let arrowLeft: UInt16 = 123
    private static let arrowRight: UInt16 = 124

    private static func tapKey(_ keyCode: UInt16, modifiers: CGEventFlags) {
        postKey(keyCode, modifiers: modifiers, down: true)
        postKey(keyCode, modifiers: modifiers, down: false)
    }

    private static func postKey(_ keyCode: UInt16, modifiers: CGEventFlags, down: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down) else { return }
        event.flags = modifiers
        event.post(tap: .cghidEventTap)
    }

    private typealias DockNotification = @convention(c) (CFString, UnsafeMutableRawPointer?) -> Void

    /// The Dock's own notifications are the most reliable way to trigger
    /// Mission Control. They're private, so fall back to the Mission Control
    /// app if they ever disappear.
    private static let coreDockSendNotification: DockNotification? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CoreDockSendNotification") else { return nil }
        return unsafeBitCast(symbol, to: DockNotification.self)
    }()

    private static func sendDockNotification(_ name: String, fallbackArgument: String?) {
        if let coreDockSendNotification {
            coreDockSendNotification(name as CFString, nil)
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = fallbackArgument.map { [$0] } ?? []
        let url = URL(fileURLWithPath: "/System/Applications/Mission Control.app")
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }
}
