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

}

