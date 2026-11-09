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

/// The window: a stage, and along the bottom four pills that each open a panel beside it.
///
/// With nothing open the stage stands alone in the middle, which is the whole idea in one
/// picture. Opening a panel slides the stage left; closing it lets the stage back.
struct MainWindow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("openTab") private var storedTab = ""
    @State private var tab: Tab?

    private let panelWidth: CGFloat = 448

    var body: some View {
        VStack(spacing: 0) {
            TopBar()

            HStack(spacing: 0) {
                // Any spare height goes under the status line, so its button never crowds the pills.
                StageView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if !model.hasFinishedSetup {
                    PanelShell {
                        OnboardingPanel()
                    } footer: {
                        Button("Skip setup") { model.hasFinishedSetup = true }
                            .buttonStyle(.pill(.quiet, size: .small))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 14)
                    }
                    .frame(width: panelWidth)
                    .transition(panelTransition)
                } else if let tab {
                    PanelShell {
                        switch tab {
                        case .feel: FeelPanel()
                        case .taps: TapsPanel()
                        case .setup: SetupPanel()
                        case .signal: SignalPanel()
                        }
                    }
                    .id(tab)
                    .frame(width: panelWidth)
                    .transition(panelTransition)
                }
            }
            .frame(maxHeight: .infinity)

            if model.hasFinishedSetup {
                TabBar(selection: $tab, needsAttention: needsAttention)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        // The top bar shares its row with the window's own buttons, so the content runs up
        // under the title bar. The room is the window's own background and fills all of it.
        .ignoresSafeArea(.container, edges: .top)
        .frame(width: 880, height: 640)
        .containerBackground(for: .window) { StageBackground() }
        .animation(reduceMotion ? Theme.quick : Theme.settle, value: tab)
        .animation(reduceMotion ? Theme.quick : Theme.settle, value: model.hasFinishedSetup)
        .onAppear {
            tab = Tab(rawValue: storedTab)
            model.windowVisible = true
            // While its window is open the app behaves like any other: in the Dock, in the
            // app switcher. Closed, it goes back to being only a menu-bar icon.
            if !Rehearsal.staysInBackground {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate()
            }
        }
        .onDisappear {
            model.windowVisible = false
            NSApp.setActivationPolicy(.accessory)
        }
        .onChange(of: tab) { _, new in storedTab = new?.rawValue ?? "" }
    }

    /// Panels slide in from the right; with Reduce Motion on they fade in place.
    private var panelTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity)
    }

    /// Setup wants a look when something only the user can fix is in the way.
    private var needsAttention: Bool {
        model.status == .motionDenied || model.status == .needsPointerAccess || model.isConnectedButSilent
    }
}

/// The strip under the title bar: the name on the left, the master switch on the right.
private struct TopBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 12) {
            Spacer().frame(width: 62) // room for the window's close, minimise and zoom buttons
            Text("AirPointer")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            Toggle("Pointer", isOn: $model.isOn)
                .toggleStyle(PowerSwitchStyle())
                .help(model.isOn ? "Turn the pointer off" : "Turn the pointer on")
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
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
