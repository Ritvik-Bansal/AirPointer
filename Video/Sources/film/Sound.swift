import AVFoundation
import Foundation

/// The film's sound: music under everything, and the sound of any clip that keeps its own.
/// With neither, the film has no sound track at all, and says everything in pictures.
enum Sound {
    /// A clip's sound, placed on the film's timeline.
    struct Piece {
        let clip: URL
        /// Seconds into the clip.
        let from: Double
        /// Seconds into the film.
        let start: Double
        let duration: Double
    }

    struct Plan {
        var music: (url: URL, start: Double)?
        var pieces: [Piece] = []
        var isEmpty: Bool { music == nil && pieces.isEmpty }
    }

    /// How loud the music sits, in LUFS (the broadcast measure of loudness; -16 is the usual
    /// level for video on the web), and how loud a clip's own sound is brought to.
    static let musicLevel = -16.0
    static let clipLevel = -19.0
    /// How far the music drops while a clip with sound plays: to 35%, about 9 dB down.
    static let dip = 0.65
    /// Nothing leaves louder than this, 1.5 dB under full scale.
    static let ceiling = 0.84

    /// Adds the plan's sound to the finished picture, writing the result to `out`.
    /// Returns a line saying what went in.
    static func mix(_ plan: Plan, picture: URL, length: Double, work: URL, to out: URL) throws -> String {
        var inputs = ["-i", picture.path]
        var count = 1
        var chains = ["anullsrc=r=48000:cl=stereo,atrim=duration=\(length),aformat=sample_fmts=fltp[floor]"]
        var mixed = "[floor]"
        var said: [String] = []

        var sounding: [Piece] = []
        for (number, piece) in plan.pieces.enumerated() {
            let raw = work.appendingPathComponent("clip\(number).pcm")
            guard try extract(piece, to: raw) else {
                note("\(piece.clip.lastPathComponent) has no sound to keep.")
                continue
            }
            let source = ["-f", "s16le", "-ar", "48000", "-ac", "2", "-i", raw.path]
            // Brought toward its level, but never raised far: a quiet room should stay a quiet room.
            let gain = loudness(of: source).map { min(12, max(-12, clipLevel - $0)) } ?? 0
            inputs += source
            chains.append(
                "[\(count):a]aformat=sample_fmts=fltp:channel_layouts=stereo,volume=\(text(gain))dB,"
                    + "afade=t=in:st=0:d=0.25,afade=t=out:st=\(text(max(0, piece.duration - 0.35))):d=0.35,"
                    + "adelay=\(Int((piece.start * 1000).rounded())):all=1[clip\(number)]"
            )
            mixed += "[clip\(number)]"
            count += 1
            sounding.append(piece)
            said.append(String(format: "the sound of %@ (%+.0f dB)", piece.clip.lastPathComponent, gain))
        }

        if let music = plan.music {
            let source = ["-ss", text(music.start), "-t", text(length), "-i", music.url.path]
            let total = (try? blocking { try await AVURLAsset(url: music.url).load(.duration) })?.seconds ?? .infinity
            // Where the music ends on the film's timeline: at the film's end, or sooner if it runs out.
            let end = min(length, total - music.start)
            if end < length - 0.05 {
                note(String(format: "%@ runs out %.1f s into the film, which is %.1f s long.", music.url.lastPathComponent, end, length))
            }
            guard let measured = loudness(of: source) else {
                throw Failure("\(music.url.lastPathComponent) could not be read as sound.")
            }
            let gain = min(24, max(-24, musicLevel - measured))
            var chain = "[\(count):a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo,volume=\(text(gain))dB,"
                + "afade=t=in:st=0:d=1.2,afade=t=out:st=\(text(max(0, end - 3))):d=3"
            if !sounding.isEmpty {
                // Under a clip that has its own sound, the music steps back, and returns after it.
                let dips = sounding.map { piece in
                    "(1-\(dip)*clip((t-\(text(piece.start - 0.5)))/0.5,0,1)*clip((\(text(piece.start + piece.duration + 0.5))-t)/0.5,0,1))"
                }
                chain += ",volume=eval=frame:volume='\(dips.joined(separator: "*"))'"
            }
            inputs += source
            chains.append(chain + "[music]")
            mixed += "[music]"
            count += 1
            let reached = measured + gain
            said.insert(String(
                format: abs(reached - musicLevel) < 0.5 ? "%@ at %.0f LUFS" : "%@ at %.0f LUFS (as far as it is brought; it was supplied at %.0f)",
                music.url.lastPathComponent, reached, measured
            ), at: 0)
        }

        guard count > 1 else {
            try? FileManager.default.removeItem(at: out)
            try FileManager.default.copyItem(at: picture, to: out)
            return "no sound"
        }
        chains.append("\(mixed)amix=inputs=\(count):normalize=0:duration=first,alimiter=limit=\(ceiling):level=0[out]")
        try Tool.ffmpeg(inputs + [
            "-filter_complex", chains.joined(separator: ";"),
            "-map", "0:v", "-map", "[out]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
            "-movflags", "+faststart", "-t", text(length), "-y", out.path,
        ])
        return said.joined(separator: ", ")
    }

