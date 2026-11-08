import AppKit
import QuartzCore

/// A ring drawn at the cursor whenever the pointer clicks.
///
/// A tap on the case has no click of its own to feel or hear, so this is the confirmation
/// that the Mac received one, and which kind. The window ignores the mouse entirely and
/// floats above everything, including full-screen apps.
@MainActor
final class ClickHUD {
    enum Kind {
        /// One ring: a click.
        case click
        /// Two rings, one chasing the other: a double-click.
        case double
        /// A dashed ring: a right-click.
        case secondary
        /// A ring closing inward: the button is now held for a drag.
        case grab
    }

    private let size: CGFloat = 132
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    /// - Parameter at: Cursor position in global display coordinates (origin top-left).
    func ring(at point: CGPoint, kind: Kind) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        guard let host = panel.contentView?.layer else { return }

        // Flip to AppKit's bottom-left origin on the primary display.
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        panel.setFrameOrigin(NSPoint(x: point.x - size / 2, y: top - point.y - size / 2))
        panel.orderFrontRegardless()

        host.sublayers?.forEach { $0.removeFromSuperlayer() }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        switch kind {
        case .click:
            host.addSublayer(ringLayer(delay: 0, from: 7, to: 30, dashed: false, still: reduceMotion))
        case .double:
            host.addSublayer(ringLayer(delay: 0, from: 7, to: 30, dashed: false, still: reduceMotion))
            host.addSublayer(ringLayer(delay: 0.09, from: 7, to: 46, dashed: false, still: reduceMotion))
        case .secondary:
            host.addSublayer(ringLayer(delay: 0, from: 7, to: 30, dashed: true, still: reduceMotion))
        case .grab:
            host.addSublayer(ringLayer(delay: 0, from: 34, to: 9, dashed: false, still: reduceMotion))
        }

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak panel] in panel?.orderOut(nil) }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        let view = NSView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        view.wantsLayer = true
        panel.contentView = view
        return panel
    }

    /// A keyline-blue ring with a white edge under it, so it reads on any background.
    private func ringLayer(delay: Double, from: CGFloat, to: CGFloat, dashed: Bool, still: Bool) -> CALayer {
        let group = CALayer()
        group.frame = CGRect(x: 0, y: 0, width: size, height: size)
        let center = CGPoint(x: size / 2, y: size / 2)

        func stroke(_ color: NSColor, width: CGFloat) -> CAShapeLayer {
            let layer = CAShapeLayer()
            layer.frame = group.bounds
            layer.fillColor = nil
            layer.strokeColor = color.cgColor
            layer.lineWidth = width
            if dashed { layer.lineDashPattern = [5, 4.5] }
            layer.path = CGPath(ellipseIn: CGRect(x: center.x - to, y: center.y - to, width: to * 2, height: to * 2), transform: nil)
            return layer
        }
        let halo = stroke(NSColor.white.withAlphaComponent(0.9), width: 5)
        let ring = stroke(NSColor(Theme.keyline), width: 2.5)
        group.addSublayer(halo)
        group.addSublayer(ring)
        group.opacity = 0

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 1, 1, 0]
        fade.keyTimes = [0, 0.12, 0.45, 1]
        let duration = 0.46
        var animations: [CAAnimation] = [fade]
        if !still {
            let grow = CABasicAnimation(keyPath: "transform.scale")
            grow.fromValue = from / to
            grow.toValue = 1
            // Fast out of the gate, settling at full size: an exponential ease-out.
            grow.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            animations.append(grow)
        }
        let all = CAAnimationGroup()
        all.animations = animations
        all.duration = duration
        all.beginTime = CACurrentMediaTime() + delay
        all.fillMode = .backwards
        all.isRemovedOnCompletion = true
        group.add(all, forKey: "ring")
        return group
    }
}
