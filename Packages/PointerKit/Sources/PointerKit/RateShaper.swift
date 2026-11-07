import Foundation

/// Turns angular rate into cursor velocity: steadies small motion, removes drift, and applies
/// the acceleration curve.
///
/// Three stages, all continuous so nothing snaps as speed changes:
///
/// 1. A low-pass whose cutoff rises with speed. At rest it is heavy enough to swallow hand
///    tremor; in a flick it gets out of the way so the cursor does not lag.
/// 2. A soft dead zone. Below `floor` nothing moves (a resting earbud never drifts); between
///    `floor` and `tighten` output ramps in, so the slowest deliberate motion still registers.
/// 3. Gain that grows with speed, from `gainSlow` to `gainFast` points per degree. Slow hands
///    get precision, fast hands cross the screen.
public struct RateShaper: Sendable {
    public struct Params: Sendable, Equatable {
        /// Low-pass cutoff at rest, Hz.
        public var cutoffAtRest = 3.4
        /// Extra cutoff per deg/s of motion, Hz.
        public var cutoffPerSpeed = 0.5
        /// Below this speed the cursor does not move, deg/s.
        public var floor = 0.25
        /// Speed at which the dead zone has fully released, deg/s.
        public var tighten = 1.6
        /// Points per degree for the slowest motion.
        public var gainSlow = 14.0
        /// Points per degree for the fastest motion.
        public var gainFast = 64.0
        /// Speed where gain starts rising, deg/s.
        public var speedSlow = 2.0
        /// Speed where gain tops out, deg/s.
        public var speedFast = 110.0
        /// Vertical gain relative to horizontal.
        public var verticalRatio = 1.0

        public init() {}
    }

    public var params: Params

    private var smoothed = Vec2.zero   // deg/s, x = yaw, y = pitch
    private var speedEstimate = 0.0    // deg/s

    public init(params: Params = Params()) {
        self.params = params
    }

    public mutating func reset() {
        smoothed = .zero
        speedEstimate = 0
    }

    /// Gain in points per degree at a given angular speed (deg/s). Exposed for the response-curve view.
    public func gain(atSpeed speed: Double) -> Double {
        let t = smoothstep((speed - params.speedSlow) / max(1e-6, params.speedFast - params.speedSlow))
        return lerp(params.gainSlow, params.gainFast, t)
    }

    /// Fraction of motion let through by the dead zone at a given speed (deg/s).
    public func release(atSpeed speed: Double) -> Double {
        clamp((speed - params.floor) / max(1e-6, params.tighten - params.floor), 0, 1)
    }

    /// - Parameters:
    ///   - yaw: deg/s, right positive.
    ///   - pitch: deg/s, up positive.
    /// - Returns: Cursor velocity in points per second; x right, y down.
    public mutating func shape(yaw: Double, pitch: Double, dt: Double) -> Vec2 {
        let raw = Vec2(yaw, pitch)

        // Track speed a little faster than the main filter so the cutoff opens as a move starts.
        speedEstimate += (raw.length - speedEstimate) * lowPassAlpha(cutoffHz: 9, dt: dt)
        let cutoff = params.cutoffAtRest + params.cutoffPerSpeed * max(speedEstimate, smoothed.length)
        smoothed += (raw - smoothed) * lowPassAlpha(cutoffHz: cutoff, dt: dt)

        let speed = smoothed.length
        let k = release(atSpeed: speed) * gain(atSpeed: speed)
        return Vec2(smoothed.x * k, -smoothed.y * k * params.verticalRatio)
    }
}
