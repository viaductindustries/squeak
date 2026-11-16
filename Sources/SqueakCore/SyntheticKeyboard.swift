/// One key event for Squeak to post.
public struct SyntheticKeyEvent: Equatable, Sendable {
    public var keyCode: UInt16
    public var isDown: Bool
    /// Modifier keys are posted as flag changes rather than key presses.
    public var isModifier: Bool
    public var flags: KeyModifiers

    public init(keyCode: UInt16, isDown: Bool, isModifier: Bool, flags: KeyModifiers) {
        self.keyCode = keyCode
        self.isDown = isDown
        self.isModifier = isModifier
        self.flags = flags
    }
}

/// Tracks the keys Squeak is holding down on behalf of mouse buttons.
///
/// Shortcuts are held for as long as their button is held, so this works out
/// which key events to send:
/// - modifier keys are pressed and released as real keys, not just flags, so
///   apps watching the modifier keys themselves see them;
/// - keys shared by two held buttons stay down until both are released;
/// - modifiers the user is already holding (the ⌘ in a ⌘ + Middle trigger)
///   are left alone, so releasing the button doesn't release their key.
public struct SyntheticKeyboard: Sendable {
    private struct Hold: Sendable {
        var keyCode: UInt16
        /// The modifiers this hold pressed, in order.
        var pressedModifiers: [KeyModifiers]
    }

    /// Modifier keys in the order they're pressed, with their key codes.
    static let modifierKeys: [(KeyModifiers, UInt16)] = [
        (.control, 59), (.option, 58), (.shift, 56), (.command, 55),
    ]

    private var holds: [Trigger: Hold] = [:]
    private var keyCounts: [UInt16: Int] = [:]
    private var modifierCounts: [UInt64: Int] = [:]

    public init() {}

    public var isHoldingKeys: Bool { !holds.isEmpty }

    private var heldModifiers: KeyModifiers {
        modifierCounts.reduce(into: KeyModifiers()) { result, entry in
            if entry.value > 0 { result.insert(KeyModifiers(rawValue: entry.key)) }
        }
    }

    /// Presses `shortcut` for the button `owner`. `physicallyHeld` are the
    /// modifiers the user was holding when they pressed the button.
    public mutating func press(
        _ shortcut: KeyShortcut,
        for owner: Trigger,
        physicallyHeld: KeyModifiers = []
    ) -> [SyntheticKeyEvent] {
        guard holds[owner] == nil else { return [] }
        var events: [SyntheticKeyEvent] = []
        var pressed: [KeyModifiers] = []

        for (modifier, keyCode) in Self.modifierKeys
        where shortcut.modifiers.contains(modifier)
            && (!physicallyHeld.contains(modifier) || modifierCounts[modifier.rawValue, default: 0] > 0) {
            pressed.append(modifier)
            modifierCounts[modifier.rawValue, default: 0] += 1
            if modifierCounts[modifier.rawValue] == 1 {
                events.append(SyntheticKeyEvent(keyCode: keyCode, isDown: true, isModifier: true, flags: heldModifiers.union(physicallyHeld)))
            }
        }

        keyCounts[shortcut.keyCode, default: 0] += 1
        if keyCounts[shortcut.keyCode] == 1 {
            events.append(SyntheticKeyEvent(
                keyCode: shortcut.keyCode, isDown: true, isModifier: false,
                flags: heldModifiers.union(physicallyHeld)
            ))
        }

        holds[owner] = Hold(keyCode: shortcut.keyCode, pressedModifiers: pressed)
        return events
    }

    /// Releases whatever `owner` pressed, keeping keys another button still holds.
    public mutating func release(for owner: Trigger, physicallyHeld: KeyModifiers = []) -> [SyntheticKeyEvent] {
        guard let hold = holds.removeValue(forKey: owner) else { return [] }
        var events: [SyntheticKeyEvent] = []

        keyCounts[hold.keyCode, default: 1] -= 1
        if keyCounts[hold.keyCode] == 0 {
            keyCounts[hold.keyCode] = nil
            events.append(SyntheticKeyEvent(
                keyCode: hold.keyCode, isDown: false, isModifier: false,
                flags: heldModifiers.union(physicallyHeld)
            ))
        }

        for modifier in hold.pressedModifiers.reversed() {
            modifierCounts[modifier.rawValue, default: 1] -= 1
            if modifierCounts[modifier.rawValue] == 0 {
                modifierCounts[modifier.rawValue] = nil
                let keyCode = Self.modifierKeys.first { $0.0 == modifier }!.1
                if !physicallyHeld.contains(modifier) {
                    events.append(SyntheticKeyEvent(keyCode: keyCode, isDown: false, isModifier: true, flags: heldModifiers.union(physicallyHeld)))
                }
            }
        }
        return events
    }

    /// Releases everything, for when Squeak stops or loses track of buttons.
    public mutating func releaseAll(physicallyHeld: KeyModifiers = []) -> [SyntheticKeyEvent] {
        holds.keys.sorted().flatMap { release(for: $0, physicallyHeld: physicallyHeld) }
    }
}
