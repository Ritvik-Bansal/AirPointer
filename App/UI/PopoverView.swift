import PointerKit
import SwiftUI

/// The menu-bar icon: the case, filled while pointing, hollow otherwise, and marked when
/// something needs fixing.
struct MenuBarIcon: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: symbol)
            .accessibilityLabel("AirPointer: \(label)")
            .onReceive(NotificationCenter.default.publisher(for: .showMainWindow)) { _ in
                openWindow(id: "main")
            }

    }

    private var symbol: String {
        switch model.status {
        case .pointing, .calibrating: "airpodspro.chargingcase.wireless.fill"
        case .motionDenied, .needsPointerAccess: "exclamationmark.triangle"
        default: "airpodspro.chargingcase.wireless"
        }
    }

    private var label: String {
        switch model.status {
        case .pointing: "pointing"
        case .calibrating: "teaching your grip"
        case .asleep: "asleep"
        case .waking: "waking"
        case .off: "off"
        case .inEars: "paused"
        case .motionDenied, .needsPointerAccess: "needs permission"
        }
    }
}
