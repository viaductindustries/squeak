#if DEBUG
import AppKit
import SqueekCore
import SwiftUI

/// Renders the settings window to PNGs so layout can be checked without
/// clicking through the app: `swift run Squeek --snapshot <directory>`.
@MainActor
enum Snapshot {
    static func runIfRequested() {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--snapshot"), index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1])
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let busy = SqueekSettings(buttons: [
            ButtonMapping(button: 2, action: .normal),
            ButtonMapping(button: 2, modifiers: [.command], action: .missionControl),
            ButtonMapping(button: 2, modifiers: [.option, .shift], action: .showDesktop),
            ButtonMapping(button: 3, action: .keyboardShortcut,
                          shortcut: KeyShortcut(keyCode: 33, modifiers: [.command], keyName: "[")),
            ButtonMapping(button: 4, action: .passToOtherApps),
            ButtonMapping(button: 5, action: .openApp, appURL: URL(fileURLWithPath: "/System/Applications/System Settings.app")),
            ButtonMapping(button: 6, action: .missionControl),
            ButtonMapping(button: 7, action: .keyboardShortcut),
        ])
        let states: [(String, AppModel)] = [
            ("standard", AppModel(preview: .standard, hasAccess: true)),
            ("no-access", AppModel(preview: .standard, hasAccess: false)),
            ("busy", AppModel(preview: busy, hasAccess: true)),
            ("empty", AppModel(preview: SqueekSettings(buttons: []), hasAccess: true)),
            ("many", AppModel(preview: SqueekSettings(buttons: (2...9).flatMap { button in
                [[], [.command], [.option], [.shift, .command]].map {
                    ButtonMapping(button: button, modifiers: $0, action: .missionControl)
                }
            }), hasAccess: true)),
        ]
        for (name, model) in states {
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                let suffix = appearance == .aqua ? "light" : "dark"
                render(SettingsView(model: model), appearance: appearance,
                       to: directory.appendingPathComponent("\(name)-\(suffix).png"))
            }
        }
        exit(0)
    }

    private static func render(_ view: some View, appearance: NSAppearance.Name, to url: URL) {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        let host = NSHostingView(rootView: view)
        window.contentView = host
        window.setContentSize(host.fittingSize)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        // The form measures itself once laid out; resize to match.
        window.setContentSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
#endif
