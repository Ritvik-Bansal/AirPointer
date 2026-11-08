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

