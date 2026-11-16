import AppKit
import SqueekCore
import SwiftUI

struct SettingsView: View {
    static let windowID = "settings"

    @Bindable var model: AppModel

    var body: some View {
        Form {
            if !model.hasAccess {
                Section {
                    HStack {
                        Label("Squeek needs Accessibility access.", systemImage: "exclamationmark.triangle.fill")
                            .symbolRenderingMode(.multicolor)
                        Spacer()
                        Button("Open System Settings") { model.openAccessibilitySettings() }
                    }
                }
            }

            Section("Buttons") {
                ForEach(model.settings.buttons) { mapping in
                    ButtonRow(mapping: mapping, model: model)
                }
                AddButtonRow(model: model)
            }

            Section {
                Toggle("Open at login", isOn: Binding(
                    get: { model.opensAtLogin },
                    set: { model.setOpensAtLogin($0) }
                ))
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .onDisappear { model.isCapturing = false }
    }
}

private struct ButtonRow: View {
    let mapping: ButtonMapping
    let model: AppModel

    private var binding: Binding<ButtonMapping> {
        Binding(get: { model.binding(for: mapping.button) ?? mapping }, set: { model.update($0) })
    }

    var body: some View {
        LabeledContent(mapping.buttonName) {
            HStack(spacing: 8) {
                switch mapping.action {
                case .keyboardShortcut: ShortcutRecorder(shortcut: binding.shortcut).fixedSize()
                case .openApp: AppChooser(url: binding.appURL).frame(maxWidth: 180).fixedSize(horizontal: false, vertical: true)
                default: EmptyView()
                }

                Picker(mapping.buttonName, selection: binding.action) {
                    ForEach(Self.groups, id: \.self) { group in
                        ForEach(group, id: \.self) { Text($0.title).tag($0) }
                        if group != Self.groups.last { Divider() }
                    }
                }
                .labelsHidden()
                .fixedSize()
                .help(helpText)

                // Keep the pickers lined up whether or not a row can be removed.
                Group {
                    if mapping.isRemovable {
                        Button { model.remove(button: mapping.button) } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove")
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 16)
            }
        }
    }

    private var helpText: String {
        mapping.action == .passToOtherApps ? "Ignored in browsers. Other apps see the button as normal." : ""
    }

    private static let groups: [[ActionKind]] = [
        [.doNothing, .normal, .passToOtherApps],
        [.keyboardShortcut, .middleClick],
        [.missionControl, .appWindows, .showDesktop, .previousDesktop, .nextDesktop],
        [.openApp],
    ]
}

private struct AddButtonRow: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack {
            if model.isCapturing {
                Text("Press a mouse button…")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { model.isCapturing = false }
            } else {
                Button("Add Button…") { model.isCapturing = true }
                    .disabled(!model.hasAccess)
                Spacer()
            }
        }
    }
}

private struct AppChooser: View {
    @Binding var url: URL?

    var body: some View {
        Button(action: choose) {
            if let url {
                HStack(spacing: 4) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(FileManager.default.displayName(atPath: url.path))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } else {
                Text("Choose App…")
            }
        }
        .help(url?.path ?? "")
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let chosen = panel.url {
            url = chosen
        }
    }
}
