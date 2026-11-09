import PointerKit
import SwiftUI

/// First-run setup, shown in the panel beside the stage so the case and the screen are in
/// view the whole way through. Each step advances on its own the moment the thing it asks
/// for becomes true.
struct OnboardingPanel: View {
    @Environment(AppModel.self) private var model
    @State private var started = false
    @State private var earDetectionConfirmed = false
    @State private var practice = 0
    /// True once the grip was learned in this run, or the typical one was accepted.
    @State private var gripTaught = false

    private enum Step: Int, CaseIterable {
        case welcome, motion, pointer, earDetection, openCase, grip, practice, done
    }

    private var step: Step {
        if !started { return .welcome }
        if model.motionAccess != .allowed { return .motion }
        if !model.canControlPointer { return .pointer }
        if !model.hasEverStreamed, !earDetectionConfirmed { return .earDetection }
        if !model.isStreaming, practice < 3 { return .openCase }
        if !gripTaught, !model.calibration.isCalibrated(for: model.sensor) { return .grip }
        if practice < 3 { return .practice }
        return .done
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Progress(current: step.rawValue, total: Step.allCases.count - 1)
                .padding(.bottom, 22)

            Group {
                switch step {
                case .welcome: welcome
                case .motion: motion
                case .pointer: pointer
                case .earDetection: earDetection
                case .openCase: openCase
                case .grip: grip
                case .practice: practiceStep
                case .done: done
                }
            }
            .transition(.opacity)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .animation(Theme.quick, value: step)
        .onChange(of: model.calibrationsLearned) { _, _ in gripTaught = true }
    }

    // MARK: Steps

    private var welcome: some View {
        StepBody(
            title: "Point with your AirPods case",
            text: "The case in your hand becomes the pointer. Aim it and the cursor follows; tap its back to click.\n\nSetting it up takes about a minute, with the case and both AirPods to hand."
        ) {
            Button("Set it up") { started = true }.buttonStyle(.pill(.primary, size: .large))
        }
    }

    private var motion: some View {
        StepBody(
            title: "Let AirPointer read the AirPods",
            text: model.motionAccess == .denied
                ? "Motion access is switched off. Turn it on for AirPointer in Privacy & Security, under Motion & Fitness."
                : "The pointer follows the motion sensors inside the AirPods. macOS asks before any app may read them."
        ) {
            if model.motionAccess == .denied {
                Button("Open Privacy Settings") { Permissions.open(.motion) }.buttonStyle(.pill(.primary, size: .large))
            } else {
                Button("Allow motion") { model.requestMotionAccess() }.buttonStyle(.pill(.primary, size: .large))
            }
        }
    }

    private var pointer: some View {
        StepBody(
            title: "Let it move the pointer",
            text: "macOS treats moving the cursor and clicking as Accessibility control. In the window that opens, switch AirPointer on. This step finishes itself when you do."
        ) {
            Button("Open the prompt") { model.requestPointerAccess() }.buttonStyle(.pill(.primary, size: .large))
            Button("Open Accessibility settings") { Permissions.open(.accessibility) }.buttonStyle(.pill(.quiet))
        }
    }

    private var earDetection: some View {
        StepBody(
            title: "Turn off Automatic Ear Detection",
            text: Text("With it on, the AirPods stop sending motion the moment they are out of your ears.\n\nIn Bluetooth settings, click \(Image(systemName: "info.circle")) beside your AirPods and switch Automatic Ear Detection off. One thing changes: sound no longer pauses by itself when you take an AirPod out.")
        ) {
            Button("Open Bluetooth settings") { Permissions.open(.bluetooth) }.buttonStyle(.pill(.primary, size: .large))
            Button("It's off") { earDetectionConfirmed = true }.buttonStyle(.pill())
        }
    }

    private var openCase: some View {
        StepBody(
            title: "Open the case",
            text: model.isConnectedButSilent
                ? "The AirPods are connected but nothing is arriving. That means Automatic Ear Detection is still on: switch it off in Bluetooth settings."
                : "Put both AirPods in the case and leave the lid open. The lid is the switch: open wakes the pointer, closed puts it to sleep.\n\nWaiting for the AirPods…"
        ) {
            if model.isConnectedButSilent {
                Button("Open Bluetooth settings") { Permissions.open(.bluetooth) }.buttonStyle(.pill(.primary, size: .large))
            }
        }
    }

    private var grip: some View {
        StepBody(
            title: "Teach it your grip",
            text: "Hold the case like a small remote, the open end toward the screen, however is comfortable. AirPointer learns which way that is from one movement: hold still, then tilt the far end up."
        ) {
            if model.isCalibrating {
                Text("Follow the prompt under the case.")
                    .font(Typo.heading)
                    .foregroundStyle(Theme.action)
            } else {
                Button("I'm holding it") { model.beginCalibration() }.buttonStyle(.pill(.primary, size: .large))
                Button("Use a typical grip") { gripTaught = true }.buttonStyle(.pill(.quiet))
            }
        }
    }

    private var practiceStep: some View {
        StepBody(
            title: "Try a click",
            text: "Aim at the lit pill and tap the back of the case twice, firmly. A ring appears where each click lands. One tap on its own is a right-click."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { index in
                        Button {
                            if index == practice { practice += 1 }
                        } label: {
                            Text(index < practice ? "Got it" : index == practice ? "Click me" : "Next")
                                .frame(minWidth: 64)
                        }
                        .buttonStyle(.pill(index == practice ? .primary : .secondary, size: .large))
                        .disabled(index != practice)
                    }
                }
                Text("The trackpad works too, if you would rather skip the practice.")
                    .font(Typo.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var done: some View {
        StepBody(
            title: "That's it",
            text: "AirPointer lives in the menu bar. Open the lid and it is ready; close it and it sleeps.\n\nFeel and Taps below are where to tune it. If up and down ever feel crooked, teach it your grip again from Setup."
        ) {
            Button("Start pointing") { model.hasFinishedSetup = true }.buttonStyle(.pill(.primary, size: .large))
        }
    }
}

private struct StepBody<Actions: View>: View {
    let title: String
    let text: Text
    @ViewBuilder var actions: () -> Actions

    init(title: String, text: Text, @ViewBuilder actions: @escaping () -> Actions) {
        self.title = title
        self.text = text
        self.actions = actions
    }

    init(title: String, text: String, @ViewBuilder actions: @escaping () -> Actions) {
        self.init(title: title, text: Text(text), actions: actions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(Typo.display)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            text
                .font(.system(size: 15))
                .lineSpacing(4)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) { actions() }
                .padding(.top, 10)
        }
    }
}

/// How far through setup, as a row of dots in the screen's own vocabulary.
private struct Progress: View {
    let current: Int
    let total: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index <= current ? Theme.keyline : Theme.dotOff)
                    .frame(width: index == current ? 10 : 7, height: index == current ? 10 : 7)
            }
        }
        .frame(height: 10)
        .animation(reduceMotion ? nil : Theme.quick, value: current)
        .accessibilityElement()
        .accessibilityLabel("Step \(min(current + 1, total)) of \(total)")
    }
}
