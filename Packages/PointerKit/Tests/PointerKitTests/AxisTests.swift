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

