import AppKit
import ApplicationServices
import Carbon.HIToolbox
import ServiceManagement

// MARK: Permissions

enum Permissions {
    /// True when macOS lets this app move the cursor and click.
    static var canControlPointer: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that sends the user to the Accessibility list.
    static func requestPointerControl() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    enum Pane: String {
        case accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case motion = "x-apple.systempreferences:com.apple.preference.security?Privacy_Motion"
        case bluetooth = "x-apple.systempreferences:com.apple.BluetoothSettings"
    }

    static func open(_ pane: Pane) {
        if let url = URL(string: pane.rawValue) { NSWorkspace.shared.open(url) }
    }
}

// MARK: Launch at login

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// - Returns: A plain-language reason when it could not be changed.
    @discardableResult
    static func set(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return "macOS would not change the login item. Move AirPointer to Applications and try again."
        }
    }
}

// MARK: Global shortcuts

/// A key plus modifiers, stored with the text to show for it.
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    /// Carbon modifier mask.
    var modifiers: UInt32
    var display: String

    static let toggle = Shortcut(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(controlKey | optionKey | cmdKey), display: "⌃⌥⌘P")
    static let calibrate = Shortcut(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(controlKey | optionKey | cmdKey), display: "⌃⌥⌘C")

    /// Builds a shortcut from a key press, or nil if it has no modifier to make it safe as a global key.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mask: UInt32 = 0
        var text = ""
        if flags.contains(.control) { mask |= UInt32(controlKey); text += "⌃" }
        if flags.contains(.option) { mask |= UInt32(optionKey); text += "⌥" }
        if flags.contains(.shift) { mask |= UInt32(shiftKey); text += "⇧" }
        if flags.contains(.command) { mask |= UInt32(cmdKey); text += "⌘" }
        guard mask & UInt32(controlKey | optionKey | cmdKey) != 0 else { return nil }
        let key: String = switch Int(event.keyCode) {
        case kVK_Space: "Space"
        case kVK_Return: "↩"
        case kVK_Tab: "⇥"
        case kVK_Escape: "⎋"
        case kVK_LeftArrow: "←"
        case kVK_RightArrow: "→"
        case kVK_UpArrow: "↑"
        case kVK_DownArrow: "↓"
        default: (event.charactersIgnoringModifiers ?? "").uppercased()
        }
        guard !key.isEmpty else { return nil }
        self.keyCode = UInt32(event.keyCode)
        self.modifiers = mask
        self.display = text + key
    }

    init(keyCode: UInt32, modifiers: UInt32, display: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.display = display
    }
}

