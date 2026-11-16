#if DEBUG
import AppKit
import SqueakCore
import SwiftUI

/// Renders each settings tab to PNGs so layout can be checked without
/// clicking through the app: `swift run Squeak --snapshot <directory>`.
/// The tab bar itself comes from the window, so it isn't drawn.
@MainActor
enum Snapshot {
    static func runIfRequested() {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--snapshot"), index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1])
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let busy = SqueakSettings(buttons: [
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
        let capturing = AppModel(preview: .standard, hasAccess: true)
        capturing.isCapturing = true
        let many = SqueakSettings(buttons: (2...9).flatMap { button in
            [[], [.command], [.option], [.shift, .command]].map {
                ButtonMapping(button: button, modifiers: $0, action: .missionControl)
            }
        })
        let views: [(String, AnyView)] = [
            ("buttons-standard", AnyView(ButtonsTab(model: AppModel(preview: .standard, hasAccess: true)))),
            ("buttons-no-access", AnyView(ButtonsTab(model: AppModel(preview: .standard, hasAccess: false)))),
            ("buttons-busy", AnyView(ButtonsTab(model: AppModel(preview: busy, hasAccess: true), selection: Trigger(button: 3)))),
            ("buttons-app", AnyView(ButtonsTab(model: AppModel(preview: busy, hasAccess: true), selection: Trigger(button: 5)))),
            ("buttons-capturing", AnyView(ButtonsTab(model: capturing))),
            ("buttons-empty", AnyView(ButtonsTab(model: AppModel(preview: SqueakSettings(buttons: []), hasAccess: true)))),
            ("buttons-many", AnyView(ButtonsTab(model: AppModel(preview: many, hasAccess: true), selection: Trigger(button: 2, modifiers: [.command])))),
            ("general", AnyView(GeneralTab(model: AppModel(preview: .standard, hasAccess: true)))),
            ("about", AnyView(AboutTab())),
        ]
        for (name, view) in views {
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                let suffix = appearance == .aqua ? "light" : "dark"
                render(view, appearance: appearance, to: directory.appendingPathComponent("\(name)-\(suffix).png"))
            }
        }
        exit(0)
    }

    private static func render(_ view: some View, appearance: NSAppearance.Name, to url: URL) {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        // The window draws its own background; offscreen it has to be added.
        let host = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        window.contentView = host
        window.setContentSize(host.fittingSize)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        // Some views measure themselves once laid out; resize to match.
        window.setContentSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
#endif