    /// The loudness of a piece of sound, in LUFS, or nil when it is silent or unreadable.
    private static func loudness(of source: [String]) -> Double? {
        guard let report = try? Tool.ffmpeg(source + ["-vn", "-af", "loudnorm=print_format=json", "-f", "null", "-"]),
              let found = report.range(of: #""input_i"\s*:\s*"(-?[0-9.]+)""#, options: .regularExpression)
        else { return nil }
        let digits = report[found].split(separator: "\"").last.map(String.init) ?? ""
        guard let value = Double(digits), value > -60 else { return nil }
        return value
    }

    /// Writes a clip's sound as plain 48 kHz stereo samples for the mix. False when the clip has none.
    ///
    /// The system reads it, so whatever a phone records (spatial sound included) arrives as
    /// ordinary stereo.
    private static func extract(_ piece: Piece, to file: URL) throws -> Bool {
        let asset = AVURLAsset(url: piece.clip)
        let track: AVAssetTrack? = try blocking {
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            for track in tracks where try await track.load(.isEnabled) { return track }
            return tracks.first
        }
        guard let track else { return false }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false,
        ])
        reader.add(output)
        reader.timeRange = CMTimeRange(
            start: CMTime(seconds: max(0, piece.from), preferredTimescale: 48_000),
            duration: CMTime(seconds: piece.duration, preferredTimescale: 48_000)
        )
        guard reader.startReading() else { throw reader.error ?? CocoaError(.fileReadUnknown) }
        var samples = Data()
        while let buffer = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            var bytes = Data(count: length)
            bytes.withUnsafeMutableBytes { _ = CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: $0.baseAddress!) }
            samples.append(bytes)
        }
        try samples.write(to: file)
        return !samples.isEmpty
    }

    private static func text(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

struct Failure: LocalizedError {
    let errorDescription: String?
    init(_ text: String) { errorDescription = text }
}

/// The one outside program the film leans on.
enum Tool {
    static let path = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        .first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/opt/homebrew/bin/ffmpeg"

    /// Runs ffmpeg to its end and returns what it reported.
    @discardableResult
    static func ffmpeg(_ arguments: [String]) throws -> String {
        guard FileManager.default.isExecutableFile(atPath: path) else {
            throw Failure("ffmpeg is needed and was not found. Install it with: brew install ffmpeg")
        }
        let process = Process(), report = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-hide_banner", "-nostats", "-loglevel", "info"] + arguments
        process.standardError = report
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        let text = String(decoding: report.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Failure("ffmpeg stopped with an error:\n" + text.split(separator: "\n").suffix(6).joined(separator: "\n"))
        }
        return text
    }
}
