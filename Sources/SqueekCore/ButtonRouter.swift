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
        /// Drop the event; the user pressed this button while adding one.
        case captured(button: Int)
    }

    private enum Held: Sendable {
        case pass, rewrite(Int), swallow, action(ButtonMapping)
    }

    public var mappings: [Int: ButtonMapping] = [:]
    public var isPaused = false
    public var isCapturing = false
    private var held: [Int: Held] = [:]

    public init(settings: SqueekSettings = .standard) {
        update(settings)
    }

    public mutating func update(_ settings: SqueekSettings) {
        mappings = Dictionary(uniqueKeysWithValues: settings.buttons.map { ($0.button, $0) })
    }

    /// Routes one event. `isOverBrowser` is only asked when it matters, on the
    /// press of a button set to "Pass to other apps".
    public mutating func route(button: Int, phase: Phase, isOverBrowser: () -> Bool = { false }) -> Result {
        // Left and right clicks are never touched.
        guard button >= 2 else { return .pass }

        switch phase {
        case .down:
            let (state, result) = decide(button: button, isOverBrowser: isOverBrowser)
            held[button] = state
            return result
        case .dragged:
            return result(for: held[button], finishing: false)
        case .up:
            defer { held[button] = nil }
            return result(for: held[button], finishing: true)
        }
    }

    private mutating func decide(button: Int, isOverBrowser: () -> Bool) -> (Held, Result) {
        if isCapturing {
            isCapturing = false
            return (.swallow, .captured(button: button))
        }
        guard !isPaused, let mapping = mappings[button] else { return (.pass, .pass) }

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
