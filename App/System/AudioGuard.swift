import CoreAudio
import Foundation

/// Keeps the Mac's sound on its own speakers and microphone while the AirPods are a pointer.
///
/// Pointing needs Automatic Ear Detection off, and with it off macOS sends sound to the
/// AirPods the moment they connect, even while they sit docked in the case where nobody can
/// hear them. While guarding, any switch to the AirPods is moved back to what was in use
/// before. Sound is handed back to the AirPods in one case only: they turn out to be in
/// someone's ears, and nothing else has been chosen since.
@MainActor
final class AudioGuard {
    private(set) var isGuarding = false
    private var listening = false

    /// The last non-AirPods device seen as default, per direction.
    private var preferred: [AudioObjectPropertySelector: AudioDeviceID] = [:]
    /// What this class moved: from which AirPods device, to which other one.
    private var redirected: [AudioObjectPropertySelector: (from: AudioDeviceID, to: AudioDeviceID)] = [:]

    private let selectors: [AudioObjectPropertySelector] = [
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioHardwarePropertyDefaultSystemOutputDevice,
        kAudioHardwarePropertyDefaultInputDevice,
    ]

    /// - Parameter handBack: When guarding ends, return sound to the AirPods it was moved
    ///   from, provided the device it was moved to is still the one in use.
    func setGuarding(_ on: Bool, handBack: Bool = false) {
        listen()
        guard on != isGuarding else { return }
        isGuarding = on
        if on {
            for s in selectors { enforce(s) }
        } else {
            if handBack {
                for (selector, move) in redirected where deviceExists(move.from) && currentDefault(selector) == move.to {
                    setDefault(selector, to: move.from)
                }
            }
            redirected.removeAll()
        }
    }

    private func listen() {
        guard !listening else { return }
        listening = true
        for selector in selectors {
            if let current = currentDefault(selector), !isAirPods(current) { preferred[selector] = current }
            var address = Self.address(selector)
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.enforce(selector) }
            }
        }
    }

    private func enforce(_ selector: AudioObjectPropertySelector) {
        guard let current = currentDefault(selector) else { return }
        guard isAirPods(current) else {
            preferred[selector] = current
            return
        }
        guard isGuarding else { return }
        let input = selector == kAudioHardwarePropertyDefaultInputDevice
        guard let fallback = preferred[selector].flatMap({ deviceExists($0) ? $0 : nil }) ?? builtIn(input: input) else { return }
        redirected[selector] = (from: current, to: fallback)
        setDefault(selector, to: fallback)
    }

}
