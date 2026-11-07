import Foundation

/// The handful of controls a person actually adjusts. Each maps onto several engine
/// parameters, so the interface stays small and every setting does something you can feel.
public struct PointerPreferences: Codable, Equatable, Sendable {
    /// Overall pointer speed. 1.0 is the default; 0.4…2.5.
    public var speed = 1.0
    /// How much faster the cursor travels in a flick than in a careful move. 0…1.
    public var acceleration = 0.7
    /// How firmly small hand movement is damped. 0 is raw, 1 is rock-steady but slower to react.
    public var steadiness = 0.5
    public var invertHorizontal = false
    public var invertVertical = false

    public var tapsEnabled = true
    public var tapScheme = TapScheme.doubleTapClicks
    /// 0 needs a firm rap, 1 responds to a light touch.
    public var tapSensitivity = 0.5
    /// Longest pause between the taps of a double-tap, seconds.
    public var tapWindow = 0.4
    public var thirdTap = ThirdTapAction.doubleClick

    public var twistToScroll = false
    public var scrollSpeed = 1.0
    public var reverseScroll = false

    public init() {}

    public init(from decoder: Decoder) throws {
        // Every key is optional so settings saved by an older build still load.
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PointerPreferences()
        speed = try c.decodeIfPresent(Double.self, forKey: .speed) ?? d.speed
        acceleration = try c.decodeIfPresent(Double.self, forKey: .acceleration) ?? d.acceleration
        steadiness = try c.decodeIfPresent(Double.self, forKey: .steadiness) ?? d.steadiness
        invertHorizontal = try c.decodeIfPresent(Bool.self, forKey: .invertHorizontal) ?? d.invertHorizontal
        invertVertical = try c.decodeIfPresent(Bool.self, forKey: .invertVertical) ?? d.invertVertical
        tapsEnabled = try c.decodeIfPresent(Bool.self, forKey: .tapsEnabled) ?? d.tapsEnabled
        tapScheme = try c.decodeIfPresent(TapScheme.self, forKey: .tapScheme) ?? d.tapScheme
        tapSensitivity = try c.decodeIfPresent(Double.self, forKey: .tapSensitivity) ?? d.tapSensitivity
        tapWindow = try c.decodeIfPresent(Double.self, forKey: .tapWindow) ?? d.tapWindow
        thirdTap = try c.decodeIfPresent(ThirdTapAction.self, forKey: .thirdTap) ?? d.thirdTap
        twistToScroll = try c.decodeIfPresent(Bool.self, forKey: .twistToScroll) ?? d.twistToScroll
        scrollSpeed = try c.decodeIfPresent(Double.self, forKey: .scrollSpeed) ?? d.scrollSpeed
        reverseScroll = try c.decodeIfPresent(Bool.self, forKey: .reverseScroll) ?? d.reverseScroll
    }

    /// The score a jolt must reach to count as a tap, for a sensitivity of 0…1.
    ///
    /// The middle of the slider is the value the recordings were tuned to. Below it the
    /// threshold rises quickly, for anyone who wants to tap firmly and never misfire. Above
    /// it the threshold falls only a little: on whole recordings, anything much lower lets
    /// through the knocks of handling the case.
    public static func tapThreshold(sensitivity: Double) -> Double {
        let s = clamp(sensitivity, 0, 1)
        return s <= 0.5
            ? 2.4 * pow(1.25 / 2.4, s * 2)
            : 1.25 * pow(1.1 / 1.25, s * 2 - 1)
    }

    /// Points per degree at a middling hand speed, before the speed setting is applied.
    public static let baseGain = 24.0

    /// - Parameter displayScale: Main display width relative to a 1512-point MacBook screen,
    ///   so a sweep of the hand covers the same share of a larger display.
    public func engineSettings(displayScale: Double = 1) -> EngineSettings {
        var e = EngineSettings()

        let base = Self.baseGain * clamp(speed, 0.2, 4) * displayScale
        let spread = (1 + 5 * clamp(acceleration, 0, 1)).squareRoot()
        e.shaper.gainSlow = base / spread
        e.shaper.gainFast = base * spread

        let s = clamp(steadiness, 0, 1)
        e.shaper.cutoffAtRest = 8 * pow(0.18, s)
        e.shaper.cutoffPerSpeed = lerp(0.9, 0.3, s)
        e.shaper.floor = lerp(0.12, 0.4, s)
        e.shaper.tighten = lerp(0.7, 2.6, s)

        e.invertHorizontal = invertHorizontal
        e.invertVertical = invertVertical

        e.tapsEnabled = tapsEnabled
        e.scheme = tapScheme
        e.tap.threshold = Self.tapThreshold(sensitivity: tapSensitivity)
        e.tapWindow = clamp(tapWindow, 0.2, 0.8)
        e.thirdTap = thirdTap

        e.twistToScroll = twistToScroll
        e.scrollGain = 9 * clamp(scrollSpeed, 0.2, 4)
        e.reverseScroll = reverseScroll
        return e
    }
}
