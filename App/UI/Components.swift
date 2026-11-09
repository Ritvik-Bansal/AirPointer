import AppKit
import SwiftUI

// MARK: Pills

/// The world's button: a capsule with a blue outline. Sized generously, because this
/// window is often operated with the case itself from arm's length.
struct PillButtonStyle: ButtonStyle {
    enum Kind {
        /// Filled. The one thing to do next.
        case primary
        /// White with a keyline. Everything else that acts.
        case secondary
        /// Text only, for the least important action in a group.
        case quiet
    }

    enum Size {
        case small, regular, large

        var height: CGFloat {
            switch self {
            case .small: 30
            case .regular: 38
            case .large: 48
            }
        }

        var padding: CGFloat {
            switch self {
            case .small: 14
            case .regular: 20
            case .large: 28
            }
        }

        var font: Font {
            switch self {
            case .small: .system(size: 13, weight: .semibold, design: .rounded)
            case .regular, .large: Typo.pill
            }
        }
    }

    var kind = Kind.secondary
    var size = Size.regular

    func makeBody(configuration: Configuration) -> some View {
        PillBody(configuration: configuration, kind: kind, size: size)
    }

    private struct PillBody: View {
        let configuration: ButtonStyleConfiguration
        let kind: Kind
        let size: Size
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(size.font)
                .lineLimit(1)
                .foregroundStyle(foreground)
                .padding(.horizontal, size.padding)
                .frame(minHeight: size.height)
                .background(background)
                .contentShape(Capsule())
                .scaleEffect(configuration.isPressed ? 0.97 : hovering && size == .large && !reduceMotion ? 1.035 : 1)
                .opacity(isEnabled ? 1 : 0.45)
                .animation(Theme.quick, value: configuration.isPressed)
                .animation(Theme.quick, value: hovering)
                .onHover { hovering = $0 && isEnabled }
        }

        private var foreground: Color {
            switch kind {
            case .primary: Theme.onAction
            case .secondary: Theme.action
            case .quiet: hovering ? Theme.ink : Theme.inkSoft
            }
        }

        @ViewBuilder private var background: some View {
            switch kind {
            case .primary:
                Capsule()
                    .fill(Theme.action)
                    .brightness(configuration.isPressed ? -0.06 : hovering ? 0.07 : 0)
                    .shadow(color: Theme.shadow(0.16), radius: hovering ? 7 : 4, y: hovering ? 3 : 2)
            case .secondary:
                Capsule()
                    .fill(Theme.panel)
                    .overlay(Capsule().fill(Theme.keyline.opacity(configuration.isPressed ? 0.24 : hovering ? 0.16 : 0)))
                    .overlay(Capsule().strokeBorder(Theme.keyline, lineWidth: hovering ? 2.5 : 1.5))
                    .shadow(color: Theme.shadow(hovering ? 0.12 : 0.06), radius: hovering ? 6 : 2, y: hovering ? 3 : 1)
            case .quiet:
                Capsule().fill(Theme.hairline.opacity(hovering ? 0.6 : 0))
            }
        }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static func pill(_ kind: PillButtonStyle.Kind = .secondary, size: PillButtonStyle.Size = .regular) -> PillButtonStyle {
        PillButtonStyle(kind: kind, size: size)
    }
}

/// The master switch: a wide capsule that says which way it is set.
struct PowerSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                if configuration.isOn {
                    Text("On").foregroundStyle(Theme.onAction).padding(.leading, 14)
                }
                Circle()
                    .fill(.white)
                    .frame(width: 24, height: 24)
                    .shadow(color: Theme.shadow(0.2), radius: 1.5, y: 1)
                if !configuration.isOn {
                    Text("Off").foregroundStyle(Theme.inkSoft).padding(.trailing, 14)
                }
            }
            .font(Typo.pill)
            .padding(4)
            .frame(height: 32)
            .background(
                Capsule().fill(configuration.isOn ? Theme.action : Theme.hairline)
            )
            .overlay(Capsule().strokeBorder(configuration.isOn ? Color.clear : Theme.inkSoft.opacity(0.25), lineWidth: 1))
            .contentShape(Capsule())
            .animation(Theme.quick, value: configuration.isOn)
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}

// MARK: Rows

/// A labelled slider with its value read out and one line saying what it changes.
struct SettingSlider: View {
    let title: String
    let detail: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var low = ""
    var high = ""
    let readout: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(Typo.heading).foregroundStyle(Theme.ink)
                Spacer()
                Text(readout(value)).font(Typo.figure).foregroundStyle(Theme.action)
            }
            Slider(value: $value, in: range) {
                Text(title)
            } minimumValueLabel: {
                Text(low).font(Typo.caption).foregroundStyle(Theme.inkSoft).frame(width: 46, alignment: .leading)
            } maximumValueLabel: {
                Text(high).font(Typo.caption).foregroundStyle(Theme.inkSoft).frame(width: 46, alignment: .trailing)
            }
            .labelsHidden()
            .controlSize(.large)
            .tint(Theme.action)
            if !detail.isEmpty {
                Text(detail)
                    .font(Typo.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A switch with a title and, when it helps, a line of explanation.
struct SettingToggle: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typo.heading).foregroundStyle(Theme.ink)
                if let detail {
                    Text(detail)
                        .font(Typo.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .tint(Theme.action)
    }
}

/// A heading inside a panel, with a rule beneath to separate groups without boxing them.
struct GroupHeading: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text).font(Typo.title).foregroundStyle(Theme.ink)
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
        .padding(.top, 10)
    }
}

// MARK: Tap glyphs

/// One, two or three dots: the picture of a tap count, used wherever a gesture is named.
struct TapDots: View {
    let count: Int
    var lit = true

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { _ in
                Circle()
                    .fill(lit ? Theme.keyline : Theme.dotOff)
                    .frame(width: 9, height: 9)
            }
        }
        .frame(width: 44, alignment: .leading)
        .accessibilityHidden(true)
    }
}

// MARK: Shortcut field

/// Shows a global shortcut and records a new one when clicked.
struct ShortcutField: View {
    let title: String
    @Binding var shortcut: Shortcut?
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(title).font(Typo.heading).foregroundStyle(Theme.ink)
            Spacer()
            if shortcut != nil, !recording {
                Button("Clear") { shortcut = nil }
                    .buttonStyle(.pill(.quiet, size: .small))
            }
            Button {
                recording ? stop() : start()
            } label: {
                Text(recording ? "Press keys…" : shortcut?.display ?? "None")
                    .font(Typo.figure)
                    .frame(minWidth: 76)
            }
            .buttonStyle(.pill(recording ? .primary : .secondary, size: .small))
            .accessibilityLabel("\(title) shortcut")
            .accessibilityValue(shortcut?.display ?? "None")
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape cancels
                stop()
                return nil
            }
            if let recorded = Shortcut(event: event) {
                shortcut = recorded
                stop()
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

