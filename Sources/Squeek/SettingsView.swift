import AppKit
import SqueekCore
import SwiftUI

/// The settings window: a classic Mac preferences window with a tab per page.
struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var tab: Tab
    /// The button row to start with selected, for snapshots.
    private let selection: Trigger?

    enum Tab: Hashable {
        case buttons, general, about
    }

    init(model: AppModel, tab: Tab = .buttons, selection: Trigger? = nil) {
        self.model = model
        _tab = State(initialValue: tab)
        self.selection = selection
    }

    var body: some View {
        TabView(selection: $tab) {
            ButtonsTab(model: model, selection: selection)
                .tabItem { Label("Buttons", systemImage: "computermouse") }
                .tag(Tab.buttons)
            GeneralTab(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(Tab.general)
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(Tab.about)
        }
        .onChange(of: tab) { _, _ in cancelCapture() }
        .onDisappear(perform: cancelCapture)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
            cancelCapture()
        }
    }

    private func cancelCapture() {
        model.isCapturing = false
        ShortcutRecorder.stopActive()
    }

    /// Every tab is the same width so the window only changes height.
    static let width: CGFloat = 520
}

// MARK: - Buttons

struct ButtonsTab: View {
    @Bindable var model: AppModel
    @State private var selection: Trigger?

    init(model: AppModel, selection: Trigger? = nil) {
        self.model = model
        _selection = State(initialValue: selection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !model.hasAccess {
                HStack {
                    Label("Squeek needs Accessibility access.", systemImage: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.multicolor)
                    Spacer()
                    Button("Open System Settings") { model.openAccessibilitySettings() }
                }
            }

            VStack(spacing: 0) {
                table
                AddRemoveBar(model: model, selection: $selection)
            }
        }
        .padding(20)
        .frame(width: SettingsView.width)
        .onChange(of: model.settings.buttons.map(\.trigger)) { _, triggers in
            if let selection, !triggers.contains(selection) { self.selection = nil }
        }
        .onChange(of: model.lastAdded) { _, trigger in
            if let trigger { selection = trigger }
        }
    }

    private var table: some View {
        Table(model.settings.buttons, selection: $selection) {
            TableColumn("Button") { mapping in
                TriggerLabel(trigger: mapping.trigger)
            }
            .width(140)

            TableColumn("Action") { mapping in
                if mapping.trigger == selection {
                    ActionEditor(mapping: mapping, model: model)
                } else {
                    ActionSummary(mapping: mapping)
                }
            }
        }
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
        .frame(height: 252)
        .overlay {
            if model.settings.buttons.isEmpty {
                Text("No buttons").foregroundStyle(.secondary)
            }
        }
        .onDeleteCommand(perform: removeSelected)
    }

    private func removeSelected() {
        guard !model.isCapturing, let selection else { return }
        model.remove(selection)
        self.selection = nil
    }
}

/// The held keys as keycaps, then the button's name: ⌘ + Middle.
private struct TriggerLabel: View {
    let trigger: Trigger

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(trigger.modifiers.symbols), id: \.self) { symbol in
                Text(String(symbol))
                    .font(.system(size: 10.5, weight: .medium))
                    .frame(minWidth: 17, minHeight: 17)
                    // Tinted from the text colour, so the keycaps follow it
                    // when a selected row turns the text white.
                    .background(.quinary, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.tertiary, lineWidth: 0.5))
            }
            if !trigger.modifiers.isEmpty {
                Text("+").font(.caption).foregroundStyle(.secondary)
            }
            Text(Trigger.name(forButton: trigger.button))
        }
        .lineLimit(1)
    }
}

/// An unselected row: the action, and its shortcut or app on the right.
private struct ActionSummary: View {
    let mapping: ButtonMapping

