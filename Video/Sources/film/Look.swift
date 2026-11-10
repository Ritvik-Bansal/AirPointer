import SwiftUI

/// The film's look: the app's night palette, flat. No gradients, no glows, no shadows.
/// The only shading anywhere is the light falling on the case itself.
enum Look {
    /// The frame everything is laid out in. Output can be scaled up from it.
    static let size = CGSize(width: 1920, height: 1080)

    static let wall = Color(hex: 0x0E151D)
    static let floor = Color(hex: 0x090E14)
    static let panel = Color(hex: 0x16202B)
    static let ink = Color(hex: 0xEAF2F8)
    static let soft = Color(hex: 0x9FB2C4)
    static let key = Color(hex: 0x48B9F5)
    static let hairline = Color(hex: 0x2A3947)
    static let dotOff = Color(hex: 0x2B3947)
    /// An unlit dot that is part of a line drawn across a display.
    static let dotLine = Color(hex: 0x566A7D)

    /// Left and right margin of every text block.
    static let margin: CGFloat = 150
    /// Where the wall meets the floor.
    static let horizon: CGFloat = 742

    // Nothing is set smaller than 32: embedded in a web page the film is shown at under half
    // its size, and 32 is the least that still reads there.
    static func headline(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static let sub = Font.system(size: 37, weight: .regular)
    static let label = Font.system(size: 32, weight: .semibold, design: .rounded)
    static let small = Font.system(size: 32, weight: .regular)
    static func figure(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded).monospacedDigit() }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}
