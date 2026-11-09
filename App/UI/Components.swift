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

