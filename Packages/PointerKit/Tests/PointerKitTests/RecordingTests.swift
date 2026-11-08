import Foundation
import Testing
@testable import PointerKit

/// The engine against recordings of the user's own hand. These are the numbers the app was
/// tuned to, so a change that breaks one of them changes how the pointer feels.
@Suite("Recorded sessions: case held in the hand")
struct CaseGripTests {
    let trace = Fixture.caseGrip

    private func run(_ phase: String, _ prefs: PointerPreferences = PointerPreferences()) -> ReplayResult {
        var engine = makeEngine(prefs)
        return engine.replay(trace.samples(inPhase: phase))
    }

    @Test("The recording is present")
    func loaded() {
        #expect(trace.samples.count > 3000)
        #expect(trace.phases.map(\.name).contains("case_tap1"))
    }

    @Test("Every single tap on the case is found: ten taps, ten right-clicks")
    func singleTaps() {
        let r = run("case_tap1")
        #expect(r.taps.count == 10)
        // The tenth tap lands in the last half second; its window has not closed when the recording ends.
        #expect(r.clicks(.right) == 9)
        #expect(r.clicks(.left) == 0)
    }

    @Test("Every double-tap is one click: six pairs, six clicks, no stray right-clicks")
    func doubleTaps() {
        let r = run("case_tap2")
        #expect(r.taps.count == 12)
        #expect(r.clicks(.left) == 6)
        #expect(r.clicks(.right) == 0)
        for item in r.events {
            if case .click(_, let count) = item.event { #expect(count == 1) }
        }
    }

    @Test("The whole session, handling included, clicks only where it was tapped")
    func wholeSession() {
        // Every other test here replays one labelled stretch on a fresh engine. This one
        // runs the recording end to end, the way the app does, so it also covers picking the
        // case up, re-gripping it between steps, and putting it away.
        var engine = makeEngine()
        let r = engine.replay(trace.samples)

        func phase(_ sample: Int) -> String? { trace.phases.first { $0.range.contains(sample) }?.name }
        let singles = trace.phases.first { $0.name == "case_tap1" }!.range
        var left = 0, right = 0, stray: [String] = []
        for (item, sample) in zip(r.events, r.eventSamples) {
            switch item.event {
            case .click(.left, 1) where phase(sample) == "case_tap2":
                left += 1
            case .click(.right, 1) where phase(sample) == "case_tap1":
                right += 1
            case .click(.right, 1) where sample >= singles.upperBound && sample < singles.upperBound + 30:
                // The tenth tap lands in the phase's last half second and resolves just after it.
                right += 1
            default:
                stray.append("\(item.event) in \(phase(sample) ?? "handling") at sample \(sample)")
            }
        }
        #expect(left == 6)
        #expect(right == 10)
        #expect(stray.isEmpty, "clicks nobody made: \(stray)")
        // The knocks of picking it up and putting it away were seen, and refused.
        // Twelve of them. The film states the three counts above and this one (Video/Sources/film,
        // `Figures`), so a change here is a change to make there.
        #expect(r.knocksIgnored == 12)
    }

    @Test("Moving the case never clicks", arguments: ["case_still", "case_lr", "case_ud", "case_move", "lid_closed", "lid_reopen"])
    func noFalseTaps(phase: String) {
        let r = run(phase)
        #expect(r.taps.isEmpty)
        #expect(r.events.isEmpty)
    }

    @Test("No false clicks at a more sensitive setting either")
    func headroom() {
        var prefs = PointerPreferences()
        prefs.tapSensitivity = 0.6
        for phase in ["case_lr", "case_ud", "case_move"] {
            #expect(run(phase, prefs).taps.isEmpty, "false tap in \(phase)")
        }
    }

    @Test("Aiming left and right moves the cursor left and right, starting to the right")
    func leftRight() {
        let r = run("case_lr")
        #expect(r.extent.x > 5 * r.extent.y)
        let firstMove = r.path.first { abs($0.x) > 200 }
        #expect((firstMove?.x ?? 0) > 0)
    }

    @Test("Tilting up and down moves the cursor up and down, starting upward")
    func upDown() {
        let r = run("case_ud")
        #expect(r.extent.y > 3 * r.extent.x)
        // The hand was already tilting when the recording began, so most of the first rise
        // falls inside the stream's settling time; what is left of it must still go up.
        let firstMove = r.path.first { abs($0.y) > 30 }
        #expect((firstMove?.y ?? 0) < 0)
    }

    @Test("The cursor stays where it was aimed through a run of taps")
    func steadyThroughTaps() {
        // Ten taps over ten seconds; each one knocks the case by several degrees.
        let single = run("case_tap1")
        #expect(single.extent.x < 60 && single.extent.y < 90)
        let double = run("case_tap2")
        #expect(double.extent.x < 60 && double.extent.y < 100)
    }

    @Test("Without tap compensation the same taps throw the cursor far further")
    func compensationMatters() {
        var prefs = PointerPreferences()
        prefs.tapsEnabled = false
        let raw = run("case_tap1", prefs)
        let held = run("case_tap1")
        #expect(raw.travel > 2 * held.travel)
    }

    @Test("A held-still hand drifts the cursor only slowly")
    func holdStill() {
        // Recorded with nothing on screen to correct against, so the hand wanders a few
        // degrees over the six seconds. The cursor should creep, never dart.
        let r = run("case_still")
        #expect(r.extent.x < 80 && r.extent.y < 40)
        #expect(r.peakSpeed < 900)
    }
}

@Suite("Recorded sessions: one AirPod held loose")
struct LooseAirPodTests {
    let trace = Fixture.looseAirPod

