/// Decides what happens to each mouse button event.
///
/// The decision for a button is made when it goes down and reused for its drag
/// and release events, so a press is never half-swallowed if the settings
/// change while the button is held.
public struct ButtonRouter: Sendable {
    public enum Phase: Sendable {
        case down, dragged, up
    }

    public enum Result: Equatable, Sendable {
        /// Let the event through untouched.
        case pass
        /// Let the event through as a different button.
        case rewrite(button: Int)
        /// Drop the event.
        case swallow
        /// Drop the event and start the mapping's action.
        case trigger(ButtonMapping)
        /// Drop the event and finish the mapping's action.
        case release(ButtonMapping)
        /// Drop the event; the user pressed this while adding a button.
        case captured(Trigger)
    }

    private enum Held: Sendable {
        case pass, rewrite(Int), swallow, action(ButtonMapping)
    }

    public var mappings: [Trigger: ButtonMapping] = [:]
    public var isPaused = false
    public var isCapturing = false
    private var held: [Int: Held] = [:]

    public init(settings: SqueekSettings = .standard) {
        update(settings)
    }

    /// Forgets presses in progress, for when Squeek may have missed events
    /// (the tap was switched off or stopped).
    public mutating func reset() {
        held = [:]
    }

    public mutating func update(_ settings: SqueekSettings) {
        mappings = Dictionary(settings.buttons.map { ($0.trigger, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Routes one event. `modifiers` are the keys held at the time.
    /// `isOverBrowser` is only asked when it matters, on the press of a button
    /// set to "Pass to other apps".
    public mutating func route(
        button: Int,
        modifiers: KeyModifiers = [],
        phase: Phase,
        isOverBrowser: () -> Bool = { false }
    ) -> Result {
        // Left and right clicks are never touched.
        guard button >= 2 else { return .pass }

        let trigger = Trigger(button: button, modifiers: modifiers)
        if phase == .down {
            let (state, result) = decide(trigger, isOverBrowser: isOverBrowser)
            held[button] = state
            return result
        }

        // A drag or release without a press we saw: Squeek started, or its
        // tap was switched off, while the button was down. Treat it as the
        // current settings would, without starting any action, so a stray
        // release can't make a browser go back.
        let state = held[button] ?? orphanState(trigger, isOverBrowser: isOverBrowser)
        if phase == .up {
            held[button] = nil
        } else {
            held[button] = state
        }
        return result(for: state, finishing: phase == .up)
    }

    private mutating func decide(_ trigger: Trigger, isOverBrowser: () -> Bool) -> (Held, Result) {
        if isCapturing {
            isCapturing = false
            return (.swallow, .captured(trigger))
        }
        return decision(for: trigger, isOverBrowser: isOverBrowser)
    }

    private func orphanState(_ trigger: Trigger, isOverBrowser: () -> Bool) -> Held {
        switch decision(for: trigger, isOverBrowser: isOverBrowser).0 {
        case .action: .swallow
        case let state: state
        }
    }

    private func decision(for trigger: Trigger, isOverBrowser: () -> Bool) -> (Held, Result) {
        // An exact match wins (⌘ + middle); otherwise the plain button's
        // setting applies, so holding a key doesn't bring back behaviour the
        // user turned off.
        let plain = Trigger(button: trigger.button)
        guard !isPaused, let mapping = mappings[trigger] ?? mappings[plain] else { return (.pass, .pass) }

        switch mapping.action {
        case .normal:
            return (.pass, .pass)
        case .passToOtherApps:
            // Browsers treat these buttons as back and forward (Firefox treats
            // every other button as middle click), so the only safe way to keep
            // them quiet is not to send them at all.
            return isOverBrowser() ? (.swallow, .swallow) : (.pass, .pass)
        case .middleClick:
            return (.rewrite(2), .rewrite(button: 2))
        case .doNothing:
            return (.swallow, .swallow)
        case .keyboardShortcut where mapping.shortcut == nil, .openApp where mapping.appURL == nil:
            return (.swallow, .swallow)
        default:
            return (.action(mapping), .trigger(mapping))
        }
    }

    private func result(for state: Held?, finishing: Bool) -> Result {
        switch state {
        case nil, .pass: .pass
        case .rewrite(let button): .rewrite(button: button)
        case .swallow: .swallow
        case .action(let mapping): finishing ? .release(mapping) : .swallow
        }
    }
}
