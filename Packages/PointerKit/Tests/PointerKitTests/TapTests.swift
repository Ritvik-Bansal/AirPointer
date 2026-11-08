import Foundation
import Testing
@testable import PointerKit

@Suite("Tap detection")
struct TapDetectorTests {
    /// Feeds a quiet 50 Hz stream with jolts at the given sample indices.
    private func taps(jolts: [Int: Vec3], samples: Int = 150, motion: (Double) -> Vec3 = { _ in .zero }) -> [TapDetector.Tap] {
        var detector = TapDetector()
        var found: [TapDetector.Tap] = []
        for i in 0..<samples {
            let t = 10 + Double(i) * 0.02
            let s = MotionSample(timestamp: t, arrival: t, rotationRate: motion(t), userAcceleration: jolts[i] ?? .zero)
            if let tap = detector.ingest(s) { found.append(tap) }
        }
        return found
    }

    private let jolt = Vec3(0.4, 0.45, 0.45)

    @Test("One sharp jolt is one tap")
    func single() {
        let found = taps(jolts: [60: jolt])
        #expect(found.count == 1)
        #expect(abs((found.first?.time ?? 0) - (10 + 60 * 0.02)) < 0.021)
    }

    @Test("Smooth hand motion is never a tap, even when fast")
    func smoothMotion() {
        // A brisk back-and-forth sweep peaking near 170 deg/s.
        let found = taps(jolts: [:], samples: 400) { t in
            Vec3(0, 0, 3.0 * sin(2 * .pi * 1.2 * t))
        }
        #expect(found.isEmpty)
    }

    @Test("The start-up transient is ignored")
    func startupTransient() {
        #expect(taps(jolts: [1: Vec3(1.3, 0.5, 0)]).isEmpty)
        #expect(taps(jolts: [8: Vec3(1.3, 0.5, 0)]).isEmpty)
    }

    @Test("The rebound after a tap is not a second tap")
    func rebound() {
        // A weaker jolt 120 ms later, as the case springs back.
        #expect(taps(jolts: [60: jolt, 66: jolt * 0.5]).count == 1)
    }

    @Test("Two taps a quarter of a second apart are two taps")
    func double() {
        #expect(taps(jolts: [60: jolt, 73: jolt]).count == 2)
    }

    @Test("The second tap of a pair may land softer than the first")
    func softPartner() {
        let soft = jolt * 0.22
        // On its own the soft jolt is below the bar...
        #expect(taps(jolts: [60: soft]).isEmpty)
        // ...but right after a firm tap it counts.
        #expect(taps(jolts: [60: jolt, 73: soft]).count == 2)
    }

    @Test("A hole in the stream resets the detector instead of faking a jolt")
    func streamGap() {
        var detector = TapDetector()
        var found = 0
        for i in 0..<100 {
            // Two seconds vanish after sample 50, and motion state jumps with them.
            let t = 10 + Double(i) * 0.02 + (i > 50 ? 2 : 0)
            let w = i > 50 ? Vec3(2, 0, 0) : .zero
            if detector.ingest(MotionSample(timestamp: t, arrival: t, rotationRate: w)) != nil { found += 1 }
        }
        #expect(found == 0)
    }

    @Test("Sensitivity moves the threshold the right way")
    func sensitivity() {
        var firm = PointerPreferences(), light = PointerPreferences()
        firm.tapSensitivity = 0
        light.tapSensitivity = 1
        #expect(firm.engineSettings().tap.threshold > PointerPreferences().engineSettings().tap.threshold)
        #expect(light.engineSettings().tap.threshold < PointerPreferences().engineSettings().tap.threshold)
    }
}

