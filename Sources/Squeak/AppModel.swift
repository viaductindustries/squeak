import AppKit
import ApplicationServices
import Observation
import ServiceManagement
import SqueakCore

@MainActor
@Observable
final class AppModel {
    var settings: SqueakSettings {
        didSet {
            guard settings != oldValue, !isPreview else { return }
            UserDefaults.standard.set(settings.encoded(), forKey: Self.settingsKey)
            tap.router.update(settings)
        }
    }

    var isPaused: Bool {
        didSet {
            guard !isPreview else { return }
            UserDefaults.standard.set(isPaused, forKey: Self.pausedKey)
            tap.router.isPaused = isPaused
        }
    }

    /// True while waiting for the user to press the button they want to add.
    var isCapturing = false {
        didSet {
            if isCapturing { lastAdded = nil }
            tap.router.isCapturing = isCapturing
        }
    }

    /// The button most recently added, so the list can select it.
    private(set) var lastAdded: Trigger?

    private(set) var hasAccess = false
    private(set) var opensAtLogin = SMAppService.mainApp.status == .enabled

    @ObservationIgnored private let tap = EventTap()
    @ObservationIgnored private var accessTimer: Timer?
    @ObservationIgnored private let browsers = BrowserDetector()
    @ObservationIgnored private let isPreview: Bool

    private static let settingsKey = "settings"
    private static let pausedKey = "paused"

    init() {
        isPreview = false
        settings = SqueakSettings.decode(UserDefaults.standard.data(forKey: Self.settingsKey))
        isPaused = UserDefaults.standard.bool(forKey: Self.pausedKey)
        tap.router.update(settings)
        tap.router.isPaused = isPaused
        tap.onAction = { mapping, phase in ActionRunner.run(mapping, phase: phase) }
        tap.onCapture = { [weak self] trigger in self?.captured(trigger) }
        tap.isOverBrowser = { [browsers] in browsers.isBrowserUnderPointer() }
        tap.onInterrupted = { ActionRunner.releaseAllKeys() }
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { ActionRunner.releaseAllKeys() }
        }

        // Ask once at launch; macOS shows its own prompt.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        refreshAccess()

        // Access can be granted or taken away in System Settings at any time.
        accessTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAccess() }
        }
    }

    /// A model that shows the given state without touching saved settings or
    /// mouse events. Used to render the settings window during development.
    init(preview settings: SqueakSettings, hasAccess: Bool) {
        isPreview = true
        self.settings = settings
        isPaused = false
        self.hasAccess = hasAccess
    }

    var menuBarSymbol: String {
        hasAccess && !isPaused ? "computermouse.fill" : "computermouse"
    }

    func mapping(for trigger: Trigger) -> ButtonMapping? {
        settings.mapping(for: trigger)
    }

    func update(_ mapping: ButtonMapping) {
        settings.update(mapping)
    }

    func remove(_ trigger: Trigger) {
        settings.remove(trigger)
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func setOpensAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func captured(_ trigger: Trigger) {
        guard isCapturing else { return }
        isCapturing = false
        settings.add(trigger)
        lastAdded = trigger
    }

    private func refreshAccess() {
        let trusted = AXIsProcessTrusted()
        if trusted, !tap.isRunning {
            tap.start()
        } else if !trusted, tap.isRunning {
            tap.stop()
            ActionRunner.releaseAllKeys()
        }
        let running = tap.isRunning
        if !running { isCapturing = false }
        if hasAccess != running { hasAccess = running }
    }
}
