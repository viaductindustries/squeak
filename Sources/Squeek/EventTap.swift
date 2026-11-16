import CoreGraphics
import Foundation
import SqueekCore

/// Watches mouse button events system-wide and applies the router's decisions.
///
/// The tap runs on the main run loop, so its callback is always on the main
/// thread.
final class EventTap: @unchecked Sendable {
    var router = ButtonRouter()

    /// Called with the mapping and whether the button went down or up.
    var onAction: @MainActor (ButtonMapping, ButtonRouter.Phase) -> Void = { _, _ in }
    /// Called when a button is pressed while adding a button.
    var onCapture: @MainActor (Trigger) -> Void = { _ in }
    /// Whether the pointer is over a browser window.
    var isOverBrowser: @MainActor () -> Bool = { false }

    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { port != nil }

    /// Starts the tap. Fails if Squeek doesn't have Accessibility access.
    @discardableResult
    func start() -> Bool {
        guard port == nil else { return true }
        let types: [CGEventType] = [.otherMouseDown, .otherMouseUp, .otherMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.port = port
        self.source = source
        return true
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let port { CFMachPortInvalidate(port) }
        port = nil
        source = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let phase: ButtonRouter.Phase
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS turns taps off if they're slow or during secure input.
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        case .otherMouseDown: phase = .down
        case .otherMouseDragged: phase = .dragged
        case .otherMouseUp: phase = .up
        default: return Unmanaged.passUnretained(event)
        }

        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        let modifiers = KeyModifiers(eventFlags: event.flags.rawValue)
        let isOverBrowser = { MainActor.assumeIsolated { self.isOverBrowser() } }
        switch router.route(button: button, modifiers: modifiers, phase: phase, isOverBrowser: isOverBrowser) {
        case .pass:
            return Unmanaged.passUnretained(event)
        case .rewrite(let newButton):
            event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(newButton))
            return Unmanaged.passUnretained(event)
        case .swallow:
            return nil
        case .trigger(let mapping):
            dispatch { $0.onAction(mapping, .down) }
            return nil
        case .release(let mapping):
            dispatch { $0.onAction(mapping, .up) }
            return nil
        case .captured(let trigger):
            dispatch { $0.onCapture(trigger) }
            return nil
        }
    }

    /// Runs work after the callback returns, so the tap never waits on an action.
    private func dispatch(_ work: @escaping @MainActor (EventTap) -> Void) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { work(self) }
        }
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<EventTap>.fromOpaque(userInfo).takeUnretainedValue()
    return tap.handle(type: type, event: event)
}
