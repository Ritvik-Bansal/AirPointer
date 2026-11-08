import Foundation
import Testing
@testable import PointerKit

@Suite("Rate shaping")
struct RateShaperTests {
    /// Velocity after holding a constant rate long enough for the filter to settle.
    private func settled(yaw: Double, pitch: Double, params: RateShaper.Params = PointerPreferences().engineSettings().shaper) -> Vec2 {
        var shaper = RateShaper(params: params)
        var v = Vec2.zero
        for _ in 0..<200 { v = shaper.shape(yaw: yaw, pitch: pitch, dt: 0.02) }
        return v
    }

    @Test("A resting hand moves nothing")
    func restIsStill() {
        #expect(settled(yaw: 0, pitch: 0) == .zero)
        // Residual gyro bias and breathing sit well under the floor.
        #expect(settled(yaw: 0.1, pitch: -0.08) == .zero)
    }

    @Test("Right is +x and up is -y on screen")
    func directions() {
        let right = settled(yaw: 30, pitch: 0)
        #expect(right.x > 0 && abs(right.y) < 1e-9)
        let up = settled(yaw: 0, pitch: 30)
        #expect(up.y < 0 && abs(up.x) < 1e-9)
    }

    @Test("Left mirrors right exactly")
    func symmetric() {
        let a = settled(yaw: 42, pitch: -17)
        let b = settled(yaw: -42, pitch: 17)
        #expect(abs(a.x + b.x) < 1e-9 && abs(a.y + b.y) < 1e-9)
    }

    @Test("Faster hands always move the cursor faster")
    func monotonic() {
        var last = 0.0
        for speed in stride(from: 0.0, through: 300, by: 0.5) {
            let v = settled(yaw: speed, pitch: 0).x
            #expect(v >= last - 1e-9, "speed fell at \(speed) deg/s")
            last = v
        }
    }

    @Test("Slow motion is finer than fast motion")
    func accelerationCurve() {
        let p = PointerPreferences().engineSettings().shaper
        let slow = settled(yaw: 3, pitch: 0).x / 3
        let fast = settled(yaw: 150, pitch: 0).x / 150
        #expect(abs(slow - p.gainSlow) < 1.5)
        #expect(abs(fast - p.gainFast) < 0.01)
        #expect(fast > 3 * slow)
    }

    @Test("Diagonal motion keeps its direction")
    func keepsDirection() {
        let v = settled(yaw: 40, pitch: 40)
        #expect(abs(v.x + v.y) < 1e-6)
    }

    @Test("Steadier settings damp a trembling hand more")
    func steadiness() {
        func jitter(_ steadiness: Double) -> Double {
            var prefs = PointerPreferences()
            prefs.steadiness = steadiness
            var shaper = RateShaper(params: prefs.engineSettings().shaper)
            var travel = 0.0
            // A 10 Hz tremor of 2 deg/s amplitude: fast enough to be the hand, not the aim.
            for i in 0..<500 {
                let t = Double(i) * 0.02
                let v = shaper.shape(yaw: 2 * sin(2 * .pi * 10 * t), pitch: 0, dt: 0.02)
                travel += abs(v.x) * 0.02
            }
            return travel
        }
        #expect(jitter(1.0) < jitter(0.5))
        #expect(jitter(0.5) < jitter(0.0))
    }

    @Test("Speed and acceleration settings do what they say")
    func preferencesMap() {
        var slow = PointerPreferences(), fast = PointerPreferences()
        slow.speed = 0.5
        fast.speed = 2
        #expect(fast.engineSettings().shaper.gainSlow == 4 * slow.engineSettings().shaper.gainSlow)

        var flat = PointerPreferences()
        flat.acceleration = 0
        let f = flat.engineSettings().shaper
        #expect(abs(f.gainSlow - f.gainFast) < 1e-9)
    }
}

