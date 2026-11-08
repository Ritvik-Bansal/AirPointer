import Foundation
import simd
import Testing
@testable import PointerKit

@Suite("Axis mapping")
struct AxisMapperTests {
    @Test("Turning right reads as positive yaw, however the earbud is mounted", arguments: Rig.mounts)
    func yaw(mount: simd_quatd) {
        var rig = Rig(mount: mount)
        var mapper = AxisMapper(forward: rig.forwardInDevice)
        // Clockwise seen from above is a negative rotation about up.
        let s = rig.step(rate: -1.0, about: Rig.up)
        let r = mapper.map(rotationRate: s.rotationRate, gravity: s.gravity)
        #expect(abs(r.yaw - 1.0) < 1e-6)
        #expect(abs(r.pitch) < 0.02)
        #expect(abs(r.roll) < 0.02)
    }

    @Test("Tilting up reads as positive pitch", arguments: Rig.mounts)
    func pitch(mount: simd_quatd) {
        var rig = Rig(mount: mount)
        var mapper = AxisMapper(forward: rig.forwardInDevice)
        let s = rig.step(rate: 0.8, about: Rig.right)
        let r = mapper.map(rotationRate: s.rotationRate, gravity: s.gravity)
        #expect(abs(r.pitch - 0.8) < 1e-3)
        #expect(abs(r.yaw) < 0.02)
    }

    @Test("Twisting clockwise reads as positive roll", arguments: Rig.mounts)
    func roll(mount: simd_quatd) {
        var rig = Rig(mount: mount)
        var mapper = AxisMapper(forward: rig.forwardInDevice)
        let s = rig.step(rate: 0.5, about: Rig.forward)
        let r = mapper.map(rotationRate: s.rotationRate, gravity: s.gravity)
        #expect(abs(r.roll - 0.5) < 1e-3)
        #expect(abs(r.yaw) < 0.02)
    }

    @Test("Left/right and up/down stay true to the room when the wrist is rolled over", arguments: Rig.mounts)
    func survivesWristRoll(mount: simd_quatd) {
        var rig = Rig(mount: mount)
        var mapper = AxisMapper(forward: rig.forwardInDevice)
        // Roll the wrist 40 degrees, then turn right and tilt up.
        for _ in 0..<35 { _ = rig.step(rate: 1.0, about: Rig.forward) }
        let turn = rig.step(rate: -1.0, about: Rig.up)
        let a = mapper.map(rotationRate: turn.rotationRate, gravity: turn.gravity)
        #expect(abs(a.yaw - 1.0) < 1e-3)
        #expect(abs(a.pitch) < 0.03)
        let tilt = rig.step(rate: 1.0, about: Rig.right)
        let b = mapper.map(rotationRate: tilt.rotationRate, gravity: tilt.gravity)
        #expect(abs(b.pitch - 1.0) < 0.03)
        #expect(abs(b.yaw) < 0.03)
    }

    @Test("Pointing straight up does not flip the axes")
    func holdsThroughVertical() {
        var mapper = AxisMapper(forward: Vec3(0, 1, 0))
        _ = mapper.map(rotationRate: .zero, gravity: Vec3(0, 0, -1))
        // Forward now parallel to gravity: the level axis is undefined, so the last good one holds.
        let r = mapper.map(rotationRate: Vec3(1, 0, 0), gravity: Vec3(0, -1, 0))
        #expect(r.pitch.isFinite && r.yaw.isFinite && r.roll.isFinite)
    }
}

@Suite("Calibration")
struct AxisCalibratorTests {
    /// Holds still, then performs `gesture`, and returns the calibrator.
    private func run(mount: simd_quatd, rate: Double, about axis: Vec3, for duration: Double, stillFirst: Double = 0.6) -> AxisCalibrator {
        var rig = Rig(mount: mount)
        var cal = AxisCalibrator()
        for _ in 0..<Int(stillFirst / rig.dt) { cal.ingest(rig.step()) }
        for _ in 0..<Int(duration / rig.dt) { cal.ingest(rig.step(rate: rate, about: axis)) }
        for _ in 0..<20 { cal.ingest(rig.step()) }
        return cal
    }

    @Test("A tilt up teaches which way the case points", arguments: Rig.mounts)
    func learnsForward(mount: simd_quatd) {
        let cal = run(mount: mount, rate: 40.0.radians, about: Rig.right, for: 0.4)
        guard case .done(let forward) = cal.state else {
            Issue.record("calibration did not finish: \(cal.state), \(String(describing: cal.problem))")
            return
        }
        #expect(angleBetween(forward, Rig(mount: mount).forwardInDevice) < 12)
    }

    @Test("A sideways turn is refused, not learned")
    func refusesSideways() {
        // Mostly a turn, with a little tilt mixed in so capture starts.
        let axis = simd_normalize(Rig.up * 1.0 + Rig.right * 0.75)
        var rig = Rig(mount: Rig.mounts[1])
        var cal = AxisCalibrator()
        for _ in 0..<30 { cal.ingest(rig.step()) }
        // Start with a clean tilt so the onset test passes, then swing into a turn.
        for _ in 0..<3 { cal.ingest(rig.step(rate: 0.7, about: Rig.right)) }
        for _ in 0..<25 { cal.ingest(rig.step(rate: 1.2, about: axis)) }
        for _ in 0..<20 { cal.ingest(rig.step()) }
        if case .done = cal.state { Issue.record("a sideways turn was accepted") }
        #expect(cal.problem == .sideways)
    }

    @Test("A twitch is too small to learn from")
    func refusesTinyMotion() {
        let cal = run(mount: Rig.mounts[2], rate: 25.0.radians, about: Rig.right, for: 0.1)
        if case .done = cal.state { Issue.record("a 2.5 degree twitch was accepted") }
        #expect(cal.problem == .tooSmall)
    }

    @Test("Nothing is read until the hand has settled")
    func waitsForStillness() {
        var rig = Rig(mount: Rig.mounts[0])
        var cal = AxisCalibrator()
        for _ in 0..<40 { cal.ingest(rig.step(rate: 1.0, about: Rig.right)) }
        #expect(cal.state == .settling)
        for _ in 0..<30 { cal.ingest(rig.step()) }
        #expect(cal.state == .ready)
    }
}
