import PointerKit
import SwiftUI

/// The menu-bar panel: the pointer's state at a glance, the switch, and the two things
/// people reach for most.
struct PopoverView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline).font(Typo.title).foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(Typo.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("Pointer", isOn: $model.isOn).toggleStyle(PowerSwitchStyle())
            }

            DotScreen(runtime: model.runtime, isLive: model.status == .pointing, columns: 34, rows: Int((34 / DotScreen.displayAspect).rounded()))
                .frame(height: 28 + 280 / DotScreen.displayAspect)

            if model.status == .inEars {
                Button("They're in my hand") { model.handOverride = true }
                    .buttonStyle(.pill(size: .small))
            } else if model.status == .needsPointerAccess {
                Button("Allow pointer control…") { model.requestPointerAccess() }
                    .buttonStyle(.pill(.primary, size: .small))
            }

            SettingSlider(
                title: "Speed", detail: "", value: $model.prefs.speed, range: 0.4...2.5, low: "Slow", high: "Fast"
            ) { String(format: "%.1f×", $0) }

            if let battery {
                Text(battery)
                    .font(Typo.figure)
                    .foregroundStyle(Theme.inkSoft)
                    .accessibilityLabel("Battery: \(battery)")
            }

            Rectangle().fill(Theme.hairline).frame(height: 1)

            HStack(spacing: 8) {
                Button("Teach grip") { model.isCalibrating ? model.cancelCalibration() : model.beginCalibration() }
                    .buttonStyle(.pill(size: .small))
                    .disabled(!model.isStreaming)
                Button("Open AirPointer") { openWindow(id: "main") }
                .buttonStyle(.pill(size: .small))
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.pill(.quiet, size: .small))
                    .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 340)
        .background(Theme.stage)
        .onAppear { model.popoverVisible = true }
        .onDisappear { model.popoverVisible = false }
    }

    private var headline: String {
        switch model.status {
        case .motionDenied: "Can't read the AirPods"
        case .needsPointerAccess: "Needs permission"
        case .off: "Off"
        case .asleep: "Asleep"
        case .waking: "Waking"
        case .inEars: "Paused"
        case .calibrating: "Teaching your grip"
        case .pointing: "Pointing"
        }
    }

    private var detail: String {
        switch model.status {
        case .motionDenied: "Motion access is off in Privacy settings."
        case .needsPointerAccess: "macOS has to allow it to move the pointer."
        case .off: "Switch it on to point with the case."
        case .asleep: model.isConnectedButSilent ? "Connected, but no motion. Check ear detection is off." : "Open the case lid to wake it."
        case .waking: "Checking the AirPods are in the case."
        case .inEars: "The AirPods look like they are in your ears."
        case .calibrating: "Hold still, then tilt the case up."
        case .pointing: model.prefs.tapScheme == .doubleTapClicks ? "Two taps click. One is a right-click." : "Tap the case to click."
        }
    }

    private var battery: String? {
        guard let info = model.airPods, info.isConnected else { return nil }
        let parts = [info.left.map { "L \($0)%" }, info.right.map { "R \($0)%" }, info.caseLevel.map { "Case \($0)%" }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: "   ")
    }
}

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
