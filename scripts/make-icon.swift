// Draws the app icon at every size the asset catalog needs.
//   swift scripts/make-icon.swift App/Assets.xcassets/AppIcon.appiconset
//
// The committed PNGs each carry a note of where they came from (this script), embedded as
// PNG text. Redrawing them drops that note; the design tooling's embed-prompt script puts it back.
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func draw(size: Int) -> Data {
    let s = CGFloat(size)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: s / 1024, y: s / 1024)

    // The standard macOS icon plate: an 824-point rounded square, centred, with a soft shadow.
    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    let platePath = CGPath(roundedRect: plate, cornerWidth: 186, cornerHeight: 186, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x0A2A40, 0.35))
    ctx.addPath(platePath)
    ctx.setFillColor(color(0x1B8FD8))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(platePath)
    ctx.clip()
    let sky = CGGradient(colorsSpace: space, colors: [color(0x1784CC), color(0x3FB0EE), color(0x7FD2FA)] as CFArray, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: plate.minY), end: CGPoint(x: 0, y: plate.maxY), options: [])

    // The dot screen: a field of dim dots, with the aimed one lit and a short trail behind it.
    let cols = 9, rows = 5
    let pitch: CGFloat = 74
    let originX = 512 - pitch * CGFloat(cols - 1) / 2
    let originY: CGFloat = 560
    let lit: [(Int, Int, CGFloat)] = [(6, 3, 1.0), (5, 2, 0.62), (4, 2, 0.4), (3, 1, 0.26)]
    for j in 0..<rows {
        for i in 0..<cols {
            let c = CGPoint(x: originX + CGFloat(i) * pitch, y: originY + CGFloat(j) * pitch)
            let level = lit.first { $0.0 == i && $0.1 == j }?.2 ?? 0
            let r: CGFloat = 11 + 13 * level
            if level > 0.9 {
                ctx.setFillColor(color(0xFFFFFF, 0.28))
                ctx.fillEllipse(in: CGRect(x: c.x - r - 16, y: c.y - r - 16, width: (r + 16) * 2, height: (r + 16) * 2))
            }
            ctx.setFillColor(color(0xFFFFFF, 0.26 + 0.74 * level))
            ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }
    }

    // The case: a white pebble seen from the hand's side, lid seam across it, tipped toward the lit dot.
    ctx.translateBy(x: 500, y: 352)
    ctx.rotate(by: 0.20)
    let body = CGRect(x: -236, y: -150, width: 472, height: 300)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 118, cornerHeight: 118, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: color(0x083A5E, 0.45))
    ctx.addPath(bodyPath)
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let shade = CGGradient(colorsSpace: space, colors: [color(0xD3DEE8), color(0xF6F9FC), color(0xFFFFFF)] as CFArray, locations: [0, 0.45, 1])!
    ctx.drawLinearGradient(shade, start: CGPoint(x: 0, y: body.minY), end: CGPoint(x: 0, y: body.maxY), options: [])
    // Lid seam.
    ctx.setFillColor(color(0xB9C7D4))
    ctx.fill(CGRect(x: body.minX, y: 44, width: body.width, height: 7))
    // Charging port and speaker holes along the bottom edge.
    ctx.setFillColor(color(0x2A3541))
    let port = CGRect(x: -52, y: -128, width: 104, height: 26)
    ctx.addPath(CGPath(roundedRect: port, cornerWidth: 13, cornerHeight: 13, transform: nil))
    ctx.fillPath()
    for side in [CGFloat(-1), 1] {
        for k in 0..<3 {
            let x = side * (96 + CGFloat(k) * 30)
            ctx.fillEllipse(in: CGRect(x: x - 7, y: -122, width: 14, height: 14))
        }
    }
    ctx.restoreGState()
    ctx.restoreGState()

    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])!
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
for size in [16, 32, 64, 128, 256, 512, 1024] {
    try draw(size: size).write(to: URL(fileURLWithPath: "\(out)/icon_\(size).png"))
}
print("wrote icons to \(out)")