@Suite("Playout")
struct PlayoutTests {
    /// Pushes constant-velocity samples with a repeating bursty arrival pattern, then lets the
    /// hand come to rest, pulling frames at 120 Hz throughout.
    private func run(velocity: Vec2, seconds: Double, arrivalDelays: [Double]) -> (pulled: Vec2, steps: [Vec2]) {
        var playout = Playout()
        var pulled = Vec2.zero
        var steps: [Vec2] = []
        let moving = Int(seconds / 0.02)
        var arrivals: [(arrival: Double, ts: Double, v: Vec2)] = []
        for i in 0..<(moving + 15) {
            let ts = Double(i + 1) * 0.02
            arrivals.append((ts + 0.03 + arrivalDelays[i % arrivalDelays.count], ts, i < moving ? velocity : .zero))
        }
        var next = 0
        var now = 0.0
        while now < seconds + 0.8 {
            while next < arrivals.count, arrivals[next].arrival <= now {
                playout.push(velocity: arrivals[next].v, dt: 0.02, sensorTime: arrivals[next].ts, arrival: arrivals[next].arrival)
                next += 1
            }
            let d = playout.pull(now: now)
            pulled += d
            steps.append(d)
            now += 1.0 / 120
        }
        return (pulled, steps)
    }

    // Shaped like the measured stream: samples arriving in pairs, then a gap of up to 58 ms
    // (the 99th percentile on the real recordings). Delivery stays in order, as Bluetooth does.
    private let bursty = [0.0, 0.019, 0.004, 0.0, 0.038, 0.019, 0.001, 0.0, 0.002, 0.019]

    @Test("No motion is lost or invented, however the samples arrive")
    func conserves() {
        let v = Vec2(900, -350)
        let r = run(velocity: v, seconds: 2, arrivalDelays: bursty)
        #expect((r.pulled - v * 2).length < 1e-6)
    }

    @Test("If the stream dies mid-move, the cursor stops within a few frames of where it was")
    func streamDiesMidMove() {
        var playout = Playout()
        let v = Vec2(1000, 0)
        var pulled = Vec2.zero
        _ = playout.pull(now: 0)
        for i in 1...50 {
            let ts = Double(i) * 0.02
            playout.push(velocity: v, dt: 0.02, sensorTime: ts, arrival: ts + 0.03)
            pulled += playout.pull(now: ts + 0.03)
        }
        for i in 1...240 { pulled += playout.pull(now: 1.03 + Double(i) / 120) }
        // At most `maxLead` of extra travel, and it never keeps going.
        #expect(pulled.x >= 1000 - 1e-6)
        #expect(pulled.x <= 1000 + v.x * playout.maxLead + 1e-6)
    }

    @Test("Steady motion stays steady through delivery gaps")
    func smoothThroughGaps() {
        let v = Vec2(1200, 0)
        let ideal = v.x / 120
        let steps = run(velocity: v, seconds: 2, arrivalDelays: bursty).steps
        // Skip start-up and the tail after the hand stops.
        let mid = steps[60..<220].map(\.x)
        let worst = mid.map { abs($0 - ideal) / ideal }.max() ?? 1
        #expect(worst < 0.25, "frame steps strayed \(Int(worst * 100))% from ideal")
        // Without dead reckoning a 58 ms gap would stall the cursor completely.
        #expect((mid.min() ?? 0) > ideal * 0.75)
    }

    @Test("Rewinding takes back exactly the recent motion")
    func rewind() {
        var p = Playout()
        for i in 1...10 {
            p.push(velocity: Vec2(500, 0), dt: 0.02, sensorTime: Double(i) * 0.02, arrival: Double(i) * 0.02 + 0.03)
        }
        // Drop everything after t = 0.14: samples at 0.16, 0.18, 0.20.
        p.rewind(to: 0.14 + 1e-9)
        _ = p.pull(now: 1.0)
        let settled = p.settle()
        var total = settled
        for i in 0..<120 { total += p.pull(now: 1.0 + Double(i) / 120) }
        #expect(abs(total.x - 7 * 10) < 1e-6)
    }

    @Test("Settling lands the cursor exactly on target and stops it")
    func settle() {
        var p = Playout()
        _ = p.pull(now: 0)
        p.push(velocity: Vec2(1000, 0), dt: 0.02, sensorTime: 0.02, arrival: 0.05)
        _ = p.pull(now: 0.05)
        let d = p.settle()
        #expect(d.x > 0)
        var after = Vec2.zero
        for i in 1...30 { after += p.pull(now: 0.05 + Double(i) / 120) }
        #expect(after.length < 1e-9)
    }
}
