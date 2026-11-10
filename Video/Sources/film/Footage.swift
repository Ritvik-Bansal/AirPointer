import AVFoundation
import Foundation
import SwiftUI

/// Says something to whoever is rendering, without touching the picture.
func note(_ text: String) {
    FileHandle.standardError.write(Data(("  " + text + "\n").utf8))
}

/// Runs asynchronous work to its end from ordinary code. The work must not need the main thread.
func blocking<T>(_ work: @escaping () async throws -> T) throws -> T {
    let waited = Waited<T>()
    let done = DispatchSemaphore(value: 0)
    Task.detached {
        do { waited.result = .success(try await work()) } catch { waited.result = .failure(error) }
        done.signal()
    }
    done.wait()
    return try waited.result!.get()
}

private final class Waited<T>: @unchecked Sendable {
    var result: Result<T, Error>?
}

/// Reads a clip for the film: upright, cropped to fill the slot, and in step with the film's
/// own clock whatever rate the clip was filmed at.
///
/// The system's own video reader does the work. A clip filmed sideways arrives the right way
/// up, and a phone's HDR footage arrives toned down to the ordinary range the rest of the
/// film is in, as QuickTime shows it on an ordinary display.
final class ClipReader {
    private var reader: AVAssetReader?
    private var output: AVAssetReaderVideoCompositionOutput?
    private let canvas: CGContext?
    private let size: CGSize
    private let fps: Double
    /// The moment in the clip that belongs to the film frame `firstIndex`.
    private let start: Double
    private let firstIndex: Int
    private var shown: CGImage?
    /// The next picture in the clip, decoded but not yet due.
    private var waiting: (pixels: CVPixelBuffer, time: Double)?
    private var finished = false
    private(set) var next: Int

    private static let space = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let layout = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

    init(url: URL, from: Double, size: CGSize, fps: Int, firstIndex: Int) {
        self.size = size
        self.fps = Double(fps)
        self.firstIndex = firstIndex
        start = max(0, from)
        next = firstIndex
        canvas = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: Self.space, bitmapInfo: Self.layout
        )
        canvas?.interpolationQuality = .high
        do {
            let asset = AVURLAsset(url: url)
            let (track, composition) = try blocking {
                guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                // The composition is what turns the picture upright.
                return (track, try await AVMutableVideoComposition.videoComposition(withPropertiesOf: asset))
            }
            let reader = try AVAssetReader(asset: asset)
            // Asking for ordinary colour here, and only here, is what makes the system convert
            // HDR footage. (Set on the composition as well, it converts nothing: measured.)
            let output = AVAssetReaderVideoCompositionOutput(videoTracks: [track], videoSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                AVVideoColorPropertiesKey: [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
                ],
            ])
            output.videoComposition = composition
            output.alwaysCopiesSampleData = false
            reader.add(output)
            reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), duration: .positiveInfinity)
            guard reader.startReading() else { throw reader.error ?? CocoaError(.fileReadUnknown) }
            self.reader = reader
            self.output = output
        } catch {
            finished = true
            note("\(url.lastPathComponent) could not be read: \(error.localizedDescription)")
        }
    }

    /// The picture for the film frame `index`: the latest one in the clip that is due by then.
    /// Frames must be asked for in order. When the clip runs out, its last picture holds.
    func frame(_ index: Int) -> CGImage? {
        // Due by the middle of the film frame, so that a clip at the film's own rate is not
        // thrown a frame out by rounding.
        let due = start + (Double(index - firstIndex) + 0.5) / fps
        var latest: CVPixelBuffer?
        while !finished {
            if waiting == nil {
                guard let sample = output?.copyNextSampleBuffer(), let pixels = CMSampleBufferGetImageBuffer(sample) else {
                    finished = true
                    break
                }
                waiting = (pixels, CMSampleBufferGetPresentationTimeStamp(sample).seconds)
            }
            // The very first picture is shown at once, even if the clip starts a moment late.
            guard let ready = waiting, ready.time <= due || (shown == nil && latest == nil) else { break }
            latest = ready.pixels
            waiting = nil
        }
        if let latest { shown = picture(from: latest) ?? shown }
        next = index + 1
        return shown
    }

    /// The frame scaled to fill the slot, cropping whatever falls outside it.
    private func picture(from pixels: CVPixelBuffer) -> CGImage? {
        CVPixelBufferLockBaseAddress(pixels, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
        let width = CVPixelBufferGetWidth(pixels), height = CVPixelBufferGetHeight(pixels)
        let rowBytes = CVPixelBufferGetBytesPerRow(pixels)
        guard let canvas, let base = CVPixelBufferGetBaseAddress(pixels),
              let provider = CGDataProvider(dataInfo: nil, data: base, size: rowBytes * height, releaseData: { _, _, _ in }),
              // The values are kept as they are: the film is encoded in the same range the clip now is.
              let source = CGImage(
                  width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: rowBytes,
                  space: Self.space, bitmapInfo: CGBitmapInfo(rawValue: Self.layout),
                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
              )
        else { return nil }
        let scale = max(size.width / CGFloat(width), size.height / CGFloat(height))
        let drawn = CGSize(width: CGFloat(width) * scale, height: CGFloat(height) * scale)
        canvas.draw(source, in: CGRect(
            x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2,
            width: drawn.width, height: drawn.height
        ))
        return canvas.makeImage()
    }

    func stop() {
        reader?.cancelReading()
    }
}

