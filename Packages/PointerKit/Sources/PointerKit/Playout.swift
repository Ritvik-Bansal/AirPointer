import Foundation

/// Turns bursty 50 Hz motion samples into smooth per-frame cursor movement.
///
/// Bluetooth delivers samples in clumps: two at once, then nothing for 60 ms. Moving the
/// cursor only when samples land would stutter. Instead every sample adds its displacement
/// to a running target, and each display frame the cursor follows that target. Between
/// samples the target is dead-reckoned forward along the last known velocity, by exactly the
/// amount of sensor time that has not arrived yet, so steady motion stays steady through a
/// gap and nothing is counted twice when the late samples show up.
public struct Playout: Sendable {
    /// Time constant of the frame-rate follower, seconds.
    public var followTime = 0.012
    /// Furthest the target is dead-reckoned ahead of received data, seconds. Covers 99% of the
    /// delivery gaps measured on a real stream; going further would overshoot on a sudden stop.
    public var maxLead = 0.06
    /// After this long without samples the motion is treated as ended, seconds.
    public var stallTimeout = 0.5

    private var target = Vec2.zero
    private var emitted = Vec2.zero
    private var velocity = Vec2.zero
    private var lastSensorTime: Double?
    private var lastArrival = 0.0
    private var clockOffset: Double?
    private var lastPull: Double?
    private var history: [(time: Double, d: Vec2)] = []

    public init() {}

    /// Adds one sample's worth of motion.
    /// - Parameters:
    ///   - velocity: Cursor velocity for this sample, points per second.
    ///   - dt: Sensor time the sample covers, seconds.
    public mutating func push(velocity v: Vec2, dt: Double, sensorTime: Double, arrival: Double) {
        let d = v * dt
        target += d
        velocity = v
        history.append((sensorTime, d))
        if history.count > 64 { history.removeFirst(history.count - 64) }

        // Offset between the two clocks along the fastest delivery path. Late samples only
        // ever make it look larger, so track the minimum and let it creep up slowly to follow
        // genuine clock drift.
        let offset = arrival - sensorTime
        if let c = clockOffset {
            clockOffset = min(offset, c + 0.002 * max(0, arrival - lastArrival))
        } else {
            clockOffset = offset
        }
        // Bluetooth keeps samples in order; if one ever does arrive late, do not let the
        // clock run backwards.
        lastSensorTime = max(lastSensorTime ?? sensorTime, sensorTime)
        lastArrival = arrival
    }

    /// Movement to apply this frame, in points.
    public mutating func pull(now: Double) -> Vec2 {
        guard let previous = lastPull else {
            lastPull = now
            return .zero
        }
        lastPull = now
        let dt = clamp(now - previous, 0, 0.05)
        guard dt > 0 else { return .zero }

        if velocity != .zero, now - lastArrival > stallTimeout {
            // The stream has stopped. Keep what was dead-reckoned and stop there.
            target += velocity * lead(now: now)
            velocity = .zero
        }

        let desired = target + velocity * lead(now: now)
        let step = (desired - emitted) * (1 - exp(-dt / followTime))
        emitted += step
        return step
    }

    /// Sensor time that has elapsed but not yet been delivered, capped at `maxLead`.
    private func lead(now: Double) -> Double {
        guard let ts = lastSensorTime, let offset = clockOffset else { return 0 }
        return clamp(now - offset - ts, 0, maxLead)
    }

    /// Takes back the motion from samples newer than `sensorTime`.
    public mutating func rewind(to sensorTime: Double) {
        while let last = history.last, last.time > sensorTime {
            target -= last.d
            history.removeLast()
        }
    }

    /// Stops dead-reckoning and returns the correction that puts the cursor exactly on target.
    public mutating func settle() -> Vec2 {
        velocity = .zero
        let d = target - emitted
        emitted = target
        return d
    }

    /// Carries on across a short hole in the stream. What was dead-reckoned into the hole is
    /// kept, so the cursor does not snap back; the motion inside the hole is simply lost.
    public mutating func bridge(now: Double) {
        target += velocity * lead(now: now)
        velocity = .zero
    }

    /// Stops dead-reckoning without moving anything. Used across stream gaps.
    public mutating func halt() {
        velocity = .zero
        lastSensorTime = nil
        clockOffset = nil
    }

    public mutating func reset() {
        self = Playout(followTime: followTime, maxLead: maxLead, stallTimeout: stallTimeout)
    }

    private init(followTime: Double, maxLead: Double, stallTimeout: Double) {
        self.followTime = followTime
        self.maxLead = maxLead
        self.stallTimeout = stallTimeout
    }
}
