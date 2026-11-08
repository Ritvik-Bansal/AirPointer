import AppKit
import CoreGraphics
import PointerKit

/// Moves the real cursor and clicks, by posting the same events a mouse would.
///
/// Movement is applied as an offset from wherever the cursor already is, so the trackpad and
/// the case can be used together: whichever moved last simply carries on from there.
/// Needs Accessibility access; without it macOS drops the events silently.
final class CursorDriver {
    private let source = CGEventSource(stateID: .hidSystemState)
    /// Where this driver believes the cursor is, to a fraction of a point.
    private var position: CGPoint?
    /// The places this driver put the cursor in the last quarter second. The system applies
    /// posted events a moment later, so its reported position can trail by an event or two;
    /// a cursor found at any of these is still where we left it.
    private var recent: [(at: Double, point: CGPoint)] = []
    /// Motion asked for but too small to show yet. Saved up until it amounts to a visible move.
    private var carry = CGVector.zero
    /// Motion a screen edge refused in the last fifth of a second.
    private var refused: [(at: Double, d: CGVector)] = []
    private var deltaCarry = CGVector.zero
    private var scrollCarry = CGVector.zero
    private var held: Set<MouseButton> = []
    private var displays: [CGRect] = []
    private var displaysReadAt = 0.0

    /// When set, nothing is posted: the cursor is only imagined, starting mid-screen. Used to
    /// replay a recording without taking over the real pointer.
    var isRehearsal = false {
        didSet { if isRehearsal { position = CGPoint(x: mainBounds.midX, y: mainBounds.midY) } }
    }

    private var mainBounds: CGRect { CGDisplayBounds(CGMainDisplayID()) }
    private var now: Double { ProcessInfo.processInfo.systemUptime }

    init() {
        source?.localEventsSuppressionInterval = 0
    }

    /// Where the cursor is, in global display coordinates (origin top-left, y down): this
    /// driver's own position while the cursor is still where it put it, otherwise wherever
    /// the trackpad or mouse has taken it.
    var location: CGPoint { anchor().point }

    /// The imagined cursor's place on the main display, 0…1, while rehearsing.
    var rehearsalPoint: CGPoint? {
        guard isRehearsal, let p = position else { return nil }
        let b = mainBounds
        return CGPoint(x: (p.x - b.minX) / b.width, y: (p.y - b.minY) / b.height)
    }

    var isHoldingButton: Bool { !held.isEmpty }

    /// Moves the cursor by `d` points.
    func move(by d: Vec2) {
        guard d.x != 0 || d.y != 0 else { return }
        if isRehearsal {
            let b = mainBounds, p = position ?? CGPoint(x: b.midX, y: b.midY)
            position = CGPoint(x: min(max(p.x + d.x, b.minX), b.maxX - 1), y: min(max(p.y + d.y, b.minY), b.maxY - 1))
            return
        }
        carry.dx += d.x
        carry.dy += d.y
        // A hand holding the case still sends a tremor-sized step almost every frame. Those
        // are saved up rather than posted, which also keeps the case from tugging at a
        // cursor the trackpad is moving.
        guard hypot(carry.dx, carry.dy) >= 0.35 else { return }
        apply(carry)
        carry = .zero
    }

    /// Takes the cursor back by `d`, undoing what a tap's jolt did to it. Whatever part of
    /// that jolt a screen edge had already refused never moved the cursor, so it is not undone.
    func rewind(by d: Vec2) {
        guard !isRehearsal else {
            move(by: d)
            return
        }
        let t = now
        refused.removeAll { t - $0.at > 0.2 }
        let pushed = refused.reduce(CGVector.zero) { CGVector(dx: $0.dx + $1.d.dx, dy: $0.dy + $1.d.dy) }
        refused.removeAll()
        var back = CGVector(dx: d.x, dy: d.y)
        if pushed.dx != 0, (back.dx > 0) != (pushed.dx > 0) {
            back.dx = back.dx > 0 ? max(0, back.dx - abs(pushed.dx)) : min(0, back.dx + abs(pushed.dx))
        }
        if pushed.dy != 0, (back.dy > 0) != (pushed.dy > 0) {
            back.dy = back.dy > 0 ? max(0, back.dy - abs(pushed.dy)) : min(0, back.dy + abs(pushed.dy))
        }
        // Unposted tremor belongs to the jolt as well.
        carry = .zero
        if back.dx != 0 || back.dy != 0 { apply(back) }
    }

    func press(_ button: MouseButton, count: Int = 1) {
        post(button, down: true, count: count)
        held.insert(button)
    }

