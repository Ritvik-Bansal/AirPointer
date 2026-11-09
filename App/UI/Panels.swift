import PointerKit
import SwiftUI

/// Cursor speed against hand speed, with a dot riding the curve at the speed the hand is
/// moving right now. It is the three sliders above, drawn.
struct ResponseCurve: View {
    let prefs: PointerPreferences
    let runtime: PointerRuntime

    /// Fastest hand speed shown, deg/s.
    private let maxHand = 200.0
    /// Top of the vertical scale, in screen widths per second.
    private let maxCursor = 9.5

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
                Canvas { context, size in
                    let shaper = RateShaper(params: prefs.engineSettings().shaper)
                    func y(_ hand: Double) -> Double {
                        let cursor = hand * shaper.gain(atSpeed: hand) * shaper.release(atSpeed: hand) / 1512
                        return size.height - 6 - min(cursor / maxCursor, 1) * (size.height - 12)
                    }
                    func x(_ hand: Double) -> Double { hand / maxHand * size.width }

                    // Baseline and quarter marks.
                    var grid = Path()
                    grid.move(to: CGPoint(x: 0, y: size.height - 0.5))
                    grid.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
                    for q in 1...3 {
                        let gx = size.width * Double(q) / 4
                        grid.move(to: CGPoint(x: gx, y: size.height - 5))
                        grid.addLine(to: CGPoint(x: gx, y: size.height))
                    }
                    context.stroke(grid, with: .color(Theme.hairline), lineWidth: 1)

                    var curve = Path()
                    curve.move(to: CGPoint(x: 0, y: y(0)))
                    for step in 1...100 {
                        let hand = maxHand * Double(step) / 100
                        curve.addLine(to: CGPoint(x: x(hand), y: y(hand)))
                    }
                    var area = curve
                    area.addLine(to: CGPoint(x: size.width, y: size.height - 1))
                    area.addLine(to: CGPoint(x: 0, y: size.height - 1))
                    area.closeSubpath()
                    context.fill(area, with: .color(Theme.keyline.opacity(0.10)))
                    context.stroke(curve, with: .color(Theme.keyline), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    let live = runtime.snapshot()
                    if live.isStreaming {
                        let hand = min(hypot(live.telemetry.yaw, live.telemetry.pitch), maxHand)
                        let p = CGPoint(x: x(hand), y: y(hand))
                        context.fill(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(Theme.keyline.opacity(0.2)))
                        context.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)), with: .color(Theme.action))
                    }
                }
            }
            HStack {
                Text("Still")
                Spacer()
                Text("Hand speed")
                Spacer()
                Text("Fast flick")
            }
            .font(Typo.caption)
            .foregroundStyle(Theme.inkSoft)
        }
        .accessibilityElement()
        .accessibilityLabel("Response curve: cursor speed rises with hand speed")
    }
}

/// The line at the top of a panel that says what the panel is for.
struct PanelHeading: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Typo.title)
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}
