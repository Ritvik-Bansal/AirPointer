import CoreGraphics
import Foundation

/// Hands finished frames to ffmpeg, which writes the video. Nothing is kept on disk but the result.
final class Encoder {
    private let process = Process()
    private let pipe = Pipe()
    private let context: CGContext
    let width: Int
    let height: Int

    init(url: URL, width: Int, height: Int, fps: Int) throws {
        self.width = width
        self.height = height
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { throw CocoaError(.fileWriteUnknown) }
        context = ctx

        guard FileManager.default.isExecutableFile(atPath: Tool.path) else {
            throw Failure("ffmpeg is needed and was not found. Install it with: brew install ffmpeg")
        }
        process.executableURL = URL(fileURLWithPath: Tool.path)
        process.arguments = [
            "-hide_banner", "-loglevel", "error", "-y",
            "-f", "rawvideo", "-pix_fmt", "bgra", "-s", "\(width)x\(height)", "-r", "\(fps)", "-i", "-",
            "-c:v", "libx264", "-preset", "slow", "-crf", "15", "-pix_fmt", "yuv420p",
            "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
            "-movflags", "+faststart", url.path,
        ]
        process.standardInput = pipe
        try process.run()
    }

    func append(_ image: CGImage) {
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return }
        pipe.fileHandleForWriting.write(Data(bytesNoCopy: data, count: width * height * 4, deallocator: .none))
    }

    func finish() {
        try? pipe.fileHandleForWriting.close()
        process.waitUntilExit()
    }
}
