import Foundation

/// What the cursor did over a replayed stretch of motion.
public struct ReplayResult: Sendable {
    /// Cursor position at each simulated display frame, starting from the origin. Points; y down.
    public var path: [Vec2] = []
    /// Sensor-relative time and strength of each tap the detector found.
    public var taps: [(time: Double, strength: Double)] = []
    /// Sensor-relative time of each click-type event.
    public var events: [(time: Double, event: PointerEvent)] = []
    /// Index, in the replayed sequence, of the sample each click-type event came out on.
    public var eventSamples: [Int] = []
    /// Jolts refused as knocks rather than taken as taps.
    public var knocksIgnored = 0
    public var travel = 0.0
    public var peakSpeed = 0.0

    public var end: Vec2 { path.last ?? .zero }

    public var extent: Vec2 {
        guard let first = path.first else { return .zero }
        var lo = first, hi = first
        for p in path {
            lo = Vec2(min(lo.x, p.x), min(lo.y, p.y))
            hi = Vec2(max(hi.x, p.x), max(hi.y, p.y))
        }
        return hi - lo
    }

    /// Root-mean-square distance of the cursor from its average position.
    public var wander: Double {
        guard !path.isEmpty else { return 0 }
        let mean = path.reduce(Vec2.zero, +) / Double(path.count)
        let sum = path.reduce(0.0) { $0 + (($1 - mean) * ($1 - mean)).sum() }
        return (sum / Double(path.count)).squareRoot()
    }

    public func clicks(_ button: MouseButton) -> Int {
        events.filter {
            if case .click(let b, _) = $0.event { return b == button }
            return false
        }.count
    }
}

public extension PointerEngine {
    /// Runs recorded samples through the engine the way the app would: display frames tick
    /// at `frameRate` on the host clock and each sample is handed over when it arrived.
    mutating func replay<S: Sequence>(_ samples: S, frameRate: Double = 120) -> ReplayResult where S.Element == MotionSample {
        var result = ReplayResult()
        let interval = 1 / frameRate
        var now: Double?
        var origin: Double?
        var pos = Vec2.zero

        for (index, s) in samples.enumerated() {
            if now == nil {
                now = s.arrival
                origin = s.timestamp
            }
            while let t = now, t < s.arrival {
                let d = frame(now: t).move
                pos += d
                result.travel += d.length
                result.peakSpeed = max(result.peakSpeed, d.length / interval)
                result.path.append(pos)
                now = t + interval
            }
            let out = ingest(s)
            pos += out.snap
            result.travel += out.snap.length
            for e in out.events {
                let t = s.timestamp - (origin ?? s.timestamp)
                if case .tap(let strength) = e {
                    result.taps.append((t, strength))
                } else {
                    result.events.append((t, e))
                    result.eventSamples.append(index)
                }
            }
        }
        result.knocksIgnored = telemetry.knocksIgnored
        return result
    }
}
