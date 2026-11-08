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

