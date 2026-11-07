import Foundation

/// Finds finger taps in the motion stream.
///
/// A tap is a jolt far shorter than the 20 ms between samples, so it shows up as a single
/// sample that disagrees with both of its neighbours, in acceleration and in rotation at
/// once. Deliberate hand motion is smooth at this timescale: each sample sits close to the
/// midpoint of the ones either side. The detector scores how far the middle sample of every
/// three strays from that midpoint. Waiting for the third sample costs 20 ms.
///
/// Fast motion is never perfectly smooth, so the bar rises with how quickly the hand is
/// already moving. People stop to click, which keeps real taps well clear of it.
public struct TapDetector: Sendable {
    public struct Params: Sendable, Equatable {
        /// Acceleration impulse that scores 1.0, in g.
        public var accelScale = 0.12
        /// Rotation impulse that scores 1.0, in deg/s.
        public var gyroScale = 40.0
        /// Score a jolt must reach to count as a tap while the hand is still.
        public var threshold = 1.5
        /// Hand speed that doubles the threshold, deg/s.
        public var speedRef = 40.0
        /// Shortest time between two taps, seconds. Long enough to skip the rebound that
        /// follows a tap, short enough for a quick double-tap.
        public var refractory = 0.19
        /// Ignore the stream for this long after it starts; the first samples carry a
        /// start-up transient that looks like a 1 g jolt.
        public var settleTime = 0.3
        /// For this long after a tap, a follow-up tap needs only `partnerFactor` of the
        /// threshold, seconds. The two taps of a double-tap rarely land equally hard, and
        /// reading the pair as a lone tap would turn a click into a right-click.
        public var partnerWindow = 0.4
        public var partnerFactor = 0.65

        public init() {}
    }

    public struct Tap: Sendable, Equatable {
        /// Sensor time of the jolt.
        public var time: Double
        /// Score relative to the threshold it had to beat; 1.0 is only just a tap.
        public var strength: Double
    }

    public var params: Params
    /// Score of the most recent sample relative to its threshold. Drives the tap meter.
    public private(set) var level = 0.0

    private var older: MotionSample?
    private var centre: MotionSample?
    private var contiguousTime = 0.0
    private var speed = 0.0
    private var lastTap = -Double.infinity

    public init(params: Params = Params()) {
        self.params = params
    }

    public mutating func reset() {
        older = nil
        centre = nil
        contiguousTime = 0
        speed = 0
        level = 0
    }

    public mutating func ingest(_ s: MotionSample) -> Tap? {
        defer {
            older = centre
            centre = s
        }
        guard let c = centre else { return nil }
        let step = s.timestamp - c.timestamp
        guard step > 0, step < 0.03 else {
            // A hole in the stream: the neighbours are no longer neighbours. A short hole is
            // lost packets and the stream carries on; only a long one, or time running
            // backwards, is a restart that brings the start-up transient with it.
            older = nil
            centre = nil
            level = 0
            if step <= 0 || step > 0.5 { contiguousTime = 0 }
            return nil
        }
        contiguousTime += step
        guard let o = older else { return nil }

        // Hand speed just before the middle sample, so the jolt itself does not raise its own bar.
        speed += (o.rotationRate.length.degrees - speed) * 0.22

        let accelImpulse = (c.userAcceleration - (o.userAcceleration + s.userAcceleration) / 2).length
        let gyroImpulse = (c.rotationRate - (o.rotationRate + s.rotationRate) / 2).length.degrees
        let score = accelImpulse / params.accelScale + gyroImpulse / params.gyroScale
        let sinceLast = c.timestamp - lastTap
        let partner = sinceLast <= params.partnerWindow ? params.partnerFactor : 1
        let bar = params.threshold * partner * (1 + speed / params.speedRef)
        level = score / bar

        guard contiguousTime >= params.settleTime,
              sinceLast >= params.refractory,
              score >= bar
        else { return nil }
        lastTap = c.timestamp
        return Tap(time: c.timestamp, strength: level)
    }
}
