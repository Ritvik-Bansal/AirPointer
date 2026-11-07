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

