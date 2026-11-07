import Foundation

public enum MouseButton: Int, Sendable, Codable, Equatable {
    case left, right, middle
}

/// What the engine asks the host to do.
public enum PointerEvent: Sendable, Equatable {
    /// A tap was felt. Sent before it resolves into a click, for on-screen feedback.
    case tap(strength: Double)
    /// Press and release. `count` is the click count the system should see (2 = double-click).
    case click(MouseButton, count: Int)
    case buttonDown(MouseButton)
    case buttonUp(MouseButton)
}

/// How taps become clicks.
public enum TapScheme: String, Codable, Sendable, CaseIterable {
    /// Two taps click; one tap on its own is a right-click.
    case doubleTapClicks
    /// Every tap clicks. Right-click is Control-tap, as with a one-button mouse.
    case singleTapClicks
}

/// What a third quick tap does in the double-tap scheme.
public enum ThirdTapAction: String, Codable, Sendable, CaseIterable {
    /// Clicks again, which the system reads as a double-click.
    case doubleClick
    /// Presses and holds, for dragging. The next tap lets go.
    case dragLock
}

/// Groups taps into clicks.
///
/// The double-tap scheme is arranged so the common action never waits: the click fires on the
/// second tap itself, and each further tap in the run clicks again (three taps make a
/// double-click). Only a lone tap has to wait out the window before it becomes a right-click.
public struct TapSequencer: Sendable {
    public var scheme: TapScheme
    /// Longest gap between taps of one gesture, seconds.
    public var window: Double
    public var thirdTap: ThirdTapAction

    private var pendingSince: Double?
    private var lastTap: Double?
    private var clicksInRun = 0
    public private(set) var isDragging = false

    public init(scheme: TapScheme = .doubleTapClicks, window: Double = 0.4, thirdTap: ThirdTapAction = .doubleClick) {
        self.scheme = scheme
        self.window = window
        self.thirdTap = thirdTap
    }

    /// True while a lone tap is waiting to see whether a second one follows.
    public var isPending: Bool { pendingSince != nil }

    /// True when a tap at `t` would continue a gesture already under way rather than start one.
    public func isMidGesture(at t: Double) -> Bool {
        guard let last = lastTap, t - last <= window else { return false }
        return pendingSince != nil || clicksInRun >= 1
    }

    /// Calls off the gesture in progress without clicking. A held drag stays held.
    public mutating func cancel() {
        pendingSince = nil
        lastTap = nil
        clicksInRun = 0
    }

    public mutating func reset() -> [PointerEvent] {
        pendingSince = nil
        lastTap = nil
        clicksInRun = 0
        guard isDragging else { return [] }
        isDragging = false
        return [.buttonUp(.left)]
    }

    public mutating func tap(at t: Double) -> [PointerEvent] {
        if isDragging {
            isDragging = false
            pendingSince = nil
            lastTap = nil
            clicksInRun = 0
            return [.buttonUp(.left)]
        }
        let continuesRun = lastTap.map { t - $0 <= window } ?? false
        lastTap = t

        switch scheme {
        case .singleTapClicks:
            clicksInRun = continuesRun ? clicksInRun + 1 : 1
            return [.click(.left, count: clicksInRun)]

        case .doubleTapClicks:
            if pendingSince != nil, continuesRun {
                pendingSince = nil
                clicksInRun = 1
                return [.click(.left, count: 1)]
            }
            if clicksInRun >= 1, continuesRun {
                if thirdTap == .dragLock, clicksInRun == 1 {
                    isDragging = true
                    clicksInRun = 0
                    return [.buttonDown(.left)]
                }
                clicksInRun += 1
                return [.click(.left, count: clicksInRun)]
            }
            pendingSince = t
            clicksInRun = 0
            return []
        }
    }

    /// Call as sensor time advances. Resolves a lone tap once its window has passed.
    public mutating func advance(to t: Double) -> [PointerEvent] {
        if let last = lastTap, t - last > window { clicksInRun = 0 }
        guard let p = pendingSince, t - p > window else { return [] }
        pendingSince = nil
        return [.click(.right, count: 1)]
    }
}
