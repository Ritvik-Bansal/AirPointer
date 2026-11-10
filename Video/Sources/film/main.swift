import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// Renders the AirPointer film.
//
//   film render <out.mp4> [--from <s>] [--to <s>] [--scale <1|2>] [--footage <folder>]
//   film stills <folder> <seconds> [<seconds> ...] [--footage <folder>]
//
// Clips in Video/footage named A.mov and B.mov are cut into their slots; a slot without a
// clip shows a card. A music file there is laid under the film. See Footage.swift.

@MainActor
func run() throws {
    _ = NSApplication.shared
    var args = Array(CommandLine.arguments.dropFirst())
    guard let command = args.first else {
        print("usage: film render <out.mp4> [--from s] [--to s] [--scale n] [--footage folder]  |  film stills <folder> <seconds>...")
        return
    }
    args.removeFirst()
    func option(_ name: String) -> String? {
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
        defer { args.removeSubrange(i...i + 1) }
        return args[i + 1]
    }
    let scale = option("--scale").flatMap(Double.init) ?? 1
    let from = option("--from").flatMap(Double.init) ?? 0
    let to = option("--to").flatMap(Double.init) ?? Film.At.finish
    let folder = option("--footage").map { URL(fileURLWithPath: $0) }
    let speed = option("--speed").flatMap(Double.init) ?? 1

    // This file lives at <project>/Video/Sources/film/main.swift.
    let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let film = try Film(project: project, repository: "github.com/Ritvik-Bansal/AirPointer", footage: folder, detail: scale)

    func image(at t: Double) -> CGImage? {
        let renderer = ImageRenderer(content: film.frame(at: t))
        renderer.scale = scale
        return renderer.cgImage
    }

    switch command {
    case "stills":
        guard let folder = args.first else { return }
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        for text in args.dropFirst() {
            guard let t = Double(text), let cg = image(at: t) else { continue }
            let name = String(format: "%@/t%06.2f.png", folder, t)
            try write(cg, to: URL(fileURLWithPath: name), at: t)
        }
    case "render":
        guard let out = args.first.map({ URL(fileURLWithPath: $0) }) else { return }
        let whole = from <= 0 && to >= Film.At.finish
        let sound = film.sound
        if !whole && !sound.isEmpty { note("Part of the film is being rendered, so it is left without sound.") }
        let mixing = whole && !sound.isEmpty

        // Working files stay out of the project, which lives in a folder that syncs.
        let work = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AirPointer/Film/mix-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let picture = mixing ? work.appendingPathComponent("picture.mp4") : out

        let width = Int(Look.size.width * scale), height = Int(Look.size.height * scale)
        let encoder = try Encoder(url: picture, width: width, height: height, fps: Film.fps)
        let first = Int((from * Double(Film.fps)).rounded()), last = Int((to * Double(Film.fps)).rounded())
        let started = Date()
        for frame in first..<last {
            autoreleasepool {
                if let cg = image(at: Double(frame) / Double(Film.fps)) { encoder.append(cg) }
            }
            if (frame - first) % 600 == 599 { print(String(format: "  %.0f s rendered", Double(frame + 1) / Double(Film.fps))) }
        }
        encoder.finish()
        print(String(format: "Rendered %d frames in %.0f s: %@", last - first, Date().timeIntervalSince(started), out.path))

        if mixing {
            let said = try Sound.mix(sound, picture: picture, length: Film.At.finish, work: work, to: out)
            print("Sound: \(said)")
            try? FileManager.default.removeItem(at: work)
        } else if whole {
            print("Sound: none (no music file, and no clip set to keep its sound)")
        }
        for slot in film.waiting {
            print(String(format: "Clip %@ is still a card: %@, %.1f s, from %.1f s", slot.name, slot.title, slot.duration, slot.start))
        }
    case "probe":
        // film probe <phase> <offset> <duration> [--speed n]: what a stretch of the recording
        // holds, five times a second, for choosing takes.
        guard args.count >= 3, let offset = Double(args[1]), let duration = Double(args[2]) else { return }
        for line in try film.probe(phase: args[0], offset: offset, duration: duration, speed: speed) { print(line) }
    default:
        print("unknown command \(command)")
    }
}

/// Writes a still as a PNG that says, inside the file, where it came from.
func write(_ image: CGImage, to url: URL, at t: Double) throws {
    guard let file = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    let origin = String(
        format: "The AirPointer film at %.2f s. Drawn by code (Video/Sources/film) from the app's own 3D case and from recorded motion replayed through the app's engine. No generated imagery.", t
    )
    let properties: [CFString: Any] = [
        kCGImagePropertyPNGDictionary: [kCGImagePropertyPNGDescription: origin, kCGImagePropertyPNGSoftware: "AirPointer film"],
    ]
    CGImageDestinationAddImage(file, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(file) else { throw CocoaError(.fileWriteUnknown) }
}

do {
    try MainActor.assumeIsolated { try run() }
} catch {
    FileHandle.standardError.write(Data("film: \(error.localizedDescription)\n".utf8))
    exit(1)
}