    /// This grip was never the default, so learn it the way the app would: from a tilt up.
    private var calibration: GripCalibration {
        var c = GripCalibration()
        // Principal tilt axis of the up/down phase, as measured offline.
        c.set(Vec3(0.175, -0.153, 0.973), for: .right)
        return c
    }

    private func run(_ phase: String) -> ReplayResult {
        var engine = makeEngine(calibration: calibration)
        return engine.replay(trace.samples(inPhase: phase))
    }

    // In this recording the AirPod was pinched between two fingers and the hand was often
    // still moving when a tap landed. A tap only counts once the hand has stopped, so some
    // of these are refused on purpose: the same rule that refuses the knocks of handling.

    @Test("Single taps on the AirPod are right-clicks, and never anything else")
    func singleTaps() {
        let r = run("free_tap1")
        #expect((8...10).contains(r.clicks(.right)))
        #expect(r.clicks(.left) == 0)
    }

    @Test("Double-taps on the AirPod click when the hand had stopped first")
    func doubleTaps() {
        let r = run("free_tap2")
        // Four of the six pairs. The first two came with the hand turning at 39 and 60 deg/s.
        #expect(r.clicks(.left) == 4)
        #expect(r.clicks(.right) == 0)
    }

    @Test("The whole session: no click of the wrong kind, and handling is refused")
    func wholeSession() {
        var engine = makeEngine(calibration: calibration)
        let r = engine.replay(trace.samples)
        func phase(_ sample: Int) -> String? { trace.phases.first { $0.range.contains(sample) }?.name }

        var leftInPairs = 0, rightInSingles = 0, loneKnocks = 0, wrong: [String] = []
        for (item, sample) in zip(r.events, r.eventSamples) {
            switch (item.event, phase(sample)) {
            case (.click(.left, 1), "free_tap2"): leftInPairs += 1
            case (.click(.right, 1), "free_tap1"): rightInSingles += 1
            case (.click(.right, 1), nil): loneKnocks += 1
            default: wrong.append("\(item.event) in \(phase(sample) ?? "handling")")
            }
        }
        #expect(leftInPairs == 4)
        #expect((8...10).contains(rightInSingles))
        #expect(wrong.isEmpty, "\(wrong)")
        // A single knock with the hand at rest is, to the sensors, a tap. Three such
        // right-clicks remain in three minutes of handling (one may be the tenth single tap
        // resolving after its phase); forty-odd other knocks are refused.
        #expect(loneKnocks <= 3)
        #expect(r.knocksIgnored >= 30)
    }

    @Test("Moving it never clicks", arguments: ["free_still", "free_lr", "free_ud", "free_move"])
    func noFalseTaps(phase: String) {
        #expect(run(phase).taps.isEmpty)
    }

    @Test("Axes hold for a different grip once calibrated")
    func axes() {
        let lr = run("free_lr")
        #expect(lr.extent.x > 5 * lr.extent.y)
        #expect((lr.path.first { abs($0.x) > 100 }?.x ?? 0) > 0)
        let ud = run("free_ud")
        #expect(ud.extent.y > 3 * ud.extent.x)
        #expect((ud.path.first { abs($0.y) > 200 }?.y ?? 0) < 0)
    }

    @Test("A held-still AirPod keeps the cursor within a few points")
    func holdStill() {
        let r = run("free_still")
        #expect(r.extent.x < 15 && r.extent.y < 15)
    }
}

