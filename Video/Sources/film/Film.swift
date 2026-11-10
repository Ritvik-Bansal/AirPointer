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

}

extension Take {
    /// How long the take runs, in seconds.
    var length: Double { Double(frames.count) / Double(Film.fps) }
}
