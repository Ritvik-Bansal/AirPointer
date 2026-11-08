import Foundation
import simd
import Testing
@testable import PointerKit

/// A rigid body in a room where +z is up, +y is forward and +x is to the right. Produces
/// the samples an earbud fixed to it would report, whatever way round the earbud is mounted.
struct Rig {
    /// Rotation from the earbud's frame to the room at rest.
    var mount: simd_quatd
    var orientation: simd_quatd
    var time = 100.0
    let dt = 0.02

    init(mount: simd_quatd) {
        self.mount = mount
        self.orientation = mount
    }

    static let right = Vec3(1, 0, 0), forward = Vec3(0, 1, 0), up = Vec3(0, 0, 1)

    /// Direction the body points, in the earbud's frame.
    var forwardInDevice: Vec3 { mount.inverse.act(Self.forward) }

    /// Advances one sample while rotating at `rate` rad/s about a room axis.
    mutating func step(rate: Double = 0, about axis: Vec3 = Rig.up, jolt: Vec3 = .zero) -> MotionSample {
        let w = axis * rate
        orientation = simd_quatd(angle: rate * dt, axis: axis) * orientation
        time += dt
        return MotionSample(
            timestamp: time,
            arrival: time + 0.03,
            rotationRate: orientation.inverse.act(w),
            userAcceleration: jolt,
            gravity: orientation.inverse.act(-Rig.up),
            attitude: orientation
        )
    }

    /// A handful of awkward mountings, so nothing passes only because the axes happened to line up.
    static let mounts: [simd_quatd] = [
        simd_quatd(angle: 0, axis: Vec3(0, 0, 1)),
        simd_quatd(angle: 1.1, axis: simd_normalize(Vec3(1, 2, 3))),
        simd_quatd(angle: 2.4, axis: simd_normalize(Vec3(-2, 0.5, 1))),
        simd_quatd(angle: -0.7, axis: simd_normalize(Vec3(0.3, -1, 0.2))),
        simd_quatd(angle: 3.0, axis: simd_normalize(Vec3(1, 1, -1))),
    ]
}

func angleBetween(_ a: Vec3, _ b: Vec3) -> Double {
    acos(clamp(simd_dot(simd_normalize(a), simd_normalize(b)), -1, 1)).degrees
}

/// Engine set up the way the app sets it up, with default preferences.
func makeEngine(_ prefs: PointerPreferences = PointerPreferences(), calibration: GripCalibration = GripCalibration()) -> PointerEngine {
    PointerEngine(settings: prefs.engineSettings(), calibration: calibration)
}
