import SwiftUI

/// A label joined to a point on the case by a thin line.
struct Callout: View {
    let t: Double
    let cue: Cue
    var delay = 0.0
    /// The point on the case.
    let anchor: CGPoint
    /// Where the line turns.
    let elbow: CGPoint
    /// Where the line ends and the label begins.
    let end: CGPoint
    let text: String
    /// True when the label sits to the left of `end` and should be right-aligned to it.
    var trailing = false

    var body: some View {
        let shifted = Cue(start: cue.start + delay, end: cue.end)
        let drawn = glide(span(t, from: shifted.start, over: 0.55))
        let out = 1 - shifted.leave(t)
        ZStack {
            Path { p in
                p.move(to: anchor)
                p.addLine(to: elbow)
                p.addLine(to: end)
            }
            .trim(from: 0, to: drawn)
            .stroke(Look.soft, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            // An open ring, so it cannot be taken for the case's own status light.
            Circle().fill(Look.wall).frame(width: 16, height: 16)
                .overlay(Circle().strokeBorder(Look.soft, lineWidth: 3))
                .scaleEffect(settle(span(t, from: shifted.start, over: 0.3)))
                .position(anchor)
            Text(text)
                .font(Look.label)
                .foregroundStyle(Look.ink)
                .fixedSize()
                .lift(t, Cue(start: shifted.start + 0.4, end: cue.end))
                .frame(width: 620, alignment: trailing ? .trailing : .leading)
                .position(x: end.x + (trailing ? -326 : 326), y: end.y)
        }
        .opacity(out)
    }
}

