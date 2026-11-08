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