    /// - Returns: Whether the button was down.
    @discardableResult
    func release(_ button: MouseButton, count: Int = 1) -> Bool {
        guard held.contains(button) else { return false }
        post(button, down: false, count: count)
        held.remove(button)
        return true
    }

    /// Lets go of anything held. Called whenever the pointer stops, so a drag can never be left stuck.
    func releaseAll() {
        for button in held { release(button) }
    }

    func scroll(by d: Vec2) {
        if isRehearsal { return }
        scrollCarry.dx += d.x
        scrollCarry.dy += d.y
        let dx = scrollCarry.dx.rounded(.towardZero), dy = scrollCarry.dy.rounded(.towardZero)
        guard dx != 0 || dy != 0 else { return }
        scrollCarry.dx -= dx
        scrollCarry.dy -= dy
        CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2, wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0)?
            .post(tap: .cghidEventTap)
    }

    // MARK: Internals

    /// The point to act from, and whether it is this driver's own.
    private func anchor() -> (point: CGPoint, ours: Bool) {
        if isRehearsal { return (position ?? .zero, true) }
        let system = CGEvent(source: nil)?.location ?? position ?? .zero
        let t = now
        recent.removeAll { t - $0.at > 0.25 }
        if let p = position, recent.contains(where: { abs(system.x - $0.point.x) < 1.5 && abs(system.y - $0.point.y) < 1.5 }) {
            return (p, true)
        }
        return (system, false)
    }

    private func apply(_ d: CGVector) {
        let base = anchor().point
        let wanted = CGPoint(x: base.x + d.dx, y: base.y + d.dy)
        let target = clamp(wanted, from: base)
        if wanted != target {
            refused.append((now, CGVector(dx: wanted.x - target.x, dy: wanted.y - target.y)))
            if refused.count > 32 { refused.removeFirst() }
        }
        position = target
        // Pinned against an edge: nothing to show.
        guard abs(target.x - base.x) > 0.01 || abs(target.y - base.y) > 0.01 else { return }

        deltaCarry.dx += target.x - base.x
        deltaCarry.dy += target.y - base.y
        let dx = deltaCarry.dx.rounded(.towardZero), dy = deltaCarry.dy.rounded(.towardZero)
        deltaCarry.dx -= dx
        deltaCarry.dy -= dy

        let type: CGEventType = held.contains(.left) ? .leftMouseDragged
            : held.contains(.right) ? .rightMouseDragged
            : held.contains(.middle) ? .otherMouseDragged
            : .mouseMoved
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: target, mouseButton: cgButton(held.first ?? .left)) else { return }
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(dx))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(dy))
        event.post(tap: .cghidEventTap)
        remember(target)
    }

    private func remember(_ point: CGPoint) {
        recent.append((now, point))
        if recent.count > 12 { recent.removeFirst() }
    }

    private func post(_ button: MouseButton, down: Bool, count: Int) {
        if isRehearsal { return }
        let type: CGEventType = switch button {
        case .left: down ? .leftMouseDown : .leftMouseUp
        case .right: down ? .rightMouseDown : .rightMouseUp
        case .middle: down ? .otherMouseDown : .otherMouseUp
        }
        // Act from this driver's own position when the cursor is still its own: straight
        // after a rewind the system has not caught up, and its reading would put the click
        // back where the jolt threw the cursor.
        let at = anchor().point
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: at, mouseButton: cgButton(button)) else { return }
        event.setIntegerValueField(.mouseEventClickState, value: Int64(max(1, count)))
        event.post(tap: .cghidEventTap)
        position = at
        remember(at)
    }

    private func cgButton(_ b: MouseButton) -> CGMouseButton {
        switch b {
        case .left: .left
        case .right: .right
        case .middle: .center
        }
    }

    /// Keeps the cursor on a display. Sliding along an edge still works because each axis is
    /// clamped on its own.
    private func clamp(_ p: CGPoint, from base: CGPoint) -> CGPoint {
        let t = now
        if displays.isEmpty || t - displaysReadAt > 2 {
            var ids = [CGDirectDisplayID](repeating: 0, count: 16)
            var count: UInt32 = 0
            CGGetActiveDisplayList(16, &ids, &count)
            displays = ids.prefix(Int(count)).map { CGDisplayBounds($0) }
            displaysReadAt = t
        }
        if displays.contains(where: { $0.contains(p) }) { return p }
        guard let home = displays.first(where: { $0.contains(base) }) ?? displays.first else { return p }
        return CGPoint(
            x: min(max(p.x, home.minX), home.maxX - 1),
            y: min(max(p.y, home.minY), home.maxY - 1)
        )
    }
}
