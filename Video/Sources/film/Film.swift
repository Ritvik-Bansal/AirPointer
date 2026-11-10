import AppKit
import PointerKit
import SwiftUI

// DIRECTION CONTRACT
//
// THESIS: One room, one object. Whenever the film is drawing, the case is on screen: it
// moves from place to place and is never dissolved or cut away from, and everything said
// about it is said beside it. It gives way only to the filmed clips, which arrive over it.
// It refuses the montage of screen recordings and the kinetic-type advert.
// OWN-WORLD: The app's night palette, flat: a wall and a floor in two tones, white type,
// one sky-blue. No gradients, glows or shadows; the only shading is light on the case.
// SF Rounded for headlines, plain SF for sentences. Anything measured is shown on a
// dot-matrix display: the Mac's screen, the signal, the count of taps.
// STORY: I see what it is. Then what it does, each claim followed by a clip that proves it
// (aim, then a clip of aiming; tap, then a clip of a click). Then how it can possibly work
// (the sensors, gravity, a jolt), that it was tested, and how to start.
// FIRST VIEWPORT: 1920x1080. The first frame is the title card, complete, because the first
// frame is what a player shows before anyone presses play: the name and one sentence
// top-left at a 150 px margin, the case shut, right of centre. The first thing to move is the lid.
// The last frame is the end card, held, for the same reason.
// FORM: a new surface inside the app's established world (DESIGN.md). The order of the
// chapters was chosen by the builder without a roll or a decision round: the user was away
// by their own instruction and had pinned the brief (minimal, no gradients, informative,
// not childish). The order is theirs to change; it is one enum below.
// FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review,
// the verdict, DESIGN.md, and every shipping raster carrying its provenance.

/// The film, as one timeline. `frame(at:)` draws any moment of it.
///
/// The room and the case are continuous: they move and change, but are never cut between.
/// Text arrives and leaves by chapter. Two stretches are given over to filmed clips.
@MainActor
final class Film {
    nonisolated static let fps = 60

    /// When each chapter starts, in seconds.
    enum At {
        static let open = 0.0
        static let aim = 4.4
        static let clipA = 11.8
        static let tap = 18.3
        static let clipB = 25.9
        static let sensors = 32.4
        static let gravity = 39.2
        static let jolt = 47.6
        static let proof = 57.2
        static let setup = 63.2
        static let end = 69.7
        static let finish = 75.9
    }

    static let slots = [
        Footage.Slot(
            name: "A", start: At.clipA, duration: At.tap - At.clipA,
            title: "Over the shoulder",
            brief: "Your hand, the case and the Mac's screen in one shot, steering the cursor."
        ),
        Footage.Slot(
            name: "B", start: At.clipB, duration: At.sensors - At.clipB,
            title: "A real click",
            brief: "Closer on the screen: aim at something, tap twice, and it opens."
        ),
    ]

    private typealias Pose = CaseRenderer.Pose

    private let caseRenderer = CaseRenderer()
    private let footage: Footage
    /// Pixels per point of the frame being drawn: 1 for 1080p, 2 for 4K. The case and the
    /// clips are rendered at this, so a larger film is sharper and not merely bigger.
    private let detail: Double
    private let repository: String
    private let trace: MotionTrace

    // The recorded takes, and when each plays.
    private let turn: Take
    private let tilt: Take
    private let pairs: Take
    private let single: Take
    private let strip: Take
    private let turnStart = At.aim + 1.2
    private let tiltStart: Double
    private let aimEnd: Double
    private let pairsStart = At.tap + 1.0
    private let singleStart: Double
    private let stripStart = At.jolt + 1.9
    /// Where the cursor sits before anything has moved it.
    private let origin: CGPoint

