import AppKit
import SqueekCore
import SwiftUI

struct SettingsView: View {
    static let windowID = "settings"

    @Bindable var model: AppModel
    /// The form's full height, so the window can fit it and only scroll once
    /// it's taller than `maxHeight`.
    @State private var contentHeight: CGFloat = 320
    private static let maxHeight: CGFloat = 640

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
        .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentSize.height }) { _, height in
            contentHeight = height
        }
        .frame(width: 500, height: min(contentHeight, Self.maxHeight))
        .onDisappear { model.isCapturing = false }
    }
}

private struct ButtonRow: View {
    let mapping: ButtonMapping
    let model: AppModel

    private var binding: Binding<ButtonMapping> {
        Binding(get: { model.mapping(for: mapping.trigger) ?? mapping }, set: { model.update($0) })
    }

    var body: some View {
        LabeledContent(mapping.trigger.displayName) {
            HStack(spacing: 8) {
                switch mapping.action {
                case .keyboardShortcut: ShortcutRecorder(shortcut: binding.shortcut).fixedSize()
                case .openApp: AppChooser(url: binding.appURL).frame(maxWidth: 180).fixedSize(horizontal: false, vertical: true)
                default: EmptyView()
                }

                Picker(mapping.trigger.displayName, selection: binding.action) {
                    ForEach(Self.groups, id: \.self) { group in
                        ForEach(group, id: \.self) { Text($0.title).tag($0) }
                        if group != Self.groups.last { Divider() }
                    }
                }
                .labelsHidden()
                .fixedSize()
                .help(helpText)

                Button { model.remove(mapping.trigger) } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help("Remove")
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
                Text("Hold any keys and press a mouse button…")
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
