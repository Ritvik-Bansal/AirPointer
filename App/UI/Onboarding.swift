import PointerKit
import SwiftUI

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
