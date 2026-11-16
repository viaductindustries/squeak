import Foundation
import Testing
@testable import SqueekCore

struct ButtonRouterTests {
    private func router(_ mappings: ButtonMapping...) -> ButtonRouter {
        ButtonRouter(settings: SqueekSettings(buttons: mappings))
    }

    @Test func standardSettingsSwallowBackAndForward() {
        var router = ButtonRouter()
        for button in [ButtonMapping.back, ButtonMapping.forward] {
            #expect(router.route(button: button, phase: .down) == .swallow)
            #expect(router.route(button: button, phase: .dragged) == .swallow)
            #expect(router.route(button: button, phase: .up) == .swallow)
        }
    }

    @Test func leftAndRightAreNeverTouched() {
        var router = ButtonRouter()
        router.isCapturing = true
        #expect(router.route(button: 0, phase: .down) == .pass)
        #expect(router.route(button: 1, phase: .down) == .pass)
        #expect(router.isCapturing)
    }

    @Test func unlistedButtonsPass() {
        var router = ButtonRouter()
        #expect(router.route(button: 5, phase: .down) == .pass)
        #expect(router.route(button: 5, phase: .up) == .pass)
    }

    @Test func normalPasses() {
        var router = router(ButtonMapping(button: 3, action: .normal))
        #expect(router.route(button: 3, phase: .down) == .pass)
        #expect(router.route(button: 3, phase: .up) == .pass)
    }

    @Test func passToOtherAppsPassesOutsideBrowsers() {
        var router = router(ButtonMapping(button: 3, action: .passToOtherApps))
        #expect(router.route(button: 3, phase: .down, isOverBrowser: { false }) == .pass)
        #expect(router.route(button: 3, phase: .dragged, isOverBrowser: { true }) == .pass)
        #expect(router.route(button: 3, phase: .up, isOverBrowser: { true }) == .pass)
    }

    @Test func passToOtherAppsSwallowsOverBrowsers() {
        var router = router(ButtonMapping(button: 3, action: .passToOtherApps))
        #expect(router.route(button: 3, phase: .down, isOverBrowser: { true }) == .swallow)
        #expect(router.route(button: 3, phase: .dragged, isOverBrowser: { false }) == .swallow)
        #expect(router.route(button: 3, phase: .up, isOverBrowser: { false }) == .swallow)
    }

    @Test func browserIsOnlyCheckedWhenNeeded() {
        var router = ButtonRouter()
        var asked = false
        _ = router.route(button: 3, phase: .down, isOverBrowser: { asked = true; return true })
        #expect(!asked)
    }

    @Test func middleClickRewritesToButtonTwo() {
        var router = router(ButtonMapping(button: 4, action: .middleClick))
        #expect(router.route(button: 4, phase: .down) == .rewrite(button: 2))
        #expect(router.route(button: 4, phase: .up) == .rewrite(button: 2))
    }

    @Test func actionsTriggerOnDownAndReleaseOnUp() {
        let shortcut = KeyShortcut(keyCode: 40, modifiers: [.command], keyName: "K")
        let mapping = ButtonMapping(button: 3, action: .keyboardShortcut, shortcut: shortcut)
        var router = router(mapping)
        #expect(router.route(button: 3, phase: .down) == .trigger(mapping))
        #expect(router.route(button: 3, phase: .dragged) == .swallow)
        #expect(router.route(button: 3, phase: .up) == .release(mapping))
    }

    @Test func incompleteActionsSwallow() {
        var router = router(
            ButtonMapping(button: 3, action: .keyboardShortcut),
            ButtonMapping(button: 4, action: .openApp)
        )
        #expect(router.route(button: 3, phase: .down) == .swallow)
        #expect(router.route(button: 4, phase: .down) == .swallow)
    }

    @Test func pausedPassesEverything() {
        var router = ButtonRouter()
        router.isPaused = true
        #expect(router.route(button: 3, phase: .down) == .pass)
        #expect(router.route(button: 3, phase: .up) == .pass)
    }

    @Test func decisionIsKeptUntilRelease() {
        var router = ButtonRouter()
        #expect(router.route(button: 3, phase: .down) == .swallow)
        router.isPaused = true
        #expect(router.route(button: 3, phase: .up) == .swallow)
        #expect(router.route(button: 3, phase: .down) == .pass)
    }

    @Test func capturingTakesOnePressAndSwallowsIt() {
        var router = ButtonRouter()
        router.isCapturing = true
        #expect(router.route(button: 7, phase: .down) == .captured(button: 7))
        #expect(!router.isCapturing)
        #expect(router.route(button: 7, phase: .up) == .swallow)
        #expect(router.route(button: 7, phase: .down) == .pass)
    }

    @Test func releaseWithoutPressPasses() {
        var router = ButtonRouter()
        #expect(router.route(button: 3, phase: .up) == .pass)
    }
}

struct SqueekSettingsTests {
    @Test func missingOrBrokenDataGivesStandardSettings() {
        #expect(SqueekSettings.decode(nil) == .standard)
        #expect(SqueekSettings.decode(Data("nope".utf8)) == .standard)
    }

    @Test func roundTripsAndRestoresStandardButtons() {
        let settings = SqueekSettings(buttons: [
            ButtonMapping(button: 6, action: .openApp, appURL: URL(fileURLWithPath: "/Applications/Safari.app")),
            ButtonMapping(button: 3, action: .missionControl),
        ])
        let decoded = SqueekSettings.decode(settings.encoded())
        #expect(decoded.buttons.map(\.button) == [3, 4, 6])
        #expect(decoded.buttons[0].action == .missionControl)
        #expect(decoded.buttons[2].appURL?.path == "/Applications/Safari.app")
    }

    @Test func standardButtonsCannotBeRemoved() {
        var settings = SqueekSettings.standard
        settings.add(button: 6)
        settings.add(button: 6)
        #expect(settings.buttons.map(\.button) == [3, 4, 6])
        settings.remove(button: 3)
        settings.remove(button: 6)
        #expect(settings.buttons.map(\.button) == [3, 4])
    }

    @Test func buttonNames() {
        #expect(ButtonMapping.name(forButton: 2) == "Middle")
        #expect(ButtonMapping.name(forButton: 3) == "Back")
        #expect(ButtonMapping.name(forButton: 4) == "Forward")
        #expect(ButtonMapping.name(forButton: 5) == "Button 6")
    }

    @Test func shortcutDisplayName() {
        let shortcut = KeyShortcut(keyCode: 40, modifiers: [.command, .shift, .control, .option], keyName: "K")
        #expect(shortcut.displayName == "⌃⌥⇧⌘K")
    }
}
