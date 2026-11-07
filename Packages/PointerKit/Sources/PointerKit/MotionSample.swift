import Foundation
import simd

/// Which earbud a sample came from. Raw values match `CMDeviceMotion.SensorLocation`.
public enum SensorLocation: Int, Codable, Sendable, CaseIterable {
    case unknown = 0
    case left = 1
    case right = 2
}

/// One motion reading from an AirPod, in the earbud's own frame.
public struct MotionSample: Sendable, Equatable {
    /// Sensor clock, seconds. Advances in exact 20 ms steps while the stream is healthy.
    public var timestamp: Double
    /// Host clock when the sample reached this Mac, seconds. Bluetooth delivers in bursts,
    /// so this is jittery where `timestamp` is not.
    public var arrival: Double
    /// Rotation rate, rad/s, right-hand rule about each device axis.
    public var rotationRate: Vec3
    /// Acceleration with gravity removed, in g.
    public var userAcceleration: Vec3
    /// Gravity direction in the device frame, in g. Points toward the ground.
    public var gravity: Vec3
    /// Orientation relative to an arbitrary, slowly drifting reference.
    public var attitude: simd_quatd
    public var location: SensorLocation

    public init(
        timestamp: Double,
        arrival: Double,
        rotationRate: Vec3,
        userAcceleration: Vec3 = .zero,
        gravity: Vec3 = Vec3(0, 0, -1),
        attitude: simd_quatd = simd_quatd(ix: 0, iy: 0, iz: 0, r: 1),
        location: SensorLocation = .right
    ) {
        self.timestamp = timestamp
        self.arrival = arrival
        self.rotationRate = rotationRate
        self.userAcceleration = userAcceleration
        self.gravity = gravity
        self.attitude = attitude
        self.location = location
    }
}

