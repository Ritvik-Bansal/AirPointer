import PointerKit
import SwiftUI

/// The four things the window can open beside the stage.
enum Tab: String, CaseIterable, Identifiable {
    case feel, taps, setup, signal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feel: "Feel"
        case .taps: "Taps"
        case .setup: "Setup"
        case .signal: "Signal"
        }
    }
}

/// Four large pills. Large because they are often clicked with the case itself.
private struct TabBar: View {
    @Binding var selection: Tab?
    let needsAttention: Bool

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Tab.allCases) { tab in
                TabPill(tab: tab, isSelected: selection == tab, showsBadge: tab == .setup && needsAttention) {
                    selection = selection == tab ? nil : tab
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 14)
    }
}

private struct TabPill: View {
    let tab: Tab
    let isSelected: Bool
    let showsBadge: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tab.title)
                .frame(minWidth: 92)
                .overlay(alignment: .topTrailing) {
                    if showsBadge {
                        Circle().fill(Theme.warn).frame(width: 9, height: 9).offset(x: 12, y: -4)
                    }
                }
        }
        .buttonStyle(.pill(isSelected ? .primary : .secondary, size: .large))
        .accessibilityLabel(showsBadge ? "\(tab.title), needs attention" : tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(isSelected ? "Close \(tab.title)" : "Open \(tab.title)")
    }
}
