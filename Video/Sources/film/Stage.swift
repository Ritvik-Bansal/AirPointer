import SwiftUI

/// The room the whole film is set in: a wall and a floor, two flat tones.
struct Room: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Look.wall
            Look.floor.frame(height: Look.size.height - Look.horizon)
        }
    }
}

/// The dot-matrix screen on the wall: a miniature of the Mac's display, with the cursor as lit dots.
struct DotScreen: View {
    static let size = CGSize(width: 740, height: 470)
    static let columns = 44
    static let rows = 27
    private static let inset: CGFloat = 30

    /// 0…1: the outline draws on, then the dots come up.
    var appear: Double
    /// 0…1: how far the screen has come alive. The outline turns blue and the cursor lights.
    var live: Double
    /// Cursor, 0…1 from the top-left.
    var cursor: CGPoint
    /// Where the cursor has just been; age runs 0 (now) to 1 (gone).
    var trail: [(point: CGPoint, age: Double)] = []
    /// Taps spreading from where they landed; progress 0…1.
    var rings: [(point: CGPoint, progress: Double)] = []
    /// A word by the cursor saying what just happened; progress 0…1 over its life.
    var tag: (text: String, progress: Double)?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        ZStack {
            shape.fill(Look.panel).opacity(span(appear, from: 0.2, over: 0.5))
            shape.trim(from: 0, to: glide(span(appear, from: 0, over: 0.75)))
                .stroke(Look.hairline, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            shape.stroke(Look.key, lineWidth: 3).opacity(live)
            Canvas { context, size in draw(&context, size) }
                .padding(Self.inset)
                .opacity(span(appear, from: 0.5, over: 0.5))
            if let tag { tagView(tag) }
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private func draw(_ context: inout GraphicsContext, _ size: CGSize) {
        let cols = Double(Self.columns), rows = Double(Self.rows)
        let cellW = size.width / cols, cellH = size.height / rows
        let cu = cursor.x * cols - 0.5, cv = cursor.y * rows - 0.5
        var unlit = Path()
        for j in 0..<Self.rows {
            for i in 0..<Self.columns {
                let x = Double(i), y = Double(j)
                var glow = 0.0
                if live > 0 {
                    let d2 = (x - cu) * (x - cu) + (y - cv) * (y - cv)
                    glow = live * exp(-d2 / 3.1)
                    for mark in trail where mark.age < 1 {
                        let px = mark.point.x * cols - 0.5, py = mark.point.y * rows - 0.5
                        let t2 = (x - px) * (x - px) + (y - py) * (y - py)
                        if t2 < 9 { glow = max(glow, 0.6 * (1 - mark.age) * exp(-t2 / 1.6)) }
                    }
                }
                for ring in rings where ring.progress < 1 {
                    let radius = 1.2 + 8.5 * (1 - pow(1 - ring.progress, 3))
                    let rx = ring.point.x * cols - 0.5, ry = ring.point.y * rows - 0.5
                    let dist = ((x - rx) * (x - rx) + (y - ry) * (y - ry)).squareRoot()
                    glow = max(glow, (1 - ring.progress) * exp(-(dist - radius) * (dist - radius) / 1.1))
                }
                let centre = CGPoint(x: (x + 0.5) * cellW, y: (y + 0.5) * cellH)
                if glow > 0.03 {
                    let r = 2.9 + 3.6 * glow
                    context.fill(circle(centre, r), with: .color(Look.dotOff))
                    context.fill(circle(centre, r), with: .color(Look.key.opacity(min(1, glow * 1.25))))
                } else {
                    unlit.addEllipse(in: CGRect(x: centre.x - 2.9, y: centre.y - 2.9, width: 5.8, height: 5.8))
                }
            }
        }
        context.fill(unlit, with: .color(Look.dotOff))
    }

    private func circle(_ c: CGPoint, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    /// A small outlined word that lifts off the cursor and fades.
    private func tagView(_ tag: (text: String, progress: Double)) -> some View {
        let inner = CGSize(width: Self.size.width - Self.inset * 2, height: Self.size.height - Self.inset * 2)
        let x = Self.inset + cursor.x * inner.width
        let y = Self.inset + cursor.y * inner.height
        let arrive = settle(span(tag.progress, from: 0, over: 0.22))
        let leave = span(tag.progress, from: 0.72, over: 0.28)
        // Sit above the cursor, or below it when there is no room above.
        let above = y > 110
        return Text(tag.text)
            .font(Look.label)
            .foregroundStyle(Look.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Capsule().fill(Look.wall))
            .overlay(Capsule().strokeBorder(Look.key, lineWidth: 2.5))
            .fixedSize()
            .position(x: min(max(x, 130), Self.size.width - 130), y: y + (above ? -66 : 66) - (above ? 1 : -1) * arrive * 8)
            .opacity(arrive * (1 - leave))
    }
}

/// The left-hand text of a chapter: a headline, a sentence or two under it, and an optional small note.
struct ChapterText: View {
    let t: Double
    let cue: Cue
    var headline: [String]
    var bodyText: String?
    var headlineSize: CGFloat = 72
    var width: CGFloat = 800

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(headline.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(Look.headline(headlineSize))
                    .tracking(-headlineSize * 0.012)
                    .foregroundStyle(Look.ink)
                    .fixedSize()
                    .reveal(t, cue, delay: Double(index) * 0.09)
            }
            if let bodyText {
                Text(bodyText)
                    .font(Look.sub)
                    .foregroundStyle(Look.soft)
                    .lineSpacing(9)
                    .frame(width: width, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 26)
                    .lift(t, cue, delay: 0.22 + Double(headline.count) * 0.09)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, Look.margin)
        .padding(.top, 142)
    }
}

extension View {
    /// A short rise and fade, for sentences: quieter than the headline's reveal.
    func lift(_ t: Double, _ cue: Cue, delay: Double = 0) -> some View {
        let shifted = Cue(start: cue.start + delay, end: cue.end)
        let a = shifted.arrive(t, over: 0.6)
        return self.offset(y: (1 - a) * 16).opacity(span(t, from: shifted.start, over: 0.35) * (1 - shifted.leave(t)))
    }
}
