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

