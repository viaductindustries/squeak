import Foundation
import Testing
@testable import SqueakCore

struct ButtonRouterTests {
    private func router(_ mappings: ButtonMapping...) -> ButtonRouter {
        ButtonRouter(settings: SqueakSettings(buttons: mappings))
    }

    @Test func standardSettingsSwallowBackAndForward() {
        var router = ButtonRouter()
        for button in [3, 4] {
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
        #expect(router.route(button: 7, modifiers: [.command], phase: .down) == .captured(Trigger(button: 7, modifiers: [.command])))
        #expect(!router.isCapturing)
        #expect(router.route(button: 7, phase: .up) == .swallow)
        #expect(router.route(button: 7, phase: .down) == .pass)
    }

    @Test func heldKeysPickTheMatchingRow() {
        var router = router(
            ButtonMapping(button: 2, action: .normal),
            ButtonMapping(button: 2, modifiers: [.command], action: .missionControl),
            ButtonMapping(button: 2, modifiers: [.command, .shift], action: .doNothing)
        )
        #expect(router.route(button: 2, phase: .down) == .pass)
        _ = router.route(button: 2, phase: .up)
        let commandMiddle = ButtonMapping(button: 2, modifiers: [.command], action: .missionControl)
        #expect(router.route(button: 2, modifiers: [.command], phase: .down) == .trigger(commandMiddle))
        #expect(router.route(button: 2, modifiers: [.command], phase: .up) == .release(commandMiddle))
        #expect(router.route(button: 2, modifiers: [.command, .shift], phase: .down) == .swallow)
    }

    @Test func unmatchedKeysFallBackToThePlainButton() {
        var router = ButtonRouter()
        #expect(router.route(button: 3, modifiers: [.option], phase: .down) == .swallow)
        #expect(router.route(button: 3, modifiers: [.option], phase: .up) == .swallow)
    }

    @Test func keysWithoutAPlainRowPass() {
        var router = router(ButtonMapping(button: 2, modifiers: [.command], action: .missionControl))
        #expect(router.route(button: 2, phase: .down) == .pass)
        #expect(router.route(button: 2, modifiers: [.option], phase: .down) == .pass)
    }

    @Test func releaseWithoutPressFollowsCurrentSettings() {
        let shortcut = KeyShortcut(keyCode: 40, modifiers: [.command], keyName: "K")
        var router = router(
            ButtonMapping(button: 2, action: .middleClick),
            ButtonMapping(button: 3),
            ButtonMapping(button: 4, action: .keyboardShortcut, shortcut: shortcut),
            ButtonMapping(button: 5, action: .normal)
        )
        #expect(router.route(button: 3, phase: .up) == .swallow)
        #expect(router.route(button: 2, phase: .up) == .rewrite(button: 2))
        #expect(router.route(button: 5, phase: .up) == .pass)
        #expect(router.route(button: 6, phase: .up) == .pass)
        // No action starts, so there's nothing to release either.
        #expect(router.route(button: 4, phase: .dragged) == .swallow)
        #expect(router.route(button: 4, phase: .up) == .swallow)
    }

    @Test func releaseWithoutPressDoesNotUseUpCapture() {
        var router = ButtonRouter()
        router.isCapturing = true
        #expect(router.route(button: 7, phase: .up) == .pass)
        #expect(router.isCapturing)
    }

    @Test func resetForgetsPressesInProgress() {
        let shortcut = KeyShortcut(keyCode: 40, modifiers: [.command], keyName: "K")
        let mapping = ButtonMapping(button: 3, action: .keyboardShortcut, shortcut: shortcut)
        var router = router(mapping)
        #expect(router.route(button: 3, phase: .down) == .trigger(mapping))
        router.reset()
        #expect(router.route(button: 3, phase: .up) == .swallow)
    }
}

struct SqueakSettingsTests {
    @Test func missingOrBrokenDataGivesStandardSettings() {
        #expect(SqueakSettings.decode(nil) == .standard)
        #expect(SqueakSettings.decode(Data("nope".utf8)) == .standard)
    }

    @Test func roundTrips() {
        let settings = SqueakSettings(buttons: [
            ButtonMapping(button: 6, action: .openApp, appURL: URL(fileURLWithPath: "/Applications/Safari.app")),
            ButtonMapping(button: 2, modifiers: [.command], action: .missionControl),
        ])
        let decoded = SqueakSettings.decode(settings.encoded())
        #expect(decoded == settings)
        #expect(decoded.buttons.map(\.trigger) == [Trigger(button: 2, modifiers: [.command]), Trigger(button: 6)])
    }

    @Test func removingEveryRowIsKept() {
        var settings = SqueakSettings.standard
        settings.remove(Trigger(button: 3))
        settings.remove(Trigger(button: 4))
        #expect(SqueakSettings.decode(settings.encoded()).buttons.isEmpty)
    }

    @Test func settingsSavedBeforeModifiersStillLoad() {
        let data = Data(#"{"buttons":[{"button":3,"action":"missionControl"}]}"#.utf8)
        #expect(SqueakSettings.decode(data).buttons == [ButtonMapping(button: 3, action: .missionControl)])
    }

    @Test func addingTheSameTriggerTwiceKeepsOneRow() {
        var settings = SqueakSettings(buttons: [])
        settings.add(Trigger(button: 2, modifiers: [.command]))
        settings.add(Trigger(button: 2, modifiers: [.command]))
        settings.add(Trigger(button: 2, modifiers: [.option, .shift]))
        settings.add(Trigger(button: 2))
        #expect(settings.buttons.map(\.trigger) == [
            Trigger(button: 2),
            Trigger(button: 2, modifiers: [.command]),
            Trigger(button: 2, modifiers: [.option, .shift]),
        ])
    }

    @Test func triggerNames() {
        #expect(Trigger(button: 2).displayName == "Middle")
        #expect(Trigger(button: 3).displayName == "Button 4")
        #expect(Trigger(button: 4).displayName == "Button 5")
        #expect(Trigger(button: 5).displayName == "Button 6")
        #expect(Trigger(button: 2, modifiers: [.command, .option]).displayName == "⌥⌘ Middle")
    }

    @Test func eventFlagsKeepOnlyTheFourModifiers() {
        let capsLockAndFn: UInt64 = 0x0001_0000 | 0x0080_0000
        let flags = KeyModifiers.command.rawValue | KeyModifiers.shift.rawValue | capsLockAndFn
        #expect(KeyModifiers(eventFlags: flags) == [.command, .shift])
    }

    @Test func shortcutDisplayName() {
        let shortcut = KeyShortcut(keyCode: 40, modifiers: [.command, .shift, .control, .option], keyName: "K")
        #expect(shortcut.displayName == "⌃⌥⇧⌘K")
    }
}
