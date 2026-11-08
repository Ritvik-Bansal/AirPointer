import Foundation
import Testing
@testable import PointerKit

/// A hand holding the case, driving a real engine. A held hand trembles a little, which is
/// how the engine tells it from a case lying on a table.
struct Hand {
    var engine: PointerEngine
    var rig = Rig(mount: Rig.mounts[1])
    var events: [PointerEvent] = []
    private var tick = 0

    init(_ prefs: PointerPreferences = PointerPreferences()) {
        engine = makeEngine(prefs)
        hold(1.0)
        events.removeAll()
    }

    private mutating func feed(rate: Double, about axis: Vec3, jolt: Vec3 = .zero) {
        tick += 1
        events += engine.ingest(rig.step(rate: rate, about: axis, jolt: jolt)).events
    }

    /// Holds still for a while: about 1 deg/s of tremor, as measured on a steady hand.
    mutating func hold(_ seconds: Double) {
        for _ in 0..<Int((seconds / 0.02).rounded()) {
            feed(rate: 0.03 * sin(Double(tick) * 0.9), about: tick % 2 == 0 ? Rig.right : Rig.up)
        }
    }

    /// One finger tap: a single-sample jolt on an otherwise steady hand.
    mutating func tap() {
        feed(rate: 0.03 * sin(Double(tick) * 0.9), about: Rig.right, jolt: Vec3(0.4, 0.45, 0.45))
    }

    /// Turns steadily, as when aiming or handling. `rate` in deg/s.
    mutating func turn(_ rate: Double, for seconds: Double, knockAt: Double? = nil) {
        let count = Int((seconds / 0.02).rounded())
        for i in 0..<count {
            let knock = knockAt.map { Int(($0 / 0.02).rounded()) == i } ?? false
            feed(rate: rate.radians, about: Rig.up, jolt: knock ? Vec3(0.5, 0.5, 0.4) : .zero)
        }
    }

    /// Lies on a table: no motion at all.
    mutating func rest(_ seconds: Double, knockAt: Double? = nil) {
        let count = Int((seconds / 0.02).rounded())
        for i in 0..<count {
            let knock = knockAt.map { Int(($0 / 0.02).rounded()) == i } ?? false
            feed(rate: 0, about: Rig.up, jolt: knock ? Vec3(0.5, 0.5, 0.4) : .zero)
        }
    }

    /// Loses `seconds` of the stream, as when packets drop or the AirPods sleep.
    mutating func lose(_ seconds: Double) {
        for _ in 0..<Int((seconds / 0.02).rounded()) { _ = rig.step() }
    }

    var clicks: [PointerEvent] { events.filter { if case .tap = $0 { false } else { true } } }
}

@Suite("Telling taps from knocks")
struct KnockTests {
    @Test("Two taps on a steady hand click")
    func steadyDoubleTap() {
        var hand = Hand()
        hand.tap()
        hand.hold(0.26)
        hand.tap()
        hand.hold(0.6)
        #expect(hand.clicks == [.click(.left, count: 1)])
    }

    @Test("One tap on a steady hand is a right-click, after the window")
    func steadySingleTap() {
        var hand = Hand()
        hand.tap()
        hand.hold(0.3)
        #expect(hand.clicks.isEmpty)
        hand.hold(0.3)
        #expect(hand.clicks == [.click(.right, count: 1)])
    }

    @Test("A knock while the case is being moved is not a tap", arguments: [60.0, 150.0, 600.0])
    func knockWhileMoving(speed: Double) {
        var hand = Hand()
        hand.turn(speed, for: 0.8, knockAt: 0.5)
        hand.hold(1.0)
        #expect(hand.clicks.isEmpty)
        // The knock itself, and at speed the lurch of starting and stopping, are all refused.
        #expect(hand.engine.telemetry.knocksIgnored >= 1)
    }

    @Test("A knock just as the hand stops is not a tap either")
    func knockOnStopping() {
        var hand = Hand()
        hand.turn(120, for: 0.5)
        hand.hold(0.1)   // stopped a tenth of a second ago
        hand.tap()
        hand.hold(1.0)
        #expect(hand.clicks.isEmpty)
    }

    @Test("A bump while the case lies on the table is not a tap")
    func bumpOnTable() {
        var hand = Hand()
        hand.rest(2.0, knockAt: 1.2)
        hand.rest(1.0)
        #expect(hand.clicks.isEmpty)
        #expect(hand.engine.telemetry.knocksIgnored == 1)
    }

    @Test("Putting the case down does not right-click")
    func puttingDown() {
        var hand = Hand()
        hand.turn(8, for: 0.6)   // lowering it gently
        hand.tap()               // it touches the table
        hand.rest(1.0)           // and lies there
        #expect(hand.clicks.isEmpty)
    }

    @Test("A tap followed by the hand swinging away is called off")
    func wanderingOff() {
        var hand = Hand()
        hand.tap()
        hand.turn(90, for: 0.3)  // 27 degrees: this is handling, not waiting for a second tap
        hand.hold(0.6)
        #expect(hand.clicks.isEmpty)
    }

    @Test("Two taps exactly one window apart are still a pair")
    func windowIsExact() {
        var prefs = PointerPreferences()
        prefs.tapWindow = 0.4
        var hand = Hand(prefs)
        hand.tap()
        hand.hold(0.38)   // nineteen samples, then the second tap on the twentieth: 0.40 s apart
        hand.tap()
        hand.hold(0.6)
        #expect(hand.clicks == [.click(.left, count: 1)])
    }

    @Test("Turning taps off mid-gesture leaves no click waiting")
    func tapsOffMidGesture() {
        var hand = Hand()
        hand.tap()
        hand.hold(0.1)
        hand.engine.settings.tapsEnabled = false
        hand.hold(1.0)
        hand.engine.settings.tapsEnabled = true
        hand.hold(1.0)
        #expect(hand.clicks.isEmpty)
    }

    @Test("Turning taps off during a drag lets go of the button")
    func tapsOffMidDrag() {
        var prefs = PointerPreferences()
        prefs.thirdTap = .dragLock
        var hand = Hand(prefs)
        hand.tap(); hand.hold(0.26); hand.tap(); hand.hold(0.26); hand.tap()
        hand.hold(0.5)
        #expect(hand.clicks == [.click(.left, count: 1), .buttonDown(.left)])
        hand.engine.settings.tapsEnabled = false
        hand.hold(0.1)
        #expect(hand.clicks.last == .buttonUp(.left))
    }

    @Test("A tap made while the pointer was off counts for nothing once it is on")
    func staleGestureOnEnable() {
        var hand = Hand()
        hand.tap()
        hand.hold(0.1)
        hand.events += hand.engine.cancelGestures()
        hand.hold(1.0)
        #expect(hand.clicks.isEmpty)
    }

    @Test("If the AirPods drop out mid-gesture, the gesture is dropped too")
    func dropoutMidGesture() {
        var hand = Hand()
        hand.tap()
        hand.hold(0.1)
        hand.lose(2.0)
        hand.hold(1.5)
        #expect(hand.clicks.isEmpty)
    }

    @Test("A few lost samples do not stop taps working")
    func tapsAfterShortHole() {
        var hand = Hand()
        hand.hold(0.5)
        hand.lose(0.12)
        hand.hold(0.5)
        hand.tap(); hand.hold(0.26); hand.tap()
        hand.hold(0.6)
        #expect(hand.clicks == [.click(.left, count: 1)])
    }
}

