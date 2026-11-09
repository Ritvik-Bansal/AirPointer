import AppKit
import SwiftUI

// DIRECTION CONTRACT
//
// THESIS: The window is a small living room: your case on the floor at the bottom, a screen
// on the wall above it, and the dot you are aiming lit on that screen. It refuses the
// Settings sidebar of grouped rows.
// OWN-WORLD: Cool matte white (deep blue-black at night) with one glossy object, the case.
// One sky-blue keyline colour, white pills and panels with blue outlines, rounded pebble
// forms, a dot-matrix screen, SF Rounded for display.
// STORY: I see my hand mirrored; I understand that aiming moves the dot and a tap clicks;
// I tune the feel and get back to work.
// FIRST VIEWPORT: an 880x672 window (640 of content running up under the title bar). A centred stage: the dot screen (360 wide) showing the real cursor
// as lit dots, the case in 3D beneath it, facing you with both AirPods docked and turning as
// yours turns, one status line, an on/off pill top right. Along the bottom, four large
// pills: Feel, Taps, Setup, Signal. Choosing one slides the stage left and opens its
// controls on the right.
// FORM: Point at the Screen (mid-2000s motion-controller setup screens), first on the
// grounded list, chosen by the user over the roll; its mini screen is the dot display the
// user asked to keep from Pocket Radio. Seed 9ca91a4f; the round is recorded in
// .impeccable/questions/direction-round.md.
// FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review,
// the verdict, DESIGN.md, and every shipping raster carrying its provenance.

/// The palette. One accent, used only for what is live or can be acted on.
enum Theme {
    /// Window ground, top of the stage.
    static let stage = Color(light: 0xF4F7FA, dark: 0x0E151D)
    /// Bottom of the stage, a shade deeper so the floor recedes.
    static let stageFloor = Color(light: 0xE4EBF2, dark: 0x090E14)
    /// Raised surfaces: pills, the settings panel, the screen's glass.
    static let panel = Color(light: 0xFFFFFF, dark: 0x16202B)
    static let ink = Color(light: 0x1F2A36, dark: 0xEAF2F8)
    /// Secondary text, tinted toward the stage rather than neutral grey.
    static let inkSoft = Color(light: 0x566575, dark: 0x9FB2C4)
    static let hairline = Color(light: 0xD3DCE5, dark: 0x27343F)
    /// The one colour: outlines, lit dots, the click ring.
    static let keyline = Color(light: 0x2FA8E6, dark: 0x48B9F5)
    /// Filled controls and accent text. Deeper than the keyline in light mode so white text
    /// and small labels clear 4.5:1.
    static let action = Color(light: 0x0B74B4, dark: 0x48B9F5)
    static let onAction = Color(light: 0xFFFFFF, dark: 0x06202F)
    /// Needs attention. Never decorative.
    static let warn = Color(light: 0xA85A07, dark: 0xF5B041)
    /// An unlit dot on the screen.
    static let dotOff = Color(light: 0xCBD5DE, dark: 0x2B3947)

    /// A cast shadow. Dark in both appearances: ink-tinted by day, near-black and stronger
    /// at night, where a pale shadow would read as a glow.
    static func shadow(_ strength: Double) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 0, green: 0.01, blue: 0.03, alpha: min(1, strength * 4.5))
                : NSColor(hex: 0x1F2A36).withAlphaComponent(strength)
        })
    }

    static let panelRadius: CGFloat = 22
    static let quick = Animation.easeOut(duration: 0.18)
    /// Settles fast and without bounce: the one curve used for layout moves.
    static let settle = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.42)
}

/// Type roles. Rounded for display, plain for reading, tabular wherever a number changes.
enum Typo {
    static let display = Font.system(size: 30, weight: .bold, design: .rounded)
    static let title = Font.system(size: 20, weight: .bold, design: .rounded)
    static let pill = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let heading = Font.system(size: 14, weight: .semibold)
    static let body = Font.system(size: 14)
    static let caption = Font.system(size: 12.5)
    static let figure = Font.system(size: 13, weight: .medium, design: .rounded).monospacedDigit()
}

extension Color {
    /// A colour that follows the window's appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
