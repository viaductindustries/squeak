import Foundation

/// What a mouse button does when it's pressed.
public enum ActionKind: String, Codable, CaseIterable, Sendable {
    case doNothing
    case normal
    case passToOtherApps
    case keyboardShortcut
    case middleClick
    case missionControl
    case appWindows
    case showDesktop
    case previousDesktop
    case nextDesktop
    case openApp

    public var title: String {
        switch self {
        case .doNothing: "Do nothing"
        case .normal: "Normal"
        case .passToOtherApps: "Pass to other apps"
        case .keyboardShortcut: "Keyboard shortcut"
        case .middleClick: "Middle click"
        case .missionControl: "Mission Control"
        case .appWindows: "App windows"
        case .showDesktop: "Show desktop"
        case .previousDesktop: "Previous desktop"
        case .nextDesktop: "Next desktop"
        case .openApp: "Open app"
        }
    }
}

/// Modifier keys for a keyboard shortcut. The raw values match `CGEventFlags`.
public struct KeyModifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }

    public static let shift = KeyModifiers(rawValue: 0x0002_0000)
    public static let control = KeyModifiers(rawValue: 0x0004_0000)
    public static let option = KeyModifiers(rawValue: 0x0008_0000)
    public static let command = KeyModifiers(rawValue: 0x0010_0000)

    /// Symbols in the order macOS menus show them.
    public var symbols: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }
}

/// A recorded key combination.
public struct KeyShortcut: Codable, Hashable, Sendable {
    public var keyCode: UInt16
    public var modifiers: KeyModifiers
    /// How the key itself is shown, such as "K" or "F5". Captured when recorded
    /// so it matches the keyboard layout in use at the time.
    public var keyName: String

    public init(keyCode: UInt16, modifiers: KeyModifiers, keyName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyName = keyName
    }

    public var displayName: String { modifiers.symbols + keyName }
}

/// The action assigned to one mouse button.
///
/// The shortcut and app are kept even when another action is chosen, so
/// switching back doesn't lose them.
public struct ButtonMapping: Codable, Hashable, Identifiable, Sendable {
    /// The macOS button number: 2 is middle, 3 is back, 4 is forward.
    public var button: Int
    public var action: ActionKind
    public var shortcut: KeyShortcut?
    public var appURL: URL?

    public var id: Int { button }

    public init(button: Int, action: ActionKind = .doNothing, shortcut: KeyShortcut? = nil, appURL: URL? = nil) {
        self.button = button
        self.action = action
        self.shortcut = shortcut
        self.appURL = appURL
    }

    public var buttonName: String { Self.name(forButton: button) }

    /// Back and forward are always listed; other buttons are added by the user.
    public var isRemovable: Bool { !Self.standardButtons.contains(button) }

    public static let back = 3
    public static let forward = 4
    public static let standardButtons: Set<Int> = [back, forward]

    public static func name(forButton button: Int) -> String {
        switch button {
        case 2: "Middle"
        case back: "Back"
        case forward: "Forward"
        default: "Button \(button + 1)"
        }
    }
}

/// Everything Squeek stores.
public struct SqueekSettings: Codable, Hashable, Sendable {
    public var buttons: [ButtonMapping]

    public init(buttons: [ButtonMapping]) {
        self.buttons = buttons.sorted { $0.button < $1.button }
    }

    public static let standard = SqueekSettings(buttons: [
        ButtonMapping(button: ButtonMapping.back),
        ButtonMapping(button: ButtonMapping.forward),
    ])

    /// Decodes stored settings, making sure back and forward are present.
    public static func decode(_ data: Data?) -> SqueekSettings {
        guard let data, let decoded = try? JSONDecoder().decode(SqueekSettings.self, from: data) else {
            return .standard
        }
        var buttons = decoded.buttons
        for button in ButtonMapping.standardButtons where !buttons.contains(where: { $0.button == button }) {
            buttons.append(ButtonMapping(button: button))
        }
        return SqueekSettings(buttons: buttons)
    }

    public func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    public mutating func add(button: Int) {
        guard !buttons.contains(where: { $0.button == button }) else { return }
        buttons.append(ButtonMapping(button: button))
        buttons.sort { $0.button < $1.button }
    }

    public mutating func remove(button: Int) {
        buttons.removeAll { $0.button == button && $0.isRemovable }
    }
}
