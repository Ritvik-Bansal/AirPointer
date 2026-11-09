import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // A menu-bar app starts with no window. On first run the window is the setup, so ask for it.
        if !UserDefaults.standard.bool(forKey: "hasFinishedSetup") || UserDefaults.standard.bool(forKey: "showWindow") {
            // `-showWindowAfter <seconds>` delays it, so a replay has history to show by then.
            let delay = max(0.4, UserDefaults.standard.double(forKey: "showWindowAfter"))
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { Self.showMainWindow() }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { Self.showMainWindow() }
        return true
    }

    /// Only a SwiftUI view can open a SwiftUI window, so this asks the menu-bar icon to do it.
    static func showMainWindow() {
        NotificationCenter.default.post(name: .showMainWindow, object: nil)
    }
}

extension Notification.Name {
    static let showMainWindow = Notification.Name("com.ritvikbansal.AirPointer.showMainWindow")
}
