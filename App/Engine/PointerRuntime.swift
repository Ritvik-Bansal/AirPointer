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

    // MARK: Engine queue

    private func quiesce() {
        cursor.releaseAll()
        for event in engine.reset() { perform(event) }
    }

    private func handle(_ s: MotionSample) {
        recorder?.write(s)

        let out = engine.ingest(s)
        if out.snap != .zero, outputEnabled { cursor.rewind(by: out.snap) }
        var tapped: Double?
        for event in out.events {
            if case .tap(let strength) = event { tapped = strength }
            perform(event)
        }

        // Stream statistics.
        rateWindowCount += 1
        var rate: Double?
        if s.arrival - rateWindowStart >= 0.5 {
            if rateWindowStart > 0 { rate = Double(rateWindowCount) / (s.arrival - rateWindowStart) }
            rateWindowStart = s.arrival
            rateWindowCount = 0
        }
        let offset = s.arrival - s.timestamp
        clockOffset = min(offset, (clockOffset ?? offset) + 0.00004)
        let lateness = (offset - (clockOffset ?? offset)) * 1000

        // Calibration finishing is the engine clearing its calibrator.
        let calibrating = engine.calibrator != nil
        if hadCalibrator, !calibrating {
            hadCalibrator = false
            let learned = engine.calibration
            emit(.calibrated(learned))
        }

        let t = engine.telemetry
        let tap = tapped
        let newRate = rate
        let imagined = cursor.rehearsalPoint
        let calState = engine.calibrator?.state
        let calProblem = engine.calibrator?.problem
        state.withLock { live in
            live.telemetry = t
            live.lastSample = s.arrival
            if let newRate { live.sampleRate = newRate }
            live.rehearsalCursor = imagined
            live.deliveryJitter += (lateness - live.deliveryJitter) * 0.05
            live.calibration = calState
            live.calibrationProblem = calProblem
            live.history.append(SignalPoint(yaw: Float(t.yaw), pitch: Float(t.pitch), roll: Float(t.roll), tapLevel: Float(t.tapLevel)))
            if live.history.count > 300 { live.history.removeFirst(live.history.count - 300) }
            if let tap {
                live.tapCount += 1
                live.lastTapStrength = tap
                live.lastTapAt = s.arrival
            }
        }
        ensureTimer()
    }

    private func perform(_ event: PointerEvent) {
        switch event {
        case .tap(let strength):
            emit(.tap(strength: strength))
        case .click(let button, let count):
            guard outputEnabled else { return }
            afterAnyClickInFlight {
                self.cursor.press(button, count: count)
                // A real button is down for a moment; some apps ignore a press and release
                // that land in the same instant. The cursor does not move while it is down.
                self.clickDownUntil = ProcessInfo.processInfo.systemUptime + 0.012
                self.emit(.click(button, count: count, at: self.cursor.location))
                self.queue.asyncAfter(deadline: .now() + 0.012) { self.cursor.release(button, count: count) }
            }
        case .buttonDown(let button):
            guard outputEnabled else { return }
            afterAnyClickInFlight {
                self.cursor.press(button)
                self.emit(.dragBegan(at: self.cursor.location))
            }
        case .buttonUp(let button):
            afterAnyClickInFlight {
                if self.cursor.release(button) { self.emit(.dragEnded(at: self.cursor.location)) }
            }
        }
    }

    /// Runs `action` now, or just after the click in progress has let go, so one click's
    /// release can never land on the next one's press.
    private func afterAnyClickInFlight(_ action: @escaping () -> Void) {
        let wait = clickDownUntil + 0.006 - ProcessInfo.processInfo.systemUptime
        if wait > 0 {
            queue.asyncAfter(deadline: .now() + wait) { self.afterAnyClickInFlight(action) }
        } else {
            action()
        }
    }

    private func emit(_ event: RuntimeEvent) {
        guard let onEvent else { return }
        DispatchQueue.main.async { MainActor.assumeIsolated { onEvent(event) } }
    }

    /// The frame timer runs only while samples are arriving.
    private func ensureTimer() {
        guard timer == nil else { return }
        // 120 a second covers every Mac display; on a 60 Hz screen the extra ticks cost nothing visible.
        let t = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        t.schedule(deadline: .now(), repeating: 1.0 / 120, leeway: .microseconds(500))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let frame = engine.frame(now: now)
        if outputEnabled, now >= clickDownUntil {
            cursor.move(by: frame.move)
            if frame.scroll != .zero { cursor.scroll(by: frame.scroll) }
        }
        let last = state.withLock { $0.lastSample }
        if now - last > 0.8 {
            // The stream has stopped: the lid closed or the AirPods dropped. Let go of
            // everything and stop ticking until samples return.
            timer?.cancel()
            timer = nil
            quiesce()
            rateWindowStart = 0
            rateWindowCount = 0
            clockOffset = nil
            state.withLock {
                $0.sampleRate = 0
                $0.telemetry.velocity = .zero
                $0.telemetry.holding = false
            }
        }
    }
}

/// Writes the motion stream to a plain-text trace that `pointer-replay` and the tests can read.
final class TraceRecorder {
    private let handle: FileHandle?
    private let started = ProcessInfo.processInfo.systemUptime

    init(url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try? FileHandle(forWritingTo: url)
    }

    func write(_ s: MotionSample) {
        var relative = s
        relative.arrival = s.arrival - started
        line(MotionTrace.line(for: relative))
    }

    func mark(phase: String, begin: Bool) {
        line(String(format: "%.4f PHASE %@ %@", ProcessInfo.processInfo.systemUptime - started, begin ? "begin" : "end", phase))
    }

    func close() { try? handle?.close() }

    private func line(_ text: String) {
        handle?.write(Data((text + "\n").utf8))
    }
}
