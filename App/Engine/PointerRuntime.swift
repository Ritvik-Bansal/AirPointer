import AppKit
import Foundation
import os
import PointerKit

/// Everything the interface draws from, copied out of the engine under a lock.
struct LiveState: Sendable {
    var telemetry = Telemetry()
    /// Uptime of the newest sample; zero before the first one.
    var lastSample = 0.0
    var sampleRate = 0.0
    /// How late a typical sample runs behind the fastest delivery seen, milliseconds.
    var deliveryJitter = 0.0
    var calibration: AxisCalibrator.State?
    var calibrationProblem: AxisCalibrator.Problem?
    /// Recent signal for the trace view, oldest first.
    var history: [SignalPoint] = []
    /// Bumped on every tap, so views can flash without missing one between frames.
    var tapCount = 0
    var lastTapStrength = 0.0
    var lastTapAt = 0.0
    /// The imagined cursor, 0…1 on the main display, while a recording is being replayed.
    var rehearsalCursor: CGPoint?

    var isStreaming: Bool { lastSample > 0 && ProcessInfo.processInfo.systemUptime - lastSample < 0.4 }
}

struct SignalPoint: Sendable {
    var yaw: Float
    var pitch: Float
    var roll: Float
    var tapLevel: Float
}

enum RuntimeEvent: Sendable {
    case tap(strength: Double)
    case click(MouseButton, count: Int, at: CGPoint)
    case dragBegan(at: CGPoint)
    case dragEnded(at: CGPoint)
    case calibrated(GripCalibration)
}

/// Runs the pointer: owns the engine, the frame timer and the cursor, all on one serial queue
/// so the engine needs no locking of its own.
final class PointerRuntime: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.ritvikbansal.AirPointer.engine", qos: .userInteractive)
    private(set) lazy var source = MotionSource(queue: queue)

    private var engine = PointerEngine()
    private let cursor = CursorDriver()
    private var timer: DispatchSourceTimer?
    private var outputEnabled = false
    private var recorder: TraceRecorder?

    /// Host time until which a click's button is down. The cursor stays put meanwhile, and
    /// the next press waits its turn.
    private var clickDownUntil = 0.0

    private var rateWindowStart = 0.0
    private var rateWindowCount = 0
    private var clockOffset: Double?
    private var hadCalibrator = false

    private let state = OSAllocatedUnfairLock(initialState: LiveState())

    /// Delivered on the main queue.
    var onEvent: (@MainActor (RuntimeEvent) -> Void)?

    init() {
        source.onSample = { [weak self] sample in self?.handle(sample) }
    }

    // MARK: Control (call from any thread)

    func start() { source.start() }

    func stop() {
        guard source.isRunning else { return }
        source.stop()
        queue.async { self.quiesce() }
    }

    /// Allows or forbids moving the cursor and clicking. Samples keep flowing either way, so
    /// the interface stays live while the pointer itself is paused.
    func setOutput(enabled: Bool) {
        queue.async {
            guard self.outputEnabled != enabled else { return }
            self.outputEnabled = enabled
            if enabled {
                // Taps made while the pointer was off count for nothing now.
                self.cursor.releaseAll()
                _ = self.engine.cancelGestures()
            } else {
                self.quiesce()
            }
        }
    }

    func apply(_ settings: EngineSettings) {
        queue.async { self.engine.settings = settings }
    }

    func apply(_ calibration: GripCalibration) {
        queue.async { self.engine.calibration = calibration }
    }

    func beginCalibration() {
        queue.async {
            self.cursor.releaseAll()
            self.engine.beginCalibration()
            self.hadCalibrator = true
        }
    }

    func cancelCalibration() {
        queue.async {
            self.engine.cancelCalibration()
            self.hadCalibrator = false
            self.state.withLock {
                $0.calibration = nil
                $0.calibrationProblem = nil
            }
        }
    }

    func snapshot() -> LiveState { state.withLock { $0 } }

    /// Lets go of anything held, now, before returning. For when the app is quitting.
    func shutdown() {
        queue.sync { cursor.releaseAll() }
    }

    /// Plays a recorded trace through the engine in real time, on a loop, in place of the
    /// AirPods. The real cursor is left alone; an imagined one is tracked instead.
    func rehearse(_ trace: MotionTrace) {
        guard !trace.samples.isEmpty else { return }
        queue.async { self.cursor.isRehearsal = true }
        let thread = Thread { [weak self] in
            var shift = 0.0
            while true {
                var previous: MotionSample?
                for sample in trace.samples {
                    guard let self else { return }
                    if let p = previous {
                        // Keep the recording's own rhythm, but do not sit through long silences.
                        Thread.sleep(forTimeInterval: min(max(sample.arrival - p.arrival, 0), 2.5))
                    }
                    previous = sample
                    var shifted = sample
                    shifted.timestamp = sample.timestamp + shift
                    shifted.arrival = ProcessInfo.processInfo.systemUptime
                    let live = shifted
                    self.queue.async { self.handle(live) }
                }
                // Next pass carries on after this one, with a gap long enough to read as a reconnect.
                shift += (trace.samples.last!.timestamp - trace.samples.first!.timestamp) + 5
                Thread.sleep(forTimeInterval: 1.5)
            }
        }
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    func startRecording(to url: URL) {
        queue.async { self.recorder = TraceRecorder(url: url) }
    }

    func mark(phase: String, begin: Bool) {
        queue.async { self.recorder?.mark(phase: phase, begin: begin) }
    }

    func stopRecording() {
        queue.async {
            self.recorder?.close()
            self.recorder = nil
        }
    }

}

