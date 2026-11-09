import PointerKit

// The film poses the case by hand, one frame at a time, so it has no live runtime. These
// stand in for the two app types the shared case code refers to.

struct LiveState {
    var telemetry = Telemetry()
    var isStreaming = false
    var tapCount = 0
    var lastTapStrength = 0.0
}

final class PointerRuntime {
    func snapshot() -> LiveState { LiveState() }
}
