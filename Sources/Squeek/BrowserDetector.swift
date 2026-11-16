import AppKit

/// Works out whether the window under the pointer belongs to a web browser.
@MainActor
final class BrowserDetector {
    /// Browsers known to treat the side buttons as back and forward.
    private static let knownBrowsers: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.dev",
        "com.google.Chrome.canary",
        "com.google.chrome.for.testing",
        "org.chromium.Chromium",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "org.mozilla.nightly",
        "app.zen-browser.zen",
        "io.gitlab.librewolf-community",
        "company.thebrowser.Browser",
        "company.thebrowser.dia",
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "com.brave.Browser.nightly",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Beta",
        "com.microsoft.edgemac.Dev",
        "com.microsoft.edgemac.Canary",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "com.kagi.kagimacOS",
        "com.duckduckgo.macos.browser",
        "net.imput.helium",
    ]

    func isBrowserUnderPointer() -> Bool {
        guard let bundleID = appUnderPointer()?.bundleIdentifier else { return false }
        return Self.knownBrowsers.contains(bundleID) || bundleID == defaultBrowser()
    }

    private func appUnderPointer() -> NSRunningApplication? {
        let number = NSWindow.windowNumber(at: NSEvent.mouseLocation, belowWindowWithWindowNumber: 0)
        if number > 0,
           let info = CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(number)) as? [[String: Any]],
           let pid = info.first?[kCGWindowOwnerPID as String] as? Int,
           let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
            return app
        }
        return NSWorkspace.shared.frontmostApplication
    }

    private func defaultBrowser() -> String? {
        let url = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!)
        return url.flatMap { Bundle(url: $0)?.bundleIdentifier }
    }
}
