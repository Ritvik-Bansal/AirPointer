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

