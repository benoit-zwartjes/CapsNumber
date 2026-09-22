// CapsNumber
// When Caps Lock is on, the number row types digits instead of symbols
// (for AZERTY layouts such as Belgian or French). Caps Lock + Shift gives
// the symbols back. Nothing else is touched: letters, shortcuts, Option
// characters and every other key behave exactly as before.

import Foundation
import CoreGraphics
import ApplicationServices
import Carbon.HIToolbox

// MARK: - Key logic

/// Physical key codes of the number row, 1 through 0. These positions are the
/// same on ANSI and ISO keyboards, so this works whatever AZERTY layout is active.
let numberRowKeyCodes: Set<Int64> = [
    Int64(kVK_ANSI_1), Int64(kVK_ANSI_2), Int64(kVK_ANSI_3), Int64(kVK_ANSI_4), Int64(kVK_ANSI_5),
    Int64(kVK_ANSI_6), Int64(kVK_ANSI_7), Int64(kVK_ANSI_8), Int64(kVK_ANSI_9), Int64(kVK_ANSI_0),
]

/// Left/right Shift bits that macOS sets next to `.maskShift` on real key events.
let deviceShiftBits = CGEventFlags(rawValue: 0x2 | 0x4)

/// Returns the flags a key event should carry, or nil when the event must be left alone.
func remappedFlags(keyCode: Int64, flags: CGEventFlags) -> CGEventFlags? {
    guard flags.contains(.maskAlphaShift) else { return nil }          // Caps Lock is off
    guard numberRowKeyCodes.contains(keyCode) else { return nil }        // not a number-row key
    guard flags.isDisjoint(with: [.maskCommand, .maskControl, .maskAlternate]) else {
        return nil                                                       // keep shortcuts and Option characters
    }
    var out = flags
    if flags.contains(.maskShift) {
        out.remove(.maskShift)                                           // Caps + Shift -> symbol
        out.remove(deviceShiftBits)
    } else {
        out.insert(.maskShift)                                           // Caps -> digit
    }
    return out
}

// MARK: - Event tap

nonisolated(unsafe) var eventTap: CFMachPort?

let tapCallback: CGEventTapCallBack = { _, type, event, _ in
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        // macOS switches a tap off if it thinks we were too slow; switch it back on.
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
    case .keyDown, .keyUp:
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if let flags = remappedFlags(keyCode: keyCode, flags: event.flags) {
            event.flags = flags
        }
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}

func log(_ message: String) {
    let stamp = ISO8601DateFormatter().string(from: Date())
    print("\(stamp) \(message)")
    fflush(stdout)
}

func createTap() -> CFMachPort? {
    let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue))
    return CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: tapCallback,
        userInfo: nil
    )
}

// MARK: - Self test (run with --self-test)

/// Translates a key through the active keyboard layout the way apps do (UCKeyTranslate).
func characters(keyCode: Int, flags: CGEventFlags) -> String {
    guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
          let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
        return "?"
    }
    let layoutData = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
    var modifiers: UInt32 = 0
    if flags.contains(.maskShift) { modifiers |= UInt32(shiftKey) }
    if flags.contains(.maskAlphaShift) { modifiers |= UInt32(alphaLock) }
    if flags.contains(.maskAlternate) { modifiers |= UInt32(optionKey) }
    if flags.contains(.maskControl) { modifiers |= UInt32(controlKey) }
    if flags.contains(.maskCommand) { modifiers |= UInt32(cmdKey) }
    modifiers = (modifiers >> 8) & 0xFF
    var deadKeyState: UInt32 = 0
    var length = 0
    var buffer = [UniChar](repeating: 0, count: 8)
    let status = layoutData.withUnsafeBytes { bytes -> OSStatus in
        UCKeyTranslate(
            bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress!,
            UInt16(keyCode), UInt16(kUCKeyActionDown), modifiers,
            UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysMask),
            &deadKeyState, buffer.count, &length, &buffer
        )
    }
    guard status == noErr else { return "?" }
    return String(utf16CodeUnits: buffer, count: length)
}

func currentLayoutName() -> String {
    guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
          let raw = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else {
        return "unknown"
    }
    return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
}

func runSelfTest() {
    let one = Int64(kVK_ANSI_1)
    let caps: CGEventFlags = .maskAlphaShift
    precondition(remappedFlags(keyCode: one, flags: caps) == [.maskAlphaShift, .maskShift], "Caps -> adds Shift")
    precondition(remappedFlags(keyCode: one, flags: [.maskAlphaShift, .maskShift, deviceShiftBits]) == caps, "Caps+Shift -> removes Shift")
    precondition(remappedFlags(keyCode: one, flags: []) == nil, "Caps off -> untouched")
    precondition(remappedFlags(keyCode: one, flags: .maskShift) == nil, "Shift without Caps -> untouched")
    precondition(remappedFlags(keyCode: Int64(kVK_ANSI_A), flags: caps) == nil, "letters -> untouched")
    precondition(remappedFlags(keyCode: one, flags: [.maskAlphaShift, .maskCommand]) == nil, "Cmd shortcuts -> untouched")
    precondition(remappedFlags(keyCode: one, flags: [.maskAlphaShift, .maskAlternate]) == nil, "Option characters -> untouched")
    print("Logic checks passed.")
    print("Active keyboard layout: \(currentLayoutName())")
    print("Number row with Caps Lock on, without CapsNumber -> with CapsNumber:")
    let keys = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9, kVK_ANSI_0]
    var before = "", after = "", withShift = ""
    for key in keys {
        before += characters(keyCode: key, flags: caps)
        after += characters(keyCode: key, flags: remappedFlags(keyCode: Int64(key), flags: caps)!)
        withShift += characters(keyCode: key, flags: remappedFlags(keyCode: Int64(key), flags: [caps, .maskShift])!)
    }
    print("  Caps            : \(before)  ->  \(after)")
    print("  Caps + Shift    : \(after)  ->  \(withShift)")
}

// MARK: - Main

if CommandLine.arguments.contains("--self-test") {
    runSelfTest()
    exit(0)
}

// Ask for Accessibility access; macOS shows its prompt the first time.
let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
if !AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary) {
    log("Waiting for Accessibility permission: System Settings > Privacy & Security > Accessibility > CapsNumber")
}

while eventTap == nil {
    eventTap = createTap()
    if eventTap == nil { sleep(2) }
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: eventTap!, enable: true)
log("CapsNumber is running. Caps Lock now types digits on the number row.")
CFRunLoopRun()
