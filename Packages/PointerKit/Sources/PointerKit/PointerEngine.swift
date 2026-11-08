import Foundation
import simd

/// Everything the engine needs to know about how the pointer should behave.
public struct EngineSettings: Sendable, Equatable {
    public var shaper = RateShaper.Params()
    public var invertHorizontal = false
    public var invertVertical = false

    public var tapsEnabled = true
    public var tap = TapDetector.Params()
    public var scheme = TapScheme.doubleTapClicks
    public var tapWindow = 0.4
    public var thirdTap = ThirdTapAction.doubleClick

    /// Fastest the hand may have been turning in the quarter second before a gesture's
    /// first tap, deg/s. People stop to click; a knock while the case is being picked up,
    /// re-gripped or put down arrives mid-motion.
    public var leadInSpeed = 34.0
    /// Fastest the hand may have been turning on average over the half second before a
    /// gesture's first tap, deg/s. A settled hand averages under 8 on record; a hand busy
    /// with the case averages 13 and up.
    public var settledSpeed = 16.0
    /// Slowest a hand-held case turns, averaged over half a second, deg/s. A hand always
    /// trembles a little (0.45 at the stillest on record); below this the case is lying on
    /// something (0.06 to 0.3 on record) and a knock is the table being bumped.
    public var restSpeed = 0.34
    /// Furthest the hand may wander while a gesture is in progress, degrees, before the
    /// gesture is called off as handling rather than tapping.
    public var gestureDrift = 14.0

    public var twistToScroll = false
    /// Points scrolled per degree of twist.
    public var scrollGain = 9.0
    public var reverseScroll = false

    public init() {}
}

/// A snapshot of what the engine is seeing, for the interface.
public struct Telemetry: Sendable, Equatable {
    /// deg/s.
    public var yaw = 0.0
    public var pitch = 0.0
    public var roll = 0.0
    /// Cursor velocity the engine is asking for, points per second.
    public var velocity = Vec2.zero
    /// Latest tap score relative to its threshold.
    public var tapLevel = 0.0
    /// True while the cursor is held in place around a tap.
    public var holding = false
    /// Jolts that looked like taps but were refused: the hand was moving, the case was
    /// lying down, or the hand wandered off mid-gesture.
    public var knocksIgnored = 0
    /// The most recent jolt the detector found, and what was made of it. For diagnosis.
    public var lastJolt = Jolt()

    public struct Jolt: Sendable, Equatable {
        /// Sensor time of the jolt; zero before the first one.
        public var time = 0.0
        /// Fastest the hand was turning in the quarter second before it, deg/s.
        public var leadIn = 0.0
        /// Average turning speed over the half second before it, deg/s.
        public var stillness = 0.0
        /// Whether it continued a gesture already under way.
        public var continued = false
        public var accepted = false

        public init() {}
    }
    public var scrolling = false
    /// How far the case is aimed above level, degrees. Read straight from gravity, so it does not drift.
    public var elevation = 0.0
    public var gravity = Vec3(0, 0, -1)
    public var attitude = simd_quatd(ix: 0, iy: 0, iz: 0, r: 1)
    public var location = SensorLocation.unknown
    public var timestamp = 0.0

    public init() {}
}

/// The whole pipeline: motion samples in, cursor movement and clicks out.
///
/// Feed every sample to `ingest`, and call `frame` once per display refresh for the movement
/// to apply. The engine is a value with no clock or threads of its own, so a recorded trace
/// replays to the same result every time.
public struct PointerEngine: Sendable {
    public struct Output: Sendable, Equatable {
        public var events: [PointerEvent] = []
        /// Movement to apply at once, before acting on `events`. Non-zero when a tap pulls the
        /// cursor back to where it was aimed before the jolt.
        public var snap = Vec2.zero
    }

    public struct Frame: Sendable, Equatable {
        public var move = Vec2.zero
        public var scroll = Vec2.zero
    }

    public var settings: EngineSettings {
        didSet {
            // Turning taps off, or changing what they mean, mid-gesture must not leave a
            // click waiting or a drag held.
            if settings.tapsEnabled != oldValue.tapsEnabled || settings.scheme != oldValue.scheme || settings.thirdTap != oldValue.thirdTap {
                queued += sequencer.reset()
            }
            applySettings()
        }
    }
    public var calibration: GripCalibration {
        // Pick the new axes up on the next sample.
        didSet { mapperLocation = nil }
    }
    public private(set) var telemetry = Telemetry()
    /// Non-nil while a calibration gesture is being read. Pointer output is paused meanwhile.
    public private(set) var calibrator: AxisCalibrator?

