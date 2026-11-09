import PointerKit
import SwiftUI

/// One line saying what the pointer is doing, one saying what to do about it.
struct StatusLine: View {
    @Environment(AppModel.self) private var model
    var staysOffPermissions = false

    /// The status to speak about. In setup, a missing permission is the panel's subject,
    /// so here it falls back to what the AirPods themselves are doing.
    private var status: AppModel.Status {
        guard staysOffPermissions, model.status == .motionDenied || model.status == .needsPointerAccess else {
            return model.status
        }
        return model.isStreaming ? .pointing : .asleep
    }

    var body: some View {
        VStack(spacing: 5) {
            Text(headline)
                .font(Typo.display)
                .foregroundStyle(Theme.ink)
                .contentTransition(.opacity)
            Text(detail)
                .font(Typo.body)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 380)
            action.padding(.top, 3)
        }
        .animation(Theme.quick, value: status)
        .accessibilityElement(children: .combine)
    }

    private var headline: String {
        switch status {
        case .motionDenied: "Can't read the AirPods"
        case .needsPointerAccess: "One permission to go"
        case .off: "Off"
        case .asleep: "Asleep"
        case .waking: "Waking"
        case .inEars: "Paused"
        case .calibrating: calibrationHeadline
        case .pointing: staysOffPermissions && model.status != .pointing ? "Awake" : "Pointing"
        }
    }

    private var detail: String {
        switch status {
        case .motionDenied:
            "Motion access is switched off for AirPointer."
        case .needsPointerAccess:
            "macOS has to let AirPointer move the pointer."
        case .off:
            if let shortcut = model.toggleShortcut {
                "Turn it on here, or press \(shortcut.display) from anywhere."
            } else {
                "Turn it on with the switch above."
            }
        case .asleep:
            if model.isConnectedButSilent {
                "The AirPods are connected but sending no motion. Check that Automatic Ear Detection is off."
            } else {
                "Open the case lid, with both AirPods inside."
            }
        case .waking:
            "Checking the AirPods are in the case, not in your ears."
        case .inEars:
            "The AirPods look like they are in your ears."
        case .calibrating:
            calibrationDetail
        case .pointing:
            if staysOffPermissions, model.status != .pointing {
                "The case is sending motion."
            } else if !model.prefs.tapsEnabled {
                "Taps are off. Click with the trackpad."
            } else if model.prefs.tapScheme == .doubleTapClicks {
                "Two taps on the back click. One tap right-clicks."
            } else {
                "Tap the back of the case to click."
            }
        }
    }

    @ViewBuilder private var action: some View {
        switch status {
        case .motionDenied:
            Button("Open Privacy Settings") { Permissions.open(.motion) }.buttonStyle(.pill(.primary, size: .small))
        case .needsPointerAccess:
            Button("Allow…") { model.requestPointerAccess() }.buttonStyle(.pill(.primary, size: .small))
        case .inEars:
            Button("They're in my hand") { model.handOverride = true }.buttonStyle(.pill(size: .small))
        case .calibrating:
            Button("Cancel") { model.cancelCalibration() }.buttonStyle(.pill(.quiet, size: .small))
        default:
            EmptyView()
        }
    }

    private var calibrationHeadline: String {
        switch model.calibrationStage {
        case .ready: "Now tilt it up"
        case .capturing: "Keep going"
        default: "Hold still"
        }
    }

    private var calibrationDetail: String {
        switch model.calibrationProblem {
        case .sideways: "That was more of a turn. Tilt the far end straight up."
        case .tooSmall: "A little further. Tilt the far end up toward the ceiling."
        case nil: "Aim at the screen as you will hold it, then tilt up once."
        }
    }
}

/// The room: a pale wall for the screen to hang on, and a floor, a shade deeper, for the
/// case to stand on. The line where they meet passes behind the case.
struct StageBackground: View {
    /// How far down the window the wall meets the floor.
    static let horizon = 0.628

    var body: some View {
        GeometryReader { proxy in
            let y = proxy.size.height * Self.horizon
            ZStack(alignment: .top) {
                Theme.stageFloor
                // Wall: brightest at the top, where the light is.
                LinearGradient(colors: [Theme.panel.opacity(0.55), Theme.stage, Theme.stage], startPoint: .top, endPoint: .bottom)
                    .background(Theme.stage)
                    .frame(height: y)
                // Floor: lightest where it meets the wall, deepening toward the viewer.
                LinearGradient(colors: [Theme.stage.opacity(0.75), Theme.stageFloor.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 90)
                    .offset(y: y)
                // The skirting line, fading out toward the sides.
                LinearGradient(
                    colors: [Theme.hairline.opacity(0), Theme.hairline, Theme.hairline, Theme.hairline.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 1)
                .offset(y: y)
            }
        }
        .ignoresSafeArea()
    }
}
