import AppKit
import SwiftUI

@main
struct SqueekApp: App {
    @State private var model: AppModel

    init() {
        #if DEBUG
        Snapshot.runIfRequested()
        #endif
        _model = State(initialValue: AppModel())
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: model.menuBarSymbol)
        }

        Window("Squeek", id: SettingsView.windowID) {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

struct MenuContent: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if !model.hasAccess {
            Button("Allow Accessibility Access…") { model.openAccessibilitySettings() }
            Divider()
        }
        Toggle("Pause", isOn: $model.isPaused)
        Divider()
        Button("Settings…") {
            openWindow(id: SettingsView.windowID)
            bringSettingsToFront()
        }
        .keyboardShortcut(",")
        Button("Quit Squeek") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// Squeek has no Dock icon, so macOS doesn't bring its windows forward on
    /// its own. Wait for the menu to close (it hands focus back to the app
    /// underneath), then activate and raise the window explicitly.
    private func bringSettingsToFront() {
        DispatchQueue.main.async {
            NSApp.activate()
            let windows = NSApp.windows.filter { $0.identifier?.rawValue.contains(SettingsView.windowID) == true }
            for window in windows {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }
}