    /// How far before a tap the cursor is rewound, seconds. Covers the hand tensing up.
    var preTap = 0.06
    /// How long after a tap the cursor stays put, seconds. Covers the rebound.
    var postTap = 0.16
    /// How long leftover tap displacement is remembered, seconds.
    var debtMemory = 0.6
    /// Samples dropped after the stream (re)starts, while sensor fusion settles.
    var warmupSamples = 12

    private var mapper = AxisMapper()
    private var mapperLocation: SensorLocation?
    private var shaper = RateShaper()
    private var playout = Playout()
    private var scrollPlayout = Playout()
    private var detector = TapDetector()
    private var sequencer = TapSequencer()

    private var lastTimestamp: Double?
    private var warmup = 0
    private var holdUntil = -Double.infinity
    private var scrollUntil = -Double.infinity
    private var rollSmoothed = 0.0
    /// Degrees of yaw and pitch the hand moved while the cursor was held for a tap. A tap
    /// knocks the case off its aim and the hand drifts back over the next half second; that
    /// return is not pointing, so it is paid off against this instead of moving the cursor.
    private var debt = Vec2.zero
    private var recentMotion: [(time: Double, d: Vec2)] = []
    /// How far the hand has moved since the gesture in progress began, degrees.
    private var wander = Vec2.zero
    /// Turning speed of the last three quarters of a second, deg/s.
    private var speeds: [(time: Double, speed: Double)] = []
    /// Events owed from outside a sample, handed over with the next one.
    private var queued: [PointerEvent] = []

    /// `forward` used before the grip has been calibrated. Measured with both AirPods docked
    /// and the case held like a remote, lid open; the left earbud sits mirrored in the case.
    public static func defaultForward(for location: SensorLocation) -> Vec3 {
        location == .left ? Vec3(0.893, 0.394, 0.217) : Vec3(-0.893, 0.394, 0.217)
    }

    public init(settings: EngineSettings = EngineSettings(), calibration: GripCalibration = GripCalibration()) {
        self.settings = settings
        self.calibration = calibration
        applySettings()
    }

    private mutating func applySettings() {
        shaper.params = settings.shaper
        detector.params = settings.tap
        detector.params.partnerWindow = settings.tapWindow
        sequencer.scheme = settings.scheme
        sequencer.window = settings.tapWindow
        sequencer.thirdTap = settings.thirdTap
    }

    // MARK: Calibration

    public mutating func beginCalibration() {
        calibrator = AxisCalibrator()
        haltMotion()
    }

    public mutating func cancelCalibration() {
        calibrator = nil
    }

    // MARK: Lifecycle

    /// Forgets all motion state. Releases a held drag.
    public mutating func reset() -> [PointerEvent] {
        lastTimestamp = nil
        warmup = 0
        haltMotion()
        detector.reset()
        speeds.removeAll()
        mapperLocation = nil
        let owed = queued + sequencer.reset()
        queued.removeAll()
        return owed
    }

    /// Calls off any gesture in progress and releases a held drag, leaving motion alone.
    /// Used when the pointer is switched back on, so taps made while it was off count for nothing.
    public mutating func cancelGestures() -> [PointerEvent] {
        holdUntil = -.infinity
        debt = .zero
        wander = .zero
        return sequencer.reset()
    }

    private mutating func haltMotion() {
        shaper.reset()
        playout.halt()
        scrollPlayout.halt()
        holdUntil = -.infinity
        scrollUntil = -.infinity
        rollSmoothed = 0
        debt = .zero
        wander = .zero
        recentMotion.removeAll()
    }

    // MARK: Samples

