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

/// A stretch of the real signal on a dot-matrix display of its own, lit as it is read.
///
/// Each column is a sliver of time. The lower band is the jolt score: quiet readings sit on
/// the bottom row and a tap stands up as a column on its own. The upper band is how much the
/// hand had been turning just before. A row of paler dots across each band marks the line that
/// matters there: a jolt has to reach its line, and the hand has to be under its own.
struct SignalDisplay: View {
    /// The dot screen's own spacing, so the two displays are one kind of thing.
    static let cell = (DotScreen.size.width - 60) / CGFloat(DotScreen.columns)
    static let columns = 87
    static let unrestRows = 8
    static let joltRows = 9
    private static let inset: CGFloat = 30
    private static let rows = unrestRows + 1 + joltRows

    static let panel = CGSize(width: inset * 2 + CGFloat(columns) * cell, height: inset * 2 + CGFloat(rows) * cell)
    static let size = CGSize(width: 1620, height: panel.height + 62)

    /// Degrees a second of turning that one dot of the upper band stands for, and the
    /// engine's limit, above which a jolt is refused.
    private let unrestStep = 4.0
    private let unrestLimit = 16.0
    /// Dots of the lower band that a jolt only just counting as a tap reaches.
    private let joltLine = 3
    private let joltScale = 2.4

    let take: Take
    /// Length of the take in seconds.
    let length: Double
    /// 0…1: how far the reading has got.
    let head: Double
    /// 0…1: the display draws on.
    let appear: Double