    init(project: URL, repository: String, footage folder: URL? = nil, detail: Double = 1) throws {
        let fixture = project.appendingPathComponent("Packages/PointerKit/Tests/PointerKitTests/Fixtures/case-grip.trace")
        trace = MotionTrace.parse(try String(contentsOf: fixture, encoding: .utf8))
        guard let sweep = trace.start(of: "case_lr"), let nod = trace.start(of: "case_ud"),
              let doubles = trace.start(of: "case_tap2"), let singles = trace.start(of: "case_tap1")
        else { throw Failure("The recording is missing one of the stretches the film is cut from.") }

        // Left and right, then up and down: the two stretches recorded for exactly that. The
        // pointer speed is turned down, because they were made with nothing on screen to aim
        // at and sweep wide.
        turn = Take.cut(from: trace, start: sweep + 0.6, duration: 3.1, speed: 0.3, bounded: false)
        tilt = Take.cut(from: trace, start: nod + 1.0, duration: 2.3, speed: 0.3, bounded: false)
        // Two double-taps, then one tap on its own.
        pairs = Take.cut(from: trace, start: doubles + 0.9, duration: 3.2)
        single = Take.cut(from: trace, start: singles + 3.3, duration: 1.0)
        // One double-tap, a quiet hand, then the case being shifted in the grip: one unbroken stretch.
        strip = Take.cut(from: trace, start: doubles + 8.5, duration: 5.5)

        tiltStart = turnStart + turn.length + 0.4
        aimEnd = tiltStart + tilt.length
        singleStart = pairsStart + pairs.length + 0.5

        // Start the cursor where the two sweeps to come will be centred on the screen.
        func travel(_ take: Take, _ axis: KeyPath<CGPoint, CGFloat>) -> [CGFloat] {
            let first = take.frames.first?.cursor ?? .zero
            return take.frames.map { $0.cursor[keyPath: axis] - first[keyPath: axis] }
        }
        let across = travel(turn, \.x), down = travel(tilt, \.y)
        let drift = travel(turn, \.y).last ?? 0
        origin = CGPoint(
            x: 0.5 - ((across.min() ?? 0) + (across.max() ?? 0)) / 2,
            y: 0.5 - drift - ((down.min() ?? 0) + (down.max() ?? 0)) / 2
        )

        footage = Footage(folder: folder ?? project.appendingPathComponent("Video/footage"), detail: detail)
        self.repository = repository
        self.detail = detail
    }

    /// A stretch of the recording, described five times a second: pose, cursor and what was tapped.
    func probe(phase: String, offset: Double, duration: Double, speed: Double) throws -> [String] {
        guard let start = trace.start(of: phase) else { throw Failure("The recording has no phase called \(phase).") }
        let take = Take.cut(from: trace, start: start + offset, duration: duration, speed: speed)
        var lines = ["   t     yaw  pitch   roll   cursor"]
        for i in stride(from: 0, to: take.frames.count, by: Self.fps / 5) {
            let f = take.frames[i], t = Double(i) / Double(Self.fps)
            let marks = take.marks.filter { $0.time >= t && $0.time < t + 0.2 }.map { "\($0.mark)" }.joined(separator: " ")
            let near = take.readings.filter { $0.time >= t && $0.time < t + 0.2 }
            let level = near.map(\.level).max() ?? 0, unrest = near.map(\.unrest).max() ?? 0
            lines.append(String(format: "%5.1f  %5.0f  %5.0f  %5.0f   %.2f, %.2f   jolt %.1f  unrest %4.1f  %@", t, f.yaw, f.pitch, f.roll, f.cursor.x, f.cursor.y, level, unrest, marks))
        }
        return lines
    }

    /// The slots still showing a card because no clip has been filmed for them.
    var waiting: [Footage.Slot] {
        Self.slots.filter { footage.clip(for: $0.name) == nil }
    }

    /// What the film sounds like, going by what is in the footage folder.
    var sound: Sound.Plan {
        var plan = Sound.Plan(music: footage.music)
        for slot in Self.slots {
            let cut = footage.cut(for: slot.name)
            guard cut.sound, let clip = footage.clip(for: slot.name) else { continue }
            plan.pieces.append(Sound.Piece(clip: clip, from: cut.start, start: slot.start, duration: slot.duration))
        }
        return plan
    }

    // MARK: The frame