    public mutating func ingest(_ s: MotionSample) -> Output {
        var out = Output()
        out.events = queued
        queued.removeAll()

        var dt = 0.02
        if let last = lastTimestamp {
            let step = s.timestamp - last
            if step <= 0 || step > 0.5 {
                // The AirPods slept or reconnected. Their sensor fusion starts over, and so
                // does everything here, including any gesture that was under way.
                warmup = 0
                haltMotion()
                detector.reset()
                speeds.removeAll()
                out.events += sequencer.reset()
            } else if step > 0.05 {
                // A few samples were lost in the air; the stream itself carried on. Keep what
                // was dead-reckoned into the hole rather than snapping back.
                playout.bridge(now: s.arrival)
                scrollPlayout.bridge(now: s.arrival)
            } else {
                dt = max(step, 0.005)
            }
        }
        let lastTimestampBeforeThis = lastTimestamp ?? -Double.infinity
        lastTimestamp = s.timestamp

        warmup += 1
        guard warmup > warmupSamples else { return out }

        if mapperLocation != s.location {
            mapperLocation = s.location
            mapper.forward = calibration.forward(for: s.location) ?? Self.defaultForward(for: s.location)
        }
        speeds.append((s.timestamp, s.rotationRate.length.degrees))
        if speeds.count > 40 { speeds.removeFirst(speeds.count - 40) }
        let rates = mapper.map(rotationRate: s.rotationRate, gravity: s.gravity)
        telemetry.yaw = rates.yaw.degrees
        telemetry.pitch = rates.pitch.degrees
        telemetry.roll = rates.roll.degrees
        if let up = (-s.gravity).unit {
            telemetry.elevation = asin(clamp(mapper.forward.dot(up), -1, 1)).degrees
        }
        telemetry.gravity = s.gravity
        telemetry.attitude = s.attitude
        telemetry.location = s.location
        telemetry.timestamp = s.timestamp

        if calibrator != nil {
            calibrator?.ingest(s)
            if case .done(let forward)? = calibrator?.state {
                calibration.set(forward, for: s.location)
                mapper.forward = forward
                calibrator = nil
            }
            telemetry.velocity = .zero
            return out
        }

        let motion = Vec2(telemetry.yaw, telemetry.pitch) * dt
        recentMotion.append((s.timestamp, motion))
        if recentMotion.count > 8 { recentMotion.removeFirst() }
        let wasHolding = lastTimestampBeforeThis <= holdUntil

        // Taps.
        if settings.tapsEnabled {
            let tap = detector.ingest(s)
            // Taps are found one sample late, so that is where the gesture clock stands. A
            // lone tap is resolved before a new one is counted: two taps exactly a window
            // apart are still a pair.
            let clock = tap.map { $0.time - 1e-9 } ?? s.timestamp - 0.02
            var resolved = sequencer.advance(to: clock)
            if !resolved.isEmpty {
                // A lone tap becomes a right-click only if the hand is still there, holding
                // the case where it was. A case just put down goes dead still; a case being
                // picked up has wandered off.
                if wander.length > settings.gestureDrift * 0.6 || !isHandHeld(until: clock + 0.02, over: 0.24) {
                    resolved = []
                    telemetry.knocksIgnored += 1
                    debt = .zero
                }
                out.events += resolved
                holdUntil = min(holdUntil, s.timestamp + 0.04)
            }

            if let tap {
                let continues = sequencer.isMidGesture(at: tap.time)
                telemetry.lastJolt.time = tap.time
                telemetry.lastJolt.leadIn = leadInPeak(before: tap.time) ?? -1
                telemetry.lastJolt.stillness = meanSpeed(until: tap.time - 0.03, over: 0.5) ?? -1
                telemetry.lastJolt.continued = continues
                telemetry.lastJolt.accepted = continues || (isCalm(before: tap.time) && isHandHeld(until: tap.time - 0.03, over: 0.5))
                if !continues, !(isCalm(before: tap.time) && isHandHeld(until: tap.time - 0.03, over: 0.5)) {
                    // A knock while the case is being handled, or while it lies on a table.
                    telemetry.knocksIgnored += 1
                } else {
                    // Put the cursor back where it was aimed before the jolt, and keep it
                    // there until the hand has recovered or the gesture has resolved.
                    playout.rewind(to: tap.time - preTap)
                    out.snap = playout.settle()
                    shaper.reset()
                    if !continues { wander = .zero }
                    if !wasHolding {
                        // The rewound samples moved the hand too; all but this one, which the
                        // hold below accounts for.
                        for m in recentMotion.dropLast() where m.time > tap.time - preTap {
                            debt += m.d
                            wander += m.d
                        }
                    }
                    out.events.append(.tap(strength: tap.strength))
                    let produced = sequencer.tap(at: tap.time)
                    if !produced.isEmpty, continues, wander.length > settings.gestureDrift {
                        // The taps came with the hand going somewhere else. Handling, not clicking.
                        sequencer.cancel()
                        telemetry.knocksIgnored += 1
                        debt = .zero
                        holdUntil = -.infinity
                    } else {
                        out.events += produced
                        holdUntil = tap.time + (sequencer.isPending ? settings.tapWindow + 0.04 : postTap)
                    }
                }
            }
            telemetry.tapLevel = detector.level
        } else {
            telemetry.tapLevel = 0
        }

        let holding = s.timestamp <= holdUntil
        telemetry.holding = holding
        if holding {
            debt += motion
            wander += motion
            shaper.reset()
            telemetry.velocity = .zero
            telemetry.scrolling = false
            return out
        }

        // Pay off what a tap left behind before treating motion as pointing.
        var aim = motion
        let owed = debt.length
        if owed > 1e-6 {
            let direction = debt / owed
            let back = -(aim.x * direction.x + aim.y * direction.y)
            if back > 0 {
                let paid = min(back, owed)
                aim += direction * paid
                debt -= direction * paid
            }
            debt *= exp(-dt / debtMemory)
        }

        // Twist to scroll. Engages only when the twist clearly dominates, then owns the motion
        // until the wrist stops turning.
        var scrolling = false
        if settings.twistToScroll {
            rollSmoothed += (telemetry.roll - rollSmoothed) * lowPassAlpha(cutoffHz: 6, dt: dt)
            let aim = hypot(telemetry.yaw, telemetry.pitch)
            if abs(rollSmoothed) > 45, abs(rollSmoothed) > 2 * aim {
                scrollUntil = s.timestamp + 0.15
            } else if s.timestamp <= scrollUntil, abs(rollSmoothed) > 12 {
                scrollUntil = s.timestamp + 0.15
            }
            scrolling = s.timestamp <= scrollUntil
        }
        telemetry.scrolling = scrolling

        if scrolling {
            shaper.reset()
            let excess = max(0, abs(rollSmoothed) - 8) * (rollSmoothed < 0 ? -1 : 1)
            let direction = settings.reverseScroll ? -1.0 : 1.0
            // Clockwise twist scrolls down the page.
            let v = Vec2(0, -excess * settings.scrollGain * direction)
            scrollPlayout.push(velocity: v, dt: dt, sensorTime: s.timestamp, arrival: s.arrival)
            playout.push(velocity: .zero, dt: dt, sensorTime: s.timestamp, arrival: s.arrival)
            telemetry.velocity = .zero
            return out
        }
        if settings.twistToScroll {
            scrollPlayout.push(velocity: .zero, dt: dt, sensorTime: s.timestamp, arrival: s.arrival)
        }

        var v = shaper.shape(yaw: aim.x / dt, pitch: aim.y / dt, dt: dt)
        if settings.invertHorizontal { v.x = -v.x }
        if settings.invertVertical { v.y = -v.y }
        telemetry.velocity = v
        playout.push(velocity: v, dt: dt, sensorTime: s.timestamp, arrival: s.arrival)
        return out
    }