    var body: some View {
        HStack {
            Text(mapping.action.title)
            Spacer()
            Text(detail).foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .help(mapping.action == .passToOtherApps ? ActionEditor.passHelp : "")
    }

    private var detail: String {
        switch mapping.action {
        case .keyboardShortcut: mapping.shortcut?.displayName ?? ""
        case .openApp: mapping.appURL.map { FileManager.default.displayName(atPath: $0.path) } ?? ""
        default: ""
        }
    }
}

/// The selected row: the action picker, and a shortcut recorder or app chooser.
private struct ActionEditor: View {
    let mapping: ButtonMapping
    let model: AppModel

    static let passHelp = "Ignored in browsers. Other apps see the button as normal."

    private var binding: Binding<ButtonMapping> {
        Binding(get: { model.mapping(for: mapping.trigger) ?? mapping }, set: { model.update($0) })
    }

    var body: some View {
        HStack(spacing: 8) {
            Picker(mapping.trigger.displayName, selection: binding.action) {
                ForEach(Self.groups, id: \.self) { group in
                    ForEach(group, id: \.self) { Text($0.title).tag($0) }
                    if group != Self.groups.last { Divider() }
                }
            }
            .labelsHidden()
            .fixedSize()
            .help(mapping.action == .passToOtherApps ? Self.passHelp : "")

            Spacer(minLength: 0)

            // Tables draw buttons without a bezel unless asked.
            switch mapping.action {
            case .keyboardShortcut: ShortcutRecorder(shortcut: binding.shortcut).fixedSize().buttonStyle(.bordered)
            case .openApp: AppChooser(url: binding.appURL).frame(maxWidth: 180).fixedSize(horizontal: false, vertical: true).buttonStyle(.bordered)
            default: EmptyView()
            }
        }
        .controlSize(.small)
    }

    private static let groups: [[ActionKind]] = [
        [.doNothing, .normal, .passToOtherApps],
        [.keyboardShortcut, .middleClick],
        [.missionControl, .appWindows, .showDesktop, .previousDesktop, .nextDesktop],
        [.openApp],
    ]
}

/// The + and − buttons under the list, as in other Mac lists.
private struct AddRemoveBar: View {
    @Bindable var model: AppModel
    @Binding var selection: Trigger?

    var body: some View {
        HStack(spacing: 0) {
            Button {
                ShortcutRecorder.stopActive()
                model.isCapturing = true
            } label: {
                Image(systemName: "plus").frame(width: 24, height: 20)
            }
            .disabled(!model.hasAccess || model.isCapturing)
            .help("Add a button")
            Divider()
            Button(action: remove) {
                Image(systemName: "minus").frame(width: 24, height: 20)
            }
            .disabled(selection == nil || model.isCapturing)
            .help("Remove the selected button")
            Divider()

            if model.isCapturing {
                Text("Hold any keys and press a mouse button…")
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
                Spacer()
                Button("Cancel") { model.isCapturing = false }
                    .controlSize(.small)
                    .padding(.trailing, 4)
            } else {
                Spacer()
            }
        }
        .buttonStyle(.borderless)
        .frame(height: 22)
        .background(.background)
        .overlay(Rectangle().strokeBorder(.separator))
        .padding(.top, -1)
    }

    private func remove() {
        guard !model.isCapturing, let selection else { return }
        model.remove(selection)
        self.selection = nil
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
                        .frame(width: 14, height: 14)
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

// MARK: - General

struct GeneralTab: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Toggle("Open at login", isOn: Binding(
                get: { model.opensAtLogin },
                set: { model.setOpensAtLogin($0) }
            ))
            Toggle("Pause Squeek", isOn: $model.isPaused)
                .help("Mouse buttons behave as if Squeek weren't running.")
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: SettingsView.width)
    }
}

// MARK: - About

struct AboutTab: View {
    static let website = URL(string: "https://viaduct.io/squeek")!
    static let copyright = "© 2026 Viaduct Industries Limited"

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Version \(short)"
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Squeek")
                .font(.title2.weight(.semibold))
                .padding(.top, 8)
            Text(version)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            Link("viaduct.io/squeek", destination: Self.website)
                .padding(.top, 14)
                .pointerStyle(.link)
            Text(Self.copyright)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 16)
        }
        .padding(.vertical, 28)
        .frame(width: SettingsView.width)
    }
}
