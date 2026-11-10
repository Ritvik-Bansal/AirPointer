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

