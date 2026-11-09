import SwiftUI

@main
struct AirPointerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView().environment(model)
        } label: {
            MenuBarIcon().environment(model)
        }
        .menuBarExtraStyle(.window)

        Window("AirPointer", id: "main") {
            MainWindow().environment(model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        // Stay out of the way at login; on first run the window is the setup.
        .defaultLaunchBehavior(UserDefaults.standard.bool(forKey: "hasFinishedSetup") ? .suppressed : .presented)
        .restorationBehavior(.disabled)
        .commands {
            // A single-window utility has nothing to make new.
            CommandGroup(replacing: .newItem) {}
        }
    }
}

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
