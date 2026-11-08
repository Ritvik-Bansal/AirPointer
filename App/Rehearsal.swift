import AppKit
import PointerKit
import SwiftUI

/// Development switches, all given as launch arguments and none of them saved:
///
///     -rehearse <trace file>     play a recording in place of the AirPods; the real cursor is untouched
///     -appearance light|dark     force the look, whatever the system is set to
///     -popoverWindow YES         show the menu-bar panel in an ordinary window
///     -showWindow YES            open the main window at launch even after setup
///     -showWindowAfter <seconds> wait before opening it
///     -background YES            open windows without coming to the front or joining the Dock
///
/// Saved choices can be overridden the same way, for example `-hasFinishedSetup YES -openTab feel`.
enum Rehearsal {
    static var staysInBackground: Bool { UserDefaults.standard.bool(forKey: "background") }

    @MainActor
    static func beginIfAsked(_ model: AppModel) {
        let defaults = UserDefaults.standard
        switch defaults.string(forKey: "appearance") {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }
        if let path = defaults.string(forKey: "rehearse"), let text = try? String(contentsOfFile: path, encoding: .utf8) {
            model.beginRehearsal(MotionTrace.parse(text))
        }
        if defaults.bool(forKey: "popoverWindow") {
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0.5, defaults.double(forKey: "showWindowAfter"))) {
                let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
                window.title = "Popover"
                window.contentView = NSHostingView(rootView: PopoverView().environment(model))
                window.isReleasedWhenClosed = false
                window.center()
                window.orderFrontRegardless()
                popoverWindow = window
            }
        }
    }

    @MainActor private static var popoverWindow: NSWindow?
}
