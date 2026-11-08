import Foundation

/// What macOS knows about the AirPods beyond their motion.
struct AirPodsInfo: Equatable, Sendable {
    var name: String
    var isConnected: Bool
    /// Percent, 0…100.
    var left: Int?
    var right: Int?
    var caseLevel: Int?

    /// The case only reports its battery while an AirPod is docked in it with the lid open,
    /// so a case reading means the AirPods are in the case rather than in someone's ears.
    var isDocked: Bool { isConnected && caseLevel != nil }
}

/// Reads AirPods battery and docking state from the system's Bluetooth report.
///
/// There is no public API for these. `system_profiler` already has them and needs no
/// permission, at the cost of about a second per call, so this runs off the main thread and
/// only as often as asked.
@MainActor
final class AirPodsMonitor {
    private let queue = DispatchQueue(label: "com.ritvikbansal.AirPointer.airpods", qos: .utility)
    private var isReading = false

    /// Fetches once and calls back. A request made while one is already under way is dropped.
    func refresh(_ completion: @escaping @MainActor (AirPodsInfo?) -> Void) {
        guard !isReading else { return }
        isReading = true
        queue.async {
            let info = Self.read()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.isReading = false
                    completion(info)
                }
            }
        }
    }

    nonisolated private static func read() -> AirPodsInfo? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        // It normally answers within a second or two. If it ever hangs, do not hang with it.
        let deadline = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 10, execute: deadline)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        deadline.cancel()

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let section = (root["SPBluetoothDataType"] as? [[String: Any]])?.first
        else { return nil }

        var found: AirPodsInfo?
        for (key, connected) in [("device_connected", true), ("device_not_connected", false)] {
            guard let devices = section[key] as? [[String: Any]] else { continue }
            for entry in devices {
                for (name, value) in entry {
                    guard name.localizedCaseInsensitiveContains("AirPods"), let props = value as? [String: Any] else { continue }
                    let info = AirPodsInfo(
                        name: name,
                        isConnected: connected,
                        left: percent(props["device_batteryLevelLeft"]),
                        right: percent(props["device_batteryLevelRight"]),
                        caseLevel: percent(props["device_batteryLevelCase"])
                    )
                    // Prefer a connected pair over a remembered one.
                    if found == nil || (connected && found?.isConnected == false) { found = info }
                }
            }
        }
        return found
    }

    nonisolated private static func percent(_ value: Any?) -> Int? {
        guard let text = value as? String else { return nil }
        return Int(text.trimmingCharacters(in: CharacterSet(charactersIn: "% ")))
    }
}