    // MARK: Telling a tap from a knock

    /// Fastest turning speed in the quarter second before `time`, leaving out the last
    /// sample, where the jolt itself may already have begun. Nil when the stream is too new.
    private func leadInPeak(before time: Double) -> Double? {
        let lead = speeds.filter { $0.time >= time - 0.26 && $0.time <= time - 0.03 }
        guard lead.count >= 6 else { return nil }
        return lead.map(\.speed).max()
    }

    /// Average turning speed over the `span` seconds up to `time`. Nil when there is too little to go on.
    private func meanSpeed(until time: Double, over span: Double) -> Double? {
        let recent = speeds.filter { $0.time >= time - span && $0.time <= time }
        guard recent.count >= Int(span / 0.02 * 0.5) else { return nil }
        return recent.map(\.speed).reduce(0, +) / Double(recent.count)
    }

    /// The hand had stopped before `time`: no burst of motion in the last quarter second, and
    /// settled on average over the last half. With no history, the answer is no.
    private func isCalm(before time: Double) -> Bool {
        (leadInPeak(before: time) ?? .infinity) <= settings.leadInSpeed
            && (meanSpeed(until: time - 0.03, over: 0.5) ?? .infinity) <= settings.settledSpeed
    }

    /// The case is in a hand rather than lying on something: a hand never holds anything
    /// perfectly still.
    private func isHandHeld(until time: Double, over span: Double) -> Bool {
        (meanSpeed(until: time, over: span) ?? 0) >= settings.restSpeed
    }

    // MARK: Frames

    /// Movement to apply for the display frame at host time `now`.
    public mutating func frame(now: Double) -> Frame {
        Frame(move: playout.pull(now: now), scroll: scrollPlayout.pull(now: now))
    }
}
