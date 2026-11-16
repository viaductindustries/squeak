import AppKit
import SwiftUI

@main
struct SqueakApp: App {
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

        Settings {
            SettingsView(model: model)
        }
    }
}

struct MenuContent: View {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if !model.hasAccess {
            Button("Allow Accessibility Access…") { model.openAccessibilitySettings() }
            Divider()
        }
        Toggle("Pause", isOn: $model.isPaused)
        Divider()
        Button("Settings…") {
            openSettings()
            bringSettingsToFront()
        }
        .keyboardShortcut(",")
        Button("Quit Squeak") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// Squeak has no Dock icon, so macOS doesn't bring its windows forward on
    /// its own. Wait for the menu to close (it hands focus back to the app
    /// underneath), then activate and raise the window explicitly.
    private func bringSettingsToFront() {
        DispatchQueue.main.async {
            NSApp.activate()
            // SwiftUI names the settings window com_apple_SwiftUI_Settings_window.
            let windows = NSApp.windows.filter { $0.identifier?.rawValue.contains("Settings") == true }
            for window in windows {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }
}
