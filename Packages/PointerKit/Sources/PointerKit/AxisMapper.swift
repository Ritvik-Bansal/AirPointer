import Foundation
import simd

/// Rotation expressed the way a person holding a pointer thinks about it.
public struct PointerRates: Sendable, Equatable {
    /// Turning right is positive. rad/s.
    public var yaw: Double
    /// Tilting up is positive. rad/s.
    public var pitch: Double
    /// Twisting clockwise, seen from behind, is positive. rad/s.
    public var roll: Double

    public init(yaw: Double = 0, pitch: Double = 0, roll: Double = 0) {
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
    }
}

/// Converts rotation in the earbud's frame into yaw / pitch / roll about the user's own axes.
///
/// The earbud can sit in the hand at any angle, so its axes mean nothing on their own. Two
/// facts pin the mapping down: gravity gives "up" for free on every sample, and a one-off
/// calibration gives `forward`, the device-frame direction that points away from the user.
/// Yaw is rotation about up; pitch is rotation about the level axis square to forward. That
/// keeps left/right and up/down true to the room even when the wrist rolls.
public struct AxisMapper: Sendable {
    /// Device-frame direction that points at the screen in the user's grip.
    public var forward: Vec3 {
        didSet { forward = forward.unit ?? Vec3(0, 1, 0) }
    }

    private var up = Vec3(0, 0, 1)
    private var right = Vec3(1, 0, 0)

    public init(forward: Vec3 = Vec3(0, 1, 0)) {
        self.forward = forward.unit ?? Vec3(0, 1, 0)
    }

    public mutating func map(rotationRate w: Vec3, gravity g: Vec3) -> PointerRates {
        if let u = (-g).unit, g.length > 0.3 { up = u }
        // Level axis to the user's right. Undefined while pointing straight up or down, so
        // hold the last good one through that pose.
        let c = forward.cross(up)
        if c.length > 0.25 { right = c / c.length }
        let level = right - up * right.dot(up)
        let r = level.unit ?? right
        let f = up.cross(r)
        return PointerRates(yaw: -w.dot(up), pitch: w.dot(r), roll: w.dot(f))
    }
}

/// The per-earbud `forward` directions learned by calibration.
public struct GripCalibration: Codable, Equatable, Sendable {
    public var forwardLeft: [Double]?
    public var forwardRight: [Double]?

    public init(forwardLeft: [Double]? = nil, forwardRight: [Double]? = nil) {
        self.forwardLeft = forwardLeft
        self.forwardRight = forwardRight
    }

    public func forward(for location: SensorLocation) -> Vec3? {
        let v = location == .left ? forwardLeft : forwardRight
        guard let v, v.count == 3 else { return nil }
        return Vec3(v[0], v[1], v[2])
    }

    public mutating func set(_ forward: Vec3, for location: SensorLocation) {
        let v = [forward.x, forward.y, forward.z]
        if location == .left { forwardLeft = v } else { forwardRight = v }
    }

    public func isCalibrated(for location: SensorLocation) -> Bool { forward(for: location) != nil }
}

