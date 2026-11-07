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

/// Learns `forward` from one gesture: hold still, then tilt the earbud up.
///
/// A tilt up is a rotation about the user's left-right axis, so the axis of that rotation,
/// levelled against gravity, is "right"; forward follows as up × right.
public struct AxisCalibrator: Sendable {
    public enum Problem: Sendable, Equatable {
        /// The motion was mostly a sideways turn rather than a tilt.
        case sideways
        /// The tilt was too small to read an axis from.
        case tooSmall
    }

    public enum State: Sendable, Equatable {
        /// Waiting for the hand to settle.
        case settling
        /// Still. Waiting for the tilt.
        case ready
        /// Reading the tilt. Progress runs 0…1.
        case capturing(progress: Double)
        case done(forward: Vec3)
    }

    public private(set) var state: State = .settling
    /// Set when the last attempt was rejected; cleared when the next one starts.
    public private(set) var problem: Problem?

    // Tunables, in degrees and seconds.
    var stillRate = 10.0
    var stillTime = 0.35
    var onsetRate = 20.0
    var endRate = 8.0
    var minAngle = 6.0
    var fullAngle = 14.0
    var maxDuration = 1.2

    private var stillFor = 0.0
    private var theta = Vec3.zero
    private var upSum = Vec3.zero
    private var elapsed = 0.0
    private var lastTimestamp: Double?

    public init() {}

    public mutating func restart() {
        state = .settling
        problem = nil
        stillFor = 0
        lastTimestamp = nil
    }

    public mutating func ingest(_ s: MotionSample) {
        if case .done = state { return }
        let dt = lastTimestamp.map { clamp(s.timestamp - $0, 0, 0.05) } ?? 0.02
        lastTimestamp = s.timestamp

        guard let up = (-s.gravity).unit else { return }
        let w = s.rotationRate
        let speed = w.length.degrees
        let vertical = w.dot(up)
        let horizontal = (w - up * vertical).length.degrees

        switch state {
        case .settling:
            stillFor = speed < stillRate ? stillFor + dt : 0
            if stillFor >= stillTime { state = .ready }

        case .ready:
            if horizontal > onsetRate, horizontal > 1.5 * abs(vertical).degrees {
                theta = w * dt
                upSum = up
                elapsed = dt
                problem = nil
                state = .capturing(progress: 0)
            }

        case .capturing:
            theta += w * dt
            upSum += up
            elapsed += dt
            let upAvg = upSum.unit ?? up
            let level = theta - upAvg * theta.dot(upAvg)
            let angle = level.length.degrees
            let finished = (elapsed > 0.1 && speed < endRate) || elapsed > maxDuration || angle > 28
            if !finished {
                state = .capturing(progress: clamp(angle / fullAngle, 0, 1))
                return
            }
            let turned = abs(theta.dot(upAvg)).degrees
            if angle < minAngle {
                fail(.tooSmall)
            } else if turned > 0.7 * angle {
                fail(.sideways)
            } else if let right = level.unit {
                state = .done(forward: upAvg.cross(right))
            } else {
                fail(.tooSmall)
            }

        case .done:
            break
        }
    }

    private mutating func fail(_ p: Problem) {
        problem = p
        stillFor = 0
        state = .settling
    }
}
