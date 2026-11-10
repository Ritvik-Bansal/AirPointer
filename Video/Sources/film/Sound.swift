import AVFoundation
import Foundation

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
