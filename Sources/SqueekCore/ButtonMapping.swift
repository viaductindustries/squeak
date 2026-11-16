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

    public static let all: KeyModifiers = [.shift, .control, .option, .command]

    /// Picks out the four modifier keys from an event's flags, ignoring
    /// things like Caps Lock and Fn.
    public init(eventFlags: UInt64) {
        self.init(rawValue: eventFlags & Self.all.rawValue)
    }

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

/// A mouse button pressed while holding some modifier keys, such as ⌘ + middle.
public struct Trigger: Hashable, Comparable, Sendable {
    /// The macOS button number, counting from 0: 2 is middle. Browsers treat
    /// 3 and 4 (buttons 4 and 5) as back and forward.
    public var button: Int
    public var modifiers: KeyModifiers

    public init(button: Int, modifiers: KeyModifiers = []) {
        self.button = button
        self.modifiers = modifiers
    }

    public var displayName: String {
        modifiers.isEmpty ? Self.name(forButton: button) : "\(modifiers.symbols) \(Self.name(forButton: button))"
    }

    /// By button, then plain before one key before several.
    public static func < (lhs: Trigger, rhs: Trigger) -> Bool {
        (lhs.button, lhs.modifiers.rawValue.nonzeroBitCount, lhs.modifiers.rawValue)
            < (rhs.button, rhs.modifiers.rawValue.nonzeroBitCount, rhs.modifiers.rawValue)
    }

    public static func name(forButton button: Int) -> String {
        // Named the way other mouse tools name them. Only macOS's own
        // numbering is reliable: "back" and "forward" are just a browser habit.
        button == 2 ? "Middle" : "Button \(button + 1)"
    }
}

/// The action assigned to one trigger.
///
/// The shortcut and app are kept even when another action is chosen, so
/// switching back doesn't lose them.
public struct ButtonMapping: Codable, Hashable, Identifiable, Sendable {
    public var button: Int
    public var modifiers: KeyModifiers
    public var action: ActionKind
    public var shortcut: KeyShortcut?
    public var appURL: URL?

    public var trigger: Trigger { Trigger(button: button, modifiers: modifiers) }
    public var id: Trigger { trigger }

    public init(
        button: Int,
        modifiers: KeyModifiers = [],
        action: ActionKind = .doNothing,
        shortcut: KeyShortcut? = nil,
        appURL: URL? = nil
    ) {
        self.button = button
        self.modifiers = modifiers
        self.action = action
        self.shortcut = shortcut
        self.appURL = appURL
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        button = try container.decode(Int.self, forKey: .button)
        modifiers = try container.decodeIfPresent(KeyModifiers.self, forKey: .modifiers) ?? []
        action = try container.decode(ActionKind.self, forKey: .action)
        shortcut = try container.decodeIfPresent(KeyShortcut.self, forKey: .shortcut)
        appURL = try container.decodeIfPresent(URL.self, forKey: .appURL)
    }
}

/// Everything Squeek stores.
public struct SqueekSettings: Codable, Hashable, Sendable {
    public var buttons: [ButtonMapping]

    public init(buttons: [ButtonMapping]) {
        self.buttons = buttons.sorted { $0.trigger < $1.trigger }
    }

    /// A fresh install: the side buttons do nothing, so browsers stop going
    /// back and forward.
    public static let standard = SqueekSettings(buttons: [
        ButtonMapping(button: 3),
        ButtonMapping(button: 4),
    ])

    public static func decode(_ data: Data?) -> SqueekSettings {
        guard let data, let decoded = try? JSONDecoder().decode(SqueekSettings.self, from: data) else {
            return .standard
        }
        return SqueekSettings(buttons: decoded.buttons)
    }

    public func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    public func mapping(for trigger: Trigger) -> ButtonMapping? {
        buttons.first { $0.trigger == trigger }
    }

    public mutating func add(_ trigger: Trigger) {
        guard mapping(for: trigger) == nil else { return }
        buttons.append(ButtonMapping(button: trigger.button, modifiers: trigger.modifiers))
        buttons.sort { $0.trigger < $1.trigger }
    }

    public mutating func update(_ mapping: ButtonMapping) {
        guard let index = buttons.firstIndex(where: { $0.trigger == mapping.trigger }) else { return }
        buttons[index] = mapping
    }

    public mutating func remove(_ trigger: Trigger) {
        buttons.removeAll { $0.trigger == trigger }
    }
}
