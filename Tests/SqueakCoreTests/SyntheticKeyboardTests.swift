import Testing
@testable import SqueakCore

struct SyntheticKeyboardTests {
    private let back = Trigger(button: 3)
    private let forward = Trigger(button: 4)
    private let commandK = KeyShortcut(keyCode: 40, modifiers: [.command], keyName: "K")

    private func key(_ code: UInt16, _ down: Bool, _ flags: KeyModifiers = []) -> SyntheticKeyEvent {
        SyntheticKeyEvent(keyCode: code, isDown: down, isModifier: false, flags: flags)
    }

    private func modifier(_ code: UInt16, _ down: Bool, _ flags: KeyModifiers) -> SyntheticKeyEvent {
        SyntheticKeyEvent(keyCode: code, isDown: down, isModifier: true, flags: flags)
    }

    @Test func pressesModifiersAsKeysAroundTheMainKey() {
        var keyboard = SyntheticKeyboard()
        let shortcut = KeyShortcut(keyCode: 40, modifiers: [.command, .control], keyName: "K")
        #expect(keyboard.press(shortcut, for: back) == [
            modifier(59, true, [.control]),
            modifier(55, true, [.control, .command]),
            key(40, true, [.control, .command]),
        ])
        #expect(keyboard.release(for: back) == [
            key(40, false, [.control, .command]),
            modifier(55, false, [.control]),
            modifier(59, false, []),
        ])
        #expect(!keyboard.isHoldingKeys)
    }

    @Test func plainKeyHasNoModifiers() {
        var keyboard = SyntheticKeyboard()
        let f5 = KeyShortcut(keyCode: 96, modifiers: [], keyName: "F5")
        #expect(keyboard.press(f5, for: back) == [key(96, true)])
        #expect(keyboard.release(for: back) == [key(96, false)])
    }

    @Test func leavesModifiersTheUserIsHoldingAlone() {
        var keyboard = SyntheticKeyboard()
        #expect(keyboard.press(commandK, for: back, physicallyHeld: [.command]) == [key(40, true, [.command])])
        #expect(keyboard.release(for: back, physicallyHeld: [.command]) == [key(40, false, [.command])])
    }

    @Test func fallbackModifiersDoNotReleasePhysicalKeys() {
        var keyboard = SyntheticKeyboard()
        #expect(keyboard.press(commandK, for: back, physicallyHeld: [.option, .command]) == [
            key(40, true, [.option, .command]),
        ])
        #expect(keyboard.release(for: back, physicallyHeld: [.option, .command]) == [
            key(40, false, [.option, .command]),
        ])
    }

    @Test func releasedPhysicalModifierIsNotReasserted() {
        var keyboard = SyntheticKeyboard()
        _ = keyboard.press(commandK, for: back, physicallyHeld: [.command])
        #expect(keyboard.release(for: back) == [key(40, false)])
    }

    @Test func physicalModifierPressedDuringHoldIsNotReleased() {
        var keyboard = SyntheticKeyboard()
        _ = keyboard.press(commandK, for: back)
        #expect(keyboard.releaseAll(physicallyHeld: [.command]) == [key(40, false, [.command])])
        #expect(!keyboard.isHoldingKeys)
    }

    @Test func existingSyntheticModifierRemainsOwnedWhenAlsoPhysicallyHeld() {
        var keyboard = SyntheticKeyboard()
        _ = keyboard.press(commandK, for: back)
        let commandJ = KeyShortcut(keyCode: 38, modifiers: [.command], keyName: "J")
        #expect(keyboard.press(commandJ, for: forward, physicallyHeld: [.command]) == [key(38, true, [.command])])
        #expect(keyboard.release(for: back) == [key(40, false, [.command])])
        #expect(keyboard.release(for: forward) == [key(38, false, [.command]), modifier(55, false, [])])
    }

    @Test func sharedKeyStaysDownUntilTheLastButtonIsReleased() {
        for releaseBackFirst in [true, false] {
            var keyboard = SyntheticKeyboard()
            #expect(keyboard.press(commandK, for: back).count == 2)
            #expect(keyboard.press(commandK, for: forward).isEmpty)

            let first = releaseBackFirst ? back : forward
            let second = releaseBackFirst ? forward : back
            #expect(keyboard.release(for: first).isEmpty)
            #expect(keyboard.release(for: second) == [key(40, false, [.command]), modifier(55, false, [])])
        }
    }

    @Test func sharedModifierStaysDownForTheOtherShortcut() {
        var keyboard = SyntheticKeyboard()
        let commandJ = KeyShortcut(keyCode: 38, modifiers: [.command], keyName: "J")
        _ = keyboard.press(commandK, for: back)
        #expect(keyboard.press(commandJ, for: forward) == [key(38, true, [.command])])
        #expect(keyboard.release(for: back) == [key(40, false, [.command])])
        #expect(keyboard.release(for: forward) == [key(38, false, [.command]), modifier(55, false, [])])
    }

    @Test func pressingTheSameButtonTwiceIsIgnored() {
        var keyboard = SyntheticKeyboard()
        _ = keyboard.press(commandK, for: back)
        #expect(keyboard.press(commandK, for: back).isEmpty)
        #expect(keyboard.release(for: back).count == 2)
        #expect(keyboard.release(for: back).isEmpty)
    }

    @Test func releaseAllLetsGoOfEverything() {
        var keyboard = SyntheticKeyboard()
        let optionJ = KeyShortcut(keyCode: 38, modifiers: [.option], keyName: "J")
        _ = keyboard.press(commandK, for: back)
        _ = keyboard.press(optionJ, for: forward)
        let events = keyboard.releaseAll()
        #expect(events.filter { !$0.isDown }.count == 4)
        #expect(events.allSatisfy { !$0.isDown })
        #expect(events.last?.flags == [])
        #expect(!keyboard.isHoldingKeys)
        #expect(keyboard.releaseAll().isEmpty)
    }
}
