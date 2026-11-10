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

/// The two rotations the pointer reads, drawn round the case: turning about gravity, and tilting.
struct AxisDiagram: View {
    /// Centre of the case in the frame.
    let centre: CGPoint
    /// 0…1: the line of gravity draws on.
    let appear: Double
    /// 0…1: each arc draws on, and how strongly its rotation is being shown right now.
    let turnDrawn: Double
    let turning: Double
    let tiltDrawn: Double
    let tilting: Double
    /// 0…1: everything leaves.
    let out: Double

    private let tiltRadius = 372.0

    var body: some View {
        ZStack {
            // Gravity: a dashed line straight down through the case.
            Path { p in
                p.move(to: CGPoint(x: centre.x, y: centre.y - 372))
                p.addLine(to: CGPoint(x: centre.x, y: centre.y + 348))
            }
            .trim(from: 0, to: glide(appear))
            .stroke(Look.soft, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 11]))
            arrowhead(at: CGPoint(x: centre.x, y: centre.y + 352), angle: .pi / 2).fill(Look.soft)
                .opacity(span(appear, from: 0.8, over: 0.2))
            Text("gravity").font(Look.label).foregroundStyle(Look.soft).fixedSize()
                .position(x: centre.x + 88, y: centre.y - 354).opacity(span(appear, from: 0.2, over: 0.5))

            // Turning: an arc round the front of the case.
            let turnColor = Look.key.opacity(0.3 + 0.7 * turning)
            Path { p in
                p.addArc(center: .zero, radius: 1, startAngle: .degrees(28), endAngle: .degrees(152), clockwise: false)
            }
            .applying(CGAffineTransform(translationX: centre.x, y: centre.y + 84).scaledBy(x: 430, y: 96))
            .trim(from: 0, to: glide(turnDrawn))
            .stroke(turnColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            arrowhead(at: ellipse(28, dx: 430, dy: 96, y: 84), angle: -1.12).fill(turnColor).opacity(span(turnDrawn, from: 0.7, over: 0.3))
            arrowhead(at: ellipse(152, dx: 430, dy: 96, y: 84), angle: .pi + 1.12).fill(turnColor).opacity(span(turnDrawn, from: 0.7, over: 0.3))
            Text("left and right").font(Look.label).foregroundStyle(Look.ink.opacity(0.4 + 0.6 * turning)).fixedSize()
                .frame(width: 320, alignment: .trailing)
                .position(x: centre.x - 430 - 184, y: centre.y + 126).opacity(span(turnDrawn, from: 0.3, over: 0.5))

            // Tilting: an arc up the side the case is now facing.
            let tiltColor = Look.key.opacity(0.3 + 0.7 * tilting)
            // It sits above the turning arc, so that the two do not meet.
            let top = -32.0, bottom = 13.0
            Path { p in
                p.addArc(center: centre, radius: tiltRadius, startAngle: .degrees(bottom), endAngle: .degrees(top), clockwise: true)
            }
            .trim(from: 0, to: glide(tiltDrawn))
            .stroke(tiltColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            arrowhead(at: onCircle(top), angle: (top - 90) * .pi / 180).fill(tiltColor).opacity(span(tiltDrawn, from: 0.7, over: 0.3))
            arrowhead(at: onCircle(bottom), angle: (bottom + 90) * .pi / 180).fill(tiltColor).opacity(span(tiltDrawn, from: 0.7, over: 0.3))
            Text("up and down").font(Look.label).foregroundStyle(Look.ink.opacity(0.4 + 0.6 * tilting)).fixedSize()
                .frame(width: 320, alignment: .trailing)
                .position(x: onCircle(top).x - 62, y: onCircle(top).y - 52).opacity(span(tiltDrawn, from: 0.3, over: 0.5))
        }
        .opacity(1 - out)
    }

    private func ellipse(_ degrees: Double, dx: Double, dy: Double, y: Double) -> CGPoint {
        let a = degrees * .pi / 180
        return CGPoint(x: centre.x + cos(a) * dx, y: centre.y + y + sin(a) * dy)
    }

    private func onCircle(_ degrees: Double) -> CGPoint {
        let a = degrees * .pi / 180
        return CGPoint(x: centre.x + cos(a) * tiltRadius, y: centre.y + sin(a) * tiltRadius)
    }

    /// A small solid triangle pointing along `angle`.
    private func arrowhead(at point: CGPoint, angle: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 13, y: 0))
        path.addLine(to: CGPoint(x: -9, y: -10))
        path.addLine(to: CGPoint(x: -9, y: 10))
        path.closeSubpath()
        return path.applying(CGAffineTransform(translationX: point.x, y: point.y).rotated(by: angle))
    }
}