    func frame(at t: Double) -> some View {
        let slot = Self.slots.first { t >= $0.start && t < $0.start + $0.duration }
        return ZStack {
            Room()
            stage(t)
            text(t)
            extras(t)
            if let slot {
                FootageView(slot: slot, image: footage.image(slot, at: t - slot.start, fps: Self.fps), local: t - slot.start)
            }
        }
        .frame(width: Look.size.width, height: Look.size.height)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Where the case is

    private struct Placement {
        var centre: CGPoint
        var scale: Double
    }

    /// Large, right of centre: the opening, the chapters about the case itself, and the end.
    private let hero = Placement(centre: CGPoint(x: 1335, y: 630), scale: 1.0)
    /// Under the dot screen, in the hand, while it is aimed and tapped.
    private let under = Placement(centre: CGPoint(x: 1390, y: 839), scale: 0.55)
    /// Small and out of the way, above the signal it is producing.
    private let aside = Placement(centre: CGPoint(x: 1545, y: 322), scale: 0.5)
    /// Beside the results, midway between the last of them and the margin.
    private let beside = Placement(centre: CGPoint(x: 1520, y: 600), scale: 0.5)
    private let baseSize = CGSize(width: 1000, height: 780)
    private let screenCentre = CGPoint(x: 1390, y: 335)

    /// The case travels between its places; it is never faded. The one move nobody sees
    /// happens behind the second clip.
    private func placement(_ t: Double) -> Placement {
        let moves: [(start: Double, over: Double, to: Placement)] = [
            (At.aim - 0.3, 1.0, under),
            (At.clipB + 3.0, 0.02, hero),
            (At.jolt - 0.1, 1.0, aside),
            (At.proof - 0.1, 1.0, beside),
            (At.setup - 0.1, 1.0, hero),
        ]
        var place = hero
        for move in moves {
            let p = glide(span(t, from: move.start, over: move.over))
            place = Placement(
                centre: CGPoint(x: mix(place.centre.x, move.to.centre.x, p), y: mix(place.centre.y, move.to.centre.y, p)),
                scale: mix(place.scale, move.to.scale, p)
            )
        }
        return place
    }

    // MARK: How the case is held

    private let rest = Pose(yaw: -14, pitch: 9)

    private func posed(_ frame: Take.Frame?) -> Pose {
        guard let frame else { return Pose() }
        return Pose(yaw: frame.yaw, pitch: frame.pitch, roll: frame.roll)
    }

    private func blend(_ a: Pose, _ b: Pose, _ x: Double) -> Pose {
        Pose(yaw: mix(a.yaw, b.yaw, x), pitch: mix(a.pitch, b.pitch, x), roll: mix(a.roll, b.roll, x), lid: mix(a.lid, b.lid, x))
    }

    private func pose(_ t: Double) -> Pose {
        switch t {
        case ..<turnStart:
            // Shut on the first frame. The lid lifts, and the case turns slowly to face the viewer.
            return Pose(yaw: mix(-18, 4, glide(span(t, from: 0, over: turnStart))), pitch: 9, lid: glide(span(t, from: 0.6, over: 1.2)))

        case ..<At.clipA:
            // Turned left and right, then tilted up and down, as it was recorded.
            let turnEnd = turnStart + turn.length
            if t < turnEnd {
                return blend(Pose(yaw: 4, pitch: 9), posed(turn.frame(at: t - turnStart)), glide(span(t, from: turnStart, over: 0.5)))
            }
            if t < tiltStart {
                return blend(posed(turn.frames.last), posed(tilt.frames.first), glide(span(t, from: turnEnd, over: tiltStart - turnEnd)))
            }
            if t < aimEnd { return posed(tilt.frame(at: t - tiltStart)) }
            return blend(posed(tilt.frames.last), posed(pairs.frames.first), glide(span(t, from: aimEnd, over: At.clipA - aimEnd)))

        case ..<pairsStart:
            return posed(pairs.frames.first)

        case ..<(At.clipB + 3):
            // Tapped twice, twice over, then once.
            let pairsEnd = pairsStart + pairs.length
            var p: Pose
            if t < pairsEnd {
                p = posed(pairs.frame(at: t - pairsStart))
            } else if t < singleStart {
                p = blend(posed(pairs.frames.last), posed(single.frames.first), glide(span(t, from: pairsEnd, over: singleStart - pairsEnd)))
            } else {
                p = posed(single.frame(at: t - singleStart))
            }
            p.ring = ring(single, t - singleStart) ?? ring(pairs, t - pairsStart)
            return p

        case ..<At.gravity:
            // Held nearly still while the labels point at it.
            return Pose(yaw: mix(-20, -12, glide(span(t, from: At.sensors, over: At.gravity - At.sensors))), pitch: 10)

        case ..<At.jolt:
            return demonstrating(t - At.gravity)

        case ..<At.proof:
            // Turning back to face the viewer as it moves aside, then replaying the stretch the display shows.
            if t < stripStart {
                return blend(demonstrating(At.jolt - At.gravity), posed(strip.frames.first), glide(span(t, from: At.jolt - 0.1, over: 1.1)))
            }
            var p = posed(strip.frame(at: t - stripStart))
            p.ring = ring(strip, t - stripStart)
            return p

        case ..<At.setup:
            // The lid shuts where the case is, as the results leave, so that it is not also
            // travelling while it does; the steps that follow begin from a shut case.
            var p = blend(posed(strip.frames.last), rest, glide(span(t, from: At.proof - 0.1, over: 1.0)))
            p.lid = 1 - glide(span(t, from: At.setup - 1.0, over: 0.85))
            return p

        case ..<At.end:
            // Shut, to begin from the beginning; opened on the second step; pointed on the third.
            let s = t - At.setup
            var p = rest
            p.lid = glide(span(s, from: 2.3, over: 1.1))
            let pointing = glide(span(s, from: 3.8, over: 0.4)) * (1 - glide(span(s, from: 5.2, over: 0.4)))
            p.yaw += 15 * pointing * sin(2 * .pi * (s - 3.8) / 1.8)
            return p

        default:
            var p = rest
            p.yaw = mix(rest.yaw, -6, glide(span(t, from: At.end, over: At.finish - At.end)))
            return p
        }
    }

    /// The gravity chapter, `g` seconds in: turned left and right about the line of gravity,
    /// then turned side-on to the viewer, so that tilting it up and down happens in the plane
    /// of the picture and can be seen for what it is.
    private func demonstrating(_ g: Double) -> Pose {
        let facing = mix(-12, 0, glide(span(g, from: 0, over: 1.0)))
        let turning = glide(span(g, from: 2.0, over: 0.5)) * (1 - glide(span(g, from: 4.0, over: 0.5)))
        let side = glide(span(g, from: 4.7, over: 0.9))
        let tilting = glide(span(g, from: 5.8, over: 0.5)) * (1 - glide(span(g, from: 7.5, over: 0.5)))
        return Pose(
            yaw: facing + 26 * turning * sin(2 * .pi * (g - 2.0) / 2.5) + 62 * side,
            pitch: 10 + 17 * tilting * sin(2 * .pi * (g - 5.8) / 2.2)
        )
    }

    /// How far the tap ring has spread at `local` seconds into a take, if a tap is still ringing.
    private func ring(_ take: Take, _ local: Double) -> Double? {
        take.marks(.tap).last { local >= $0 && local < $0 + 0.5 }.map { (local - $0) / 0.5 }
    }

    // MARK: The screen

    private struct ScreenState {
        var cursor = CGPoint(x: 0.5, y: 0.5)
        var trail: [(point: CGPoint, age: Double)] = []
        var rings: [(point: CGPoint, progress: Double)] = []
        var tag: (text: String, progress: Double)?
    }

    /// Where the cursor is. Each take carries it on from where the one before left it.
    private func cursor(_ t: Double) -> CGPoint {
        var p = origin
        for (take, start) in [(turn, turnStart), (tilt, tiltStart), (pairs, pairsStart), (single, singleStart)] where t >= start {
            let now = take.frame(at: t - start).cursor, first = take.frames.first?.cursor ?? now
            p.x += now.x - first.x
            p.y += now.y - first.y
        }
        return CGPoint(x: min(max(p.x, 0.03), 0.97), y: min(max(p.y, 0.04), 0.96))
    }

    private func screen(_ t: Double) -> ScreenState {
        var s = ScreenState(cursor: cursor(t))
        if t >= turnStart, t < aimEnd + 0.5 {
            for k in 1...22 {
                let earlier = t - Double(k) / Double(Self.fps)
                if earlier >= turnStart { s.trail.append((cursor(earlier), Double(k) / 23)) }
            }
        }
        for (take, start) in [(pairs, pairsStart), (single, singleStart)] where t >= start {
            let local = t - start
            for tap in take.marks(.tap) where local >= tap && local < tap + 0.6 {
                s.rings.append((s.cursor, (local - tap) / 0.6))
            }
            for mark in take.marks where local >= mark.time && local < mark.time + 1.2 {
                let progress = (local - mark.time) / 1.2
                switch mark.mark {
                case .click: s.tag = ("click", progress)
                case .doubleClick: s.tag = ("double-click", progress)
                case .rightClick: s.tag = ("right-click", progress)
                case .tap, .knock: break
                }
            }
        }
        return s
    }

    @ViewBuilder
    private func stage(_ t: Double) -> some View {
        // The screen stays up from the aiming to the tapping, the first clip included; it is
        // taken down behind the second.
        if t >= At.aim, t < At.clipB + 3 {
            let state = screen(t)
            DotScreen(
                appear: span(t, from: At.aim + 0.2, over: 1.1),
                live: span(t, from: turnStart - 0.5, over: 0.3),
                cursor: state.cursor, trail: state.trail, rings: state.rings, tag: state.tag
            )
            .position(screenCentre)
        }
        let place = placement(t)
        let size = CGSize(width: (baseSize.width * place.scale).rounded(), height: (baseSize.height * place.scale).rounded())
        let pixels = CGSize(width: size.width * detail, height: size.height * detail)
        if let image = caseRenderer.image(pose(t), size: pixels) {
            Image(decorative: image, scale: detail).position(place.centre)
        }
    }

    // MARK: Text

    @ViewBuilder
    private func text(_ t: Double) -> some View {
        switch t {
        case ..<At.aim:
            // There from the first frame: nothing arrives, the lid simply opens beside it.
            ChapterText(t: t, cue: Cue(start: -5, end: At.aim - 0.3), headline: ["AirPointer"],
                        bodyText: "Your AirPods case, as a pointer for the Mac.", headlineSize: 104)
        case ..<At.clipA:
            ChapterText(t: t, cue: Cue(start: At.aim + 0.5, end: At.clipA - 0.15), headline: ["Aim it."],
                        bodyText: "The cursor on the Mac follows the case.")
            note("Real motion, replayed through the app's own engine.", t, Cue(start: turnStart + 0.4, end: At.clipA - 0.15))
        case ..<At.tap:
            EmptyView()
        case ..<At.clipB:
            ChapterText(t: t, cue: Cue(start: At.tap + 0.3, end: At.clipB - 0.15), headline: ["Tap it."],
                        bodyText: "Two taps on the back click.\nOne tap right-clicks.")
        case ..<At.sensors:
            EmptyView()
        case ..<At.gravity:
            ChapterText(t: t, cue: Cue(start: At.sensors + 0.3, end: At.gravity - 0.15), headline: ["The sensors are", "in the AirPods."],
                        bodyText: "Docked, with the lid open, they send their motion fifty times a second.", width: 700)
        case ..<At.jolt:
            ChapterText(t: t, cue: Cue(start: At.gravity + 0.3, end: At.jolt - 0.15), headline: ["Gravity says", "which way is up."],
                        bodyText: "Turn it for left and right.\nTilt it for up and down.")
        case ..<At.proof:
            ChapterText(t: t, cue: Cue(start: At.jolt + 0.3, end: At.proof - 0.15), headline: ["A tap is one reading", "out of line."],
                        bodyText: "A knock from handling the case is refused:\nthe hand has to be still first.", width: 900)
        case ..<At.setup:
            let cue = Cue(start: At.proof + 0.3, end: At.setup - 0.15)
            ChapterText(t: t, cue: cue, headline: ["Tuned on recordings", "of a real hand."])
            note("One recorded session, replayed end to end.", t, Cue(start: At.proof + 1.6, end: At.setup - 0.15))
        case ..<At.end:
            ChapterText(t: t, cue: Cue(start: At.setup + 0.3, end: At.end - 0.15), headline: ["To start"])
        default:
            // The last frame is this card, held: it is what a player is left showing.
            let cue = Cue(start: At.end + 0.3, end: nil)
            ChapterText(t: t, cue: cue, headline: ["AirPointer"], bodyText: nil, headlineSize: 104)
            VStack(alignment: .leading, spacing: 18) {
                Text(repository).font(.system(size: 42, weight: .medium)).foregroundStyle(Look.key).fixedSize()
                Text("Tested with AirPods Pro 3 on macOS 27.").font(Look.small).foregroundStyle(Look.soft).fixedSize()
            }
            .lift(t, cue, delay: 0.35)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, Look.margin)
            .padding(.top, 296)
        }
    }

    /// A small line along the bottom of the frame, for saying how something was made.
    private func note(_ text: String, _ t: Double, _ cue: Cue) -> some View {
        Text(text)
            .font(Look.small)
            .foregroundStyle(Look.soft)
            .fixedSize()
            .lift(t, cue)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, Look.margin)
            .padding(.bottom, 84)
    }

}

extension Take {
    /// How long the take runs, in seconds.
    var length: Double { Double(frames.count) / Double(Film.fps) }
}
