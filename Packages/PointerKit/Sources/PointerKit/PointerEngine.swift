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

