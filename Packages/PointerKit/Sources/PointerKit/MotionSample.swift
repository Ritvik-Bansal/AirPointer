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

/// A recorded motion stream with optional phase labels, for replay, tuning and tests.
public struct MotionTrace: Sendable {
    public struct Phase: Sendable, Equatable {
        public var name: String
        public var range: Range<Int>
    }

    public var samples: [MotionSample] = []
    public var phases: [Phase] = []

    public init(samples: [MotionSample] = [], phases: [Phase] = []) {
        self.samples = samples
        self.phases = phases
    }

    public func samples(inPhase name: String) -> ArraySlice<MotionSample> {
        guard let p = phases.first(where: { $0.name == name }) else { return [] }
        return samples[p.range]
    }

    /// Reads the plain-text trace format written by the recorder:
    ///
    ///     <arrival> S <timestamp> loc=<n> q=w,x,y,z w=x,y,z a=x,y,z g=x,y,z
    ///     <arrival> PHASE begin|end <name>
    public static func parse(_ text: String) -> MotionTrace {
        var trace = MotionTrace()
        var open: (name: String, start: Int)?
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: " ")
            guard parts.count >= 3, let arrival = Double(parts[0]) else { continue }
            switch parts[1] {
            case "PHASE":
                guard parts.count >= 4 else { continue }
                if parts[2] == "begin" {
                    open = (String(parts[3]), trace.samples.count)
                } else if let o = open {
                    trace.phases.append(Phase(name: o.name, range: o.start..<trace.samples.count))
                    open = nil
                }
            case "S":
                guard let ts = Double(parts[2]) else { continue }
                var s = MotionSample(timestamp: ts, arrival: arrival, rotationRate: .zero)
                for field in parts.dropFirst(3) {
                    guard let eq = field.firstIndex(of: "=") else { continue }
                    let key = field[..<eq]
                    let v = field[field.index(after: eq)...].split(separator: ",").compactMap { Double($0) }
                    switch key {
                    case "loc": if let n = v.first { s.location = SensorLocation(rawValue: Int(n)) ?? .unknown }
                    case "q": if v.count == 4 { s.attitude = simd_quatd(ix: v[1], iy: v[2], iz: v[3], r: v[0]) }
                    case "w": if v.count == 3 { s.rotationRate = Vec3(v[0], v[1], v[2]) }
                    case "a": if v.count == 3 { s.userAcceleration = Vec3(v[0], v[1], v[2]) }
                    case "g": if v.count == 3 { s.gravity = Vec3(v[0], v[1], v[2]) }
                    default: break
                    }
                }
                trace.samples.append(s)
            default:
                continue
            }
        }
        if let o = open { trace.phases.append(Phase(name: o.name, range: o.start..<trace.samples.count)) }
        return trace
    }

    /// One line of the trace format for a sample.
    public static func line(for s: MotionSample) -> String {
        let q = s.attitude.vector
        return String(
            format: "%.4f S %.5f loc=%d q=%.5f,%.5f,%.5f,%.5f w=%.5f,%.5f,%.5f a=%.5f,%.5f,%.5f g=%.5f,%.5f,%.5f",
            s.arrival, s.timestamp, s.location.rawValue,
            q.w, q.x, q.y, q.z,
            s.rotationRate.x, s.rotationRate.y, s.rotationRate.z,
            s.userAcceleration.x, s.userAcceleration.y, s.userAcceleration.z,
            s.gravity.x, s.gravity.y, s.gravity.z
        )
    }
}
