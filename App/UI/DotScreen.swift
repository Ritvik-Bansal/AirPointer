import AppKit
import SwiftUI

/// A miniature of the Mac's display, made of dots. The dot under the real cursor is lit;
/// it leaves a short trail as it moves and sends out a ring on every tap.
///
/// It shows the actual cursor, not a simulation, so what lights up here is exactly what
/// the hand is doing on the real screen.
struct DotScreen: View {
    let runtime: PointerRuntime
    /// When false the cursor is still marked, but dimly: the pointer is not the one moving it.
    var isLive: Bool
    var columns = 40
    var rows = 26
    @State private var memory = DotMemory()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Live, it keeps pace with the display. Otherwise it only has the trackpad's cursor
        // to mark, and a few frames a second is plenty.
        TimelineView(.animation(minimumInterval: isLive ? 1.0 / 60 : 1.0 / 8)) { timeline in
            Canvas(opaque: false, rendersAsynchronously: false) { context, size in
                draw(in: &context, size: size, now: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.panel)
                // Lit while the pointer is live, like a screen that is switched on.
                .shadow(color: Theme.keyline.opacity(isLive ? 0.32 : 0), radius: 14)
                .shadow(color: Theme.shadow(0.10), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isLive ? Theme.keyline : Theme.hairline, lineWidth: isLive ? 1.5 : 1)
        )
        .animation(Theme.quick, value: isLive)
        .accessibilityElement()
        .accessibilityLabel("Miniature of your display")
        .accessibilityValue(isLive ? "The pointer is live" : "The pointer is paused")
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, now: Double) {
        let live = runtime.snapshot()
        let cursor = live.rehearsalCursor ?? Self.cursorOnMainDisplay()
        memory.note(cursor: cursor, tapCount: live.tapCount, now: now, recordTrail: isLive)

        let cellW = size.width / Double(columns), cellH = size.height / Double(rows)
        let cu = cursor.x * Double(columns) - 0.5, cv = cursor.y * Double(rows) - 0.5
        let off = Theme.dotOff, lit = Theme.keyline, idle = Theme.inkSoft
        // Nearly every dot is unlit. Those go into one path and are filled in one go; only
        // the few near the cursor, its trail or a ring are drawn singly.
        var unlit = Path()

        for j in 0..<rows {
            for i in 0..<columns {
                let x = Double(i), y = Double(j)
                let d2 = (x - cu) * (x - cu) + (y - cv) * (y - cv)
                var glow = 0.0

                if isLive {
                    glow = exp(-d2 / 3.1)
                    for point in memory.trail {
                        let age = (now - point.time) / DotMemory.trailLife
                        guard age < 1 else { continue }
                        let px = point.u * Double(columns) - 0.5, py = point.v * Double(rows) - 0.5
                        let t2 = (x - px) * (x - px) + (y - py) * (y - py)
                        if t2 < 9 { glow = max(glow, 0.6 * (1 - age) * exp(-t2 / 1.6)) }
                    }
                }
                for ring in memory.rings {
                    let t = (now - ring.time) / DotMemory.ringLife
                    guard t < 1 else { continue }
                    // Fast out, easing to rest: the ring spreads and thins. With Reduce
                    // Motion on it holds one size and only fades.
                    let radius = reduceMotion ? 4.5 : 1.2 + 8.5 * (1 - pow(1 - t, 3))
                    let rx = ring.u * Double(columns) - 0.5, ry = ring.v * Double(rows) - 0.5
                    let dist = ((x - rx) * (x - rx) + (y - ry) * (y - ry)).squareRoot()
                    glow = max(glow, (1 - t) * exp(-(dist - radius) * (dist - radius) / 1.1))
                }

                let center = CGPoint(x: (x + 0.5) * cellW, y: (y + 0.5) * cellH)
                if glow > 0.03 {
                    let r = 1.5 + 2.0 * glow
                    if glow > 0.45 {
                        context.fill(circle(center, r + 3), with: .color(lit.opacity(0.16 * glow)))
                    }
                    context.fill(circle(center, r), with: .color(off))
                    context.fill(circle(center, r), with: .color(lit.opacity(min(1, glow * 1.25))))
                } else if !isLive, d2 < 1.2 {
                    context.fill(circle(center, 2.4), with: .color(idle))
                } else {
                    unlit.addEllipse(in: CGRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3))
                }
            }
        }
        context.fill(unlit, with: .color(off))
    }

    private func circle(_ c: CGPoint, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    /// The cursor's place on the main display, 0…1 from the top-left corner.
    static func cursorOnMainDisplay() -> CGPoint {
        guard let screen = NSScreen.screens.first else { return CGPoint(x: 0.5, y: 0.5) }
        let p = NSEvent.mouseLocation
        let f = screen.frame
        return CGPoint(
            x: min(max((p.x - f.minX) / f.width, 0), 1),
            y: min(max(1 - (p.y - f.minY) / f.height, 0), 1)
        )
    }

    /// Width over height of the main display, so the miniature has the same shape.
    static var displayAspect: CGFloat {
        guard let f = NSScreen.screens.first?.frame, f.height > 0 else { return 1.54 }
        return f.width / f.height
    }
}

/// Where the cursor has just been, and the taps still rippling.
final class DotMemory {
    static let trailLife = 0.42
    static let ringLife = 0.6

    struct Point {
        var u: Double
        var v: Double
        var time: Double
    }

    private(set) var trail: [Point] = []
    private(set) var rings: [Point] = []
    private var lastTapCount: Int?

    func note(cursor: CGPoint, tapCount: Int, now: Double, recordTrail: Bool) {
        trail.removeAll { now - $0.time > Self.trailLife }
        rings.removeAll { now - $0.time > Self.ringLife }
        if recordTrail {
            trail.append(Point(u: cursor.x, v: cursor.y, time: now))
            if trail.count > 28 { trail.removeFirst(trail.count - 28) }
        }
        if let last = lastTapCount, tapCount != last {
            rings.append(Point(u: cursor.x, v: cursor.y, time: now))
        }
        lastTapCount = tapCount
    }
}