    var body: some View {
        let left = Self.size.width - Self.panel.width
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        ZStack(alignment: .topLeading) {
            ZStack {
                shape.fill(Look.panel).opacity(span(appear, from: 0.2, over: 0.5))
                shape.trim(from: 0, to: glide(span(appear, from: 0, over: 0.75)))
                    .stroke(Look.hairline, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                shape.stroke(Look.key, lineWidth: 3).opacity(span(head, from: 0, over: 0.04))
                Canvas { context, size in draw(&context, size) }
                    .padding(Self.inset)
                    .opacity(span(appear, from: 0.5, over: 0.5))
            }
            .frame(width: Self.panel.width, height: Self.panel.height)
            .offset(x: left)

            // What each band is, beside it.
            let labels = span(appear, from: 0.5, over: 0.5)
            Text("hand turning").font(Look.label).foregroundStyle(Look.soft).fixedSize()
                .frame(width: left - 28, height: CGFloat(Self.unrestRows) * Self.cell, alignment: .trailing)
                .offset(y: Self.inset)
                .opacity(labels)
            Text("jolts").font(Look.label).foregroundStyle(Look.soft).fixedSize()
                .frame(width: left - 28, height: CGFloat(Self.joltRows) * Self.cell, alignment: .trailing)
                .offset(y: Self.inset + CGFloat(Self.unrestRows + 1) * Self.cell)
                .opacity(labels)

            // What the engine made of each jolt, written under it as the reading passes.
            ForEach(Array(verdicts.enumerated()), id: \.offset) { _, verdict in
                let at = left + Self.inset + (Self.panel.width - Self.inset * 2) * verdict.time / length
                let shown = settle(span(head * length, from: verdict.time + 0.1, over: 0.5))
                Text(verdict.text)
                    .font(Look.label)
                    .foregroundStyle(verdict.accepted ? Look.key : Look.ink)
                    .fixedSize()
                    .frame(width: 360, alignment: .center)
                    .offset(x: min(max(at - 180, left), Self.size.width - 360), y: Self.panel.height + 14 + (1 - shown) * 10)
                    .opacity(shown)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    private func draw(_ context: inout GraphicsContext, _ size: CGSize) {
        let cell = Self.cell
        let step = length / Double(Self.columns)
        let reached = Int((head * Double(Self.columns)).rounded(.down))
        var unlit = Path(), line = Path(), quiet = Path(), bright = Path(), counted = Path()

        func dot(_ column: Int, _ row: Int, _ radius: CGFloat) -> CGRect {
            // Rows count from the top of the display.
            CGRect(x: (CGFloat(column) + 0.5) * cell - radius, y: (CGFloat(row) + 0.5) * cell - radius, width: radius * 2, height: radius * 2)
        }

        for column in 0..<Self.columns {
            let from = Double(column) * step, to = from + step
            let readings = take.readings.filter { $0.time >= from && $0.time < to }
            let revealed = column < reached && !readings.isEmpty

            // Upper band: how much the hand had been turning. Always at least one dot, so it reads as a trace.
            let unrest = readings.map(\.unrest).max() ?? 0
            let restless = revealed ? min(Self.unrestRows, max(1, Int((unrest / unrestStep).rounded()))) : 0
            let limitRow = Int(unrestLimit / unrestStep)
            for k in 1...Self.unrestRows {
                let row = Self.unrestRows - k
                if k <= restless {
                    if restless > limitRow { bright.addEllipse(in: dot(column, row, 4.4)) } else { quiet.addEllipse(in: dot(column, row, 4.4)) }
                } else if k == limitRow {
                    line.addEllipse(in: dot(column, row, 2.9))
                } else {
                    unlit.addEllipse(in: dot(column, row, 2.9))
                }
            }

            // Lower band: the jolt score.
            let level = readings.map(\.level).max() ?? 0
            let height = revealed ? min(Self.joltRows, max(1, Int((level * joltScale).rounded()))) : 0
            let tapped = take.marks.contains { $0.mark == .tap && $0.time >= from - 0.03 && $0.time < to + 0.03 } && height >= joltLine
            for k in 1...Self.joltRows {
                let row = Self.rows - k
                if k <= height {
                    if tapped { counted.addEllipse(in: dot(column, row, 4.4)) } else { quiet.addEllipse(in: dot(column, row, 4.4)) }
                } else if k == joltLine {
                    line.addEllipse(in: dot(column, row, 2.9))
                } else {
                    unlit.addEllipse(in: dot(column, row, 2.9))
                }
            }
        }
        context.fill(unlit, with: .color(Look.dotOff))
        context.fill(line, with: .color(Look.dotLine))
        context.fill(quiet, with: .color(Look.soft))
        context.fill(bright, with: .color(Look.ink))
        context.fill(counted, with: .color(Look.key))
    }

    /// One line per decision: each click (two taps), and each knock refused.
    private var verdicts: [(time: Double, text: String, accepted: Bool)] {
        var out: [(Double, String, Bool)] = []
        for mark in take.marks {
            switch mark.mark {
            case .click: out.append((mark.time - 0.12, "two taps: click", true))
            case .doubleClick: out.append((mark.time, "double-click", true))
            case .rightClick: out.append((mark.time - 0.42, "one tap: right-click", true))
            case .knock:
                // Refused jolts close together are one knock.
                if let last = out.last, !last.2, mark.time - last.0 < 0.8 { continue }
                out.append((mark.time + 0.15, "a knock: refused", false))
            case .tap: break
            }
        }
        return out
    }
}

/// Three results from the recorded session, each with a dot for every tap or knock it counts.
struct Figures: View {
    let t: Double
    let cue: Cue

    private struct Item {
        let got: Int
        let of: Int
        let label: String
        /// Dots for each one counted: 2 for a double-tap.
        var group = 1
        /// Whether a dot lit is the good outcome (a tap found) or the bad one (a knock let through).
        var lit: Bool { got > 0 }
    }

    private let items = [
        Item(got: 10, of: 10, label: "single taps found"),
        Item(got: 6, of: 6, label: "double-taps found", group: 2),
        Item(got: 0, of: 12, label: "knocks let through"),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 92) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let delay = 0.5 + Double(index) * 0.16
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text("\(item.got)").font(Look.figure(168)).foregroundStyle(Look.ink)
                        Text("/ \(item.of)").font(Look.figure(64)).foregroundStyle(Look.soft)
                    }
                    .fixedSize()
                    .reveal(t, cue, delay: delay)
                    dots(item, from: cue.start + delay + 0.45)
                        .padding(.top, 4)
                        .lift(t, cue, delay: delay + 0.2)
                    Text(item.label).font(Look.sub).foregroundStyle(Look.soft).fixedSize()
                        .padding(.top, 22)
                        .lift(t, cue, delay: delay + 0.25)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, Look.margin)
        .padding(.top, 420)
    }

    /// A dot for each one counted, lighting in turn; a knock that was refused stays unlit.
    private func dots(_ item: Item, from start: Double) -> some View {
        HStack(spacing: item.group > 1 ? 16 : 9) {
            ForEach(0..<item.of, id: \.self) { index in
                HStack(spacing: 5) {
                    ForEach(0..<item.group, id: \.self) { _ in
                        let on = item.lit && t >= start + Double(index) * 0.07
                        Circle().fill(on ? Look.key : Look.dotOff).frame(width: on ? 15 : 12, height: on ? 15 : 12)
                            .frame(width: 15, height: 15)
                    }
                }
            }
        }
    }
}

/// Numbered steps, arriving one at a time.
struct Steps: View {
    let t: Double
    let cue: Cue
    let steps: [String]
    /// Seconds before the first step, and between one step and the next.
    var lead = 0.6
    var pace = 1.2

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 26) {
                    Text("\(index + 1)").font(Look.figure(46)).foregroundStyle(Look.key).frame(width: 34, alignment: .leading)
                    Text(step).font(.system(size: 46, weight: .medium)).foregroundStyle(Look.ink).fixedSize()
                }
                .lift(t, cue, delay: lead + Double(index) * pace)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, Look.margin)
        .padding(.top, 330)
    }
}
