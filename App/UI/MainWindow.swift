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

/// The white panel that holds a tab's controls. Outlined in the keyline like the pills.
/// When there is more than fits, the bottom edge fades and a chevron says so.
private struct PanelShell<Content: View, Footer: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer
    @State private var hasMoreBelow = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                content()
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.containerSize.height < geometry.contentSize.height - 6
            } action: { _, more in
                hasMoreBelow = more
            }
            .overlay(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    LinearGradient(colors: [Theme.panel.opacity(0), Theme.panel], startPoint: .top, endPoint: .bottom)
                        .frame(height: 56)
                    Image(systemName: "chevron.compact.down")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.action)
                        .padding(.bottom, 5)
                        .accessibilityHidden(true)
                }
                .opacity(hasMoreBelow ? 1 : 0)
                .animation(Theme.quick, value: hasMoreBelow)
                .allowsHitTesting(false)
            }
            footer()
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous)
                .fill(Theme.panel)
                .shadow(color: Theme.shadow(0.10), radius: 16, y: 8)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous)
                .strokeBorder(Theme.keyline.opacity(0.7), lineWidth: 1)
        )
        .padding(.trailing, 18)
        .padding(.bottom, 8)
    }
}

extension PanelShell where Footer == EmptyView {
    init(@ViewBuilder content: @escaping () -> Content) {
        self.init(content: content) { EmptyView() }
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
