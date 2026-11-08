import Foundation
import PointerKit

// Replays a recorded motion trace through the pointer engine and reports what the cursor
// would have done. Used for tuning: change a parameter, replay, compare.
//
//   pointer-replay <trace> [--speed 1.0] [--acceleration 0.7] [--steadiness 0.5]
//                          [--sensitivity 0.5] [--forward x,y,z] [--calibrate <phase>]
//                          [--path <phase>]

var args = Array(CommandLine.arguments.dropFirst())
guard let path = args.first, let text = try? String(contentsOfFile: path, encoding: .utf8) else {
    print("usage: pointer-replay <trace> [options]")
    exit(2)
}
args.removeFirst()

func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

var prefs = PointerPreferences()
if let v = option("--speed").flatMap(Double.init) { prefs.speed = v }
if let v = option("--acceleration").flatMap(Double.init) { prefs.acceleration = v }
if let v = option("--steadiness").flatMap(Double.init) { prefs.steadiness = v }
if let v = option("--sensitivity").flatMap(Double.init) { prefs.tapSensitivity = v }
if let v = option("--scheme").flatMap(TapScheme.init(rawValue:)) { prefs.tapScheme = v }

let trace = MotionTrace.parse(text)
var calibration = GripCalibration()

if let f = option("--forward")?.split(separator: ",").compactMap({ Double($0) }), f.count == 3 {
    let v = Vec3(f[0], f[1], f[2])
    calibration.set(v, for: .left)
    calibration.set(v, for: .right)
}

// Learn `forward` the way the app does: run the calibrator over a phase that starts with a tilt up.
if let phase = option("--calibrate") {
    var cal = AxisCalibrator()
    for s in trace.samples(inPhase: phase) {
        cal.ingest(s)
        if case .done(let forward) = cal.state {
            calibration.set(forward, for: .left)
            calibration.set(forward, for: .right)
            print(String(format: "calibrated from %@: forward = (%.3f, %.3f, %.3f)", phase, forward.x, forward.y, forward.z))
            break
        }
    }
    if !calibration.isCalibrated(for: .right) { print("calibration from \(phase) failed: \(String(describing: cal.problem))") }
}

let pathPhase = option("--path")

// --whole: the entire recording through one engine, as the app runs it, including the
// handling between labelled phases. Lists every jolt and what became of it.
if args.contains("--whole") {
    var engine = PointerEngine(settings: prefs.engineSettings(), calibration: calibration)
    func phase(at index: Int) -> String {
        trace.phases.first { $0.range.contains(index) }?.name ?? "(between)"
    }
    var lastJolt = 0.0
    var now = trace.samples.first?.arrival ?? 0
    print("arrival   where             jolt: lead-in  stillness  verdict     events")
    var counts: [String: Int] = [:]
    for (i, sample) in trace.samples.enumerated() {
        while now < sample.arrival {
            _ = engine.frame(now: now)
            now += 1.0 / 120
        }
        let out = engine.ingest(sample)
        let jolt = engine.telemetry.lastJolt
        var line = ""
        if jolt.time != lastJolt {
            lastJolt = jolt.time
            let verdict = jolt.accepted ? (jolt.continued ? "continues" : "tap") : "refused"
            line = String(format: "%8.2f  %@ %7.1f  %9.2f  %@", sample.arrival, phase(at: i).padding(toLength: 16, withPad: " ", startingAt: 0), jolt.leadIn, jolt.stillness, verdict.padding(toLength: 10, withPad: " ", startingAt: 0))
        }
        let clicks = out.events.compactMap { event -> String? in
            switch event {
            case .click(let b, let n): return "\(b == .left ? "LEFT" : b == .right ? "RIGHT" : "MIDDLE")\(n > 1 ? " x\(n)" : "")"
            case .buttonDown: return "DOWN"
            case .buttonUp: return "UP"
            case .tap: return nil
            }
        }
        for c in clicks { counts["\(phase(at: i) == "(between)" ? "between phases" : "in phases"): \(c)", default: 0] += 1 }
        if !line.isEmpty || !clicks.isEmpty {
            if line.isEmpty { line = String(format: "%8.2f  %@                               ", sample.arrival, phase(at: i).padding(toLength: 16, withPad: " ", startingAt: 0)) }
            print(line + "  " + clicks.joined(separator: " "))
        }
    }
    print("")
    for (k, v) in counts.sorted(by: { $0.key < $1.key }) { print("  \(k): \(v)") }
    print("  jolts refused as knocks: \(engine.telemetry.knocksIgnored)")
    exit(0)
}

print("phase              samples  travel(pt)  net dx,dy(pt)      x-range  y-range  wander-rms  peak(pt/s)  taps  events")
for phase in trace.phases {
    let samples = trace.samples[phase.range]
    var engine = PointerEngine(settings: prefs.engineSettings(), calibration: calibration)
    let r = engine.replay(samples)
    let events = r.events.map { item -> String in
        let t = String(format: "%.2f", item.time)
        switch item.event {
        case .click(let b, let n): return "\(t):\(b == .left ? "L" : b == .right ? "R" : "M")\(n > 1 ? "x\(n)" : "")"
        case .buttonDown: return "\(t):down"
        case .buttonUp: return "\(t):up"
        case .tap: return ""
        }
    }
    print(String(
        format: "%@ %7d  %10.0f  %+8.0f,%+8.0f  %7.0f  %7.0f  %10.1f  %10.0f  %4d  %@",
        phase.name.padding(toLength: 18, withPad: " ", startingAt: 0),
        samples.count, r.travel, r.end.x, r.end.y, r.extent.x, r.extent.y, r.wander, r.peakSpeed,
        r.taps.count, events.joined(separator: " ")
    ))
    if !r.taps.isEmpty {
        print("                   taps at: " + r.taps.map { String(format: "%.2f(%.1f)", $0.time, $0.strength) }.joined(separator: " "))
    }
    if phase.name == pathPhase {
        for (i, p) in r.path.enumerated() where i % 6 == 0 {
            print(String(format: "  path %.3f %.1f %.1f", Double(i) / 120, p.x, p.y))
        }
    }
}
