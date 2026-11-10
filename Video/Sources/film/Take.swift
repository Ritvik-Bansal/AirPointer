import Foundation
import PointerKit

/// A stretch of a real recording, played through the real engine and sampled once per
/// video frame: where the case was turned, where the cursor went, and what was tapped.
struct Take {
    struct Frame {
        /// Case pose in degrees, as the app's own stage shows it.
        var yaw = 0.0
        var pitch = 0.0
        var roll = 0.0
        /// Cursor on an imagined display, 0…1 from the top-left.
        var cursor = CGPoint(x: 0.5, y: 0.5)
        /// Turning rates in deg/s and the tap score against its bar, for the signal strip.
        var yawRate = 0.0
        var pitchRate = 0.0
        var tapLevel = 0.0
    }

    enum Mark: Equatable {
        case tap
        case click
        case doubleClick
        case rightClick
        /// A jolt the engine refused: the hand was moving, or the case was lying down.
        case knock
    }

    /// One reading from the sensor, as the tap detector and the knock gate saw it.
    struct Reading {
        /// Seconds from the start of the take.
        var time = 0.0
        /// The jolt score against the bar it has to reach: 1 is only just a tap.
        var level = 0.0
        /// How fast the hand had been turning, on average, over the half second before, in deg/s.
        /// The engine refuses a jolt when this is above its `settledSpeed`.
        var unrest = 0.0
    }

    var frames: [Frame] = []
    /// What happened, in seconds from the start of the take.
    var marks: [(time: Double, mark: Mark)] = []
    /// Every sensor reading in the take, fifty a second.
    var readings: [Reading] = []

    func frame(at t: Double, fps: Double = 60) -> Frame {
        guard !frames.isEmpty else { return Frame() }
        return frames[min(max(Int((t * fps).rounded()), 0), frames.count - 1)]
    }

    func marks(_ kind: Mark) -> [Double] { marks.filter { $0.mark == kind }.map(\.time) }

    /// - Parameters:
    ///   - start: Where the take begins, in seconds on the recording's own clock.
    ///   - duration: How long it runs.
    ///   - speed: Pointer speed setting. The recordings were made with nothing on screen to
    ///     aim at, so the sweeps are wide; a lower speed keeps the cursor on the imagined display.
    ///   - bounded: Whether the cursor stops at the edges of the imagined display. Left free,
    ///     its path is the true movement, for the film to place where it will fit.
    static func cut(from trace: MotionTrace, start: Double, duration: Double, speed: Double = 1, bounded: Bool = true, fps: Double = 60) -> Take {
        var prefs = PointerPreferences()
        prefs.speed = speed
        var engine = PointerEngine(settings: prefs.engineSettings())
        var take = Take()

        // Run in from a little before the take, so the engine is warm and has its history.
        let lead = 2.0
        let samples = trace.samples.filter { $0.arrival >= start - lead && $0.arrival <= start + duration }
        guard let first = samples.first else { return take }

        let display = CGSize(width: 1512, height: 982)
        var cursor = CGPoint(x: display.width / 2, y: display.height / 2)
        var yaw = 0.0, pitch = 0.0, roll = 0.0
        var now = first.arrival
        var lastJolt = 0.0
        var index = 0
        var speeds: [(time: Double, speed: Double)] = []
        let step = 1 / fps

        while now <= start + duration {
            while index < samples.count, samples[index].arrival <= now {
                let out = engine.ingest(samples[index])
                cursor.x += out.snap.x
                cursor.y += out.snap.y
                let t = samples[index].arrival - start
                for event in out.events where t >= 0 {
                    switch event {
                    case .tap: take.marks.append((t, .tap))
                    case .click(.left, let count): take.marks.append((t, count > 1 ? .doubleClick : .click))
                    case .click(.right, _): take.marks.append((t, .rightClick))
                    default: break
                    }
                }
                let jolt = engine.telemetry.lastJolt
                if jolt.time != lastJolt {
                    lastJolt = jolt.time
                    if !jolt.accepted, t >= 0 { take.marks.append((t, .knock)) }
                }
                // The same measure the engine's knock gate uses: mean turning speed over the
                // half second that ends just before this reading.
                let stamp = samples[index].timestamp
                speeds.append((stamp, samples[index].rotationRate.length.degrees))
                speeds.removeAll { $0.time < stamp - 0.6 }
                let before = speeds.filter { $0.time >= stamp - 0.53 && $0.time <= stamp - 0.03 }
                let unrest = before.isEmpty ? 0 : before.map(\.speed).reduce(0, +) / Double(before.count)
                if t >= 0 {
                    take.readings.append(Reading(time: t, level: engine.telemetry.tapLevel, unrest: unrest))
                }
                index += 1
            }
            let move = engine.frame(now: now).move
            cursor.x += move.x
            cursor.y += move.y
            if bounded {
                cursor.x = min(max(cursor.x, 0), display.width - 1)
                cursor.y = min(max(cursor.y, 0), display.height - 1)
            }

            // The same rule the app's stage uses: pitch is the true tilt, yaw and roll follow
            // the motion and ease back to centre.
            let live = engine.telemetry
            yaw += live.yaw * step
            roll += live.roll * step
            pitch += (live.elevation - pitch) * (1 - exp(-step / 0.05))
            let ease = exp(-step / 2.2)
            yaw = min(max(yaw * ease, -50), 50)
            roll = min(max(roll * ease, -60), 60)

            if now >= start {
                take.frames.append(Frame(
                    yaw: yaw, pitch: min(max(pitch, -40), 50), roll: roll,
                    cursor: CGPoint(x: cursor.x / display.width, y: cursor.y / display.height),
                    yawRate: live.yaw, pitchRate: live.pitch, tapLevel: live.tapLevel
                ))
            }
            now += step
        }
        return take
    }
}

extension MotionTrace {
    /// Start, on the recording's clock, of a labelled phase.
    func start(of phase: String) -> Double? {
        guard let p = phases.first(where: { $0.name == phase }), p.range.lowerBound < samples.count else { return nil }
        return samples[p.range.lowerBound].arrival
    }
}
