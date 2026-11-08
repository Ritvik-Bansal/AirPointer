import AppKit
import Observation
import PointerKit
import SwiftUI

/// Where a calibration gesture has got to, without the numbers.
enum CalibrationStage: Equatable {
    case settling, ready, capturing

    init(_ state: AxisCalibrator.State?) {
        switch state {
        case .ready: self = .ready
        case .capturing: self = .capturing
        default: self = .settling
        }
    }
}

/// The app's state: what the user has chosen, what the hardware is doing, and the one
/// status that follows from the two.
@MainActor
@Observable
final class AppModel {
    /// The single thing the pointer is doing right now, most blocking first.
    enum Status: Equatable {
        /// macOS has refused access to the AirPods' motion.
        case motionDenied
        /// macOS has not allowed AirPointer to move the cursor yet.
        case needsPointerAccess
        case off
        /// On, but nothing is arriving: lid closed, AirPods away, or Automatic Ear Detection on.
        case asleep
        /// Motion has just started arriving. The pointer waits a moment before going live,
        /// long enough to tell a case in the hand from AirPods going into ears.
        case waking
        /// Motion is arriving, but it looks like a head rather than a hand.
        case inEars
        case calibrating
        case pointing
    }

    let runtime = PointerRuntime()
    private let audio = AudioGuard()
    private let airPodsMonitor = AirPodsMonitor()
    private let hud = ClickHUD()
    private let defaults = UserDefaults.standard

    // MARK: Choices (saved)

    var prefs: PointerPreferences { didSet { if prefs != oldValue { save(prefs, "prefs"); pushSettings() } } }
    var calibration: GripCalibration { didSet { if calibration != oldValue { save(calibration, "calibration") } } }
    var isOn: Bool { didSet { if isOn != oldValue { defaults.set(isOn, forKey: "isOn"); handOverride = false; refresh() } } }
    var keepSoundOnMac: Bool { didSet { defaults.set(keepSoundOnMac, forKey: "keepSoundOnMac"); refresh() } }
    var showClickRings: Bool { didSet { defaults.set(showClickRings, forKey: "showClickRings") } }
    var hasFinishedSetup: Bool { didSet { defaults.set(hasFinishedSetup, forKey: "hasFinishedSetup") } }
    var toggleShortcut: Shortcut? { didSet { save(toggleShortcut, "toggleShortcut"); registerShortcuts() } }
    var calibrateShortcut: Shortcut? { didSet { save(calibrateShortcut, "calibrateShortcut"); registerShortcuts() } }

    // MARK: Live

    private(set) var status = Status.off
    private(set) var motionAccess = MotionSource.authorization
    private(set) var canControlPointer = Permissions.canControlPointer
    private(set) var isStreaming = false
    private(set) var hasEverStreamed = false
    private(set) var airPods: AirPodsInfo?
    private(set) var sensor = SensorLocation.unknown
    private(set) var isCalibrating = false
    /// How far the calibration gesture has got, for the coaching line.
    private(set) var calibrationStage = CalibrationStage.settling
    private(set) var calibrationProblem: AxisCalibrator.Problem?
    /// True when macOS says the AirPods are connected yet nothing has arrived for a while:
    /// the sign that Automatic Ear Detection is still on.
    private(set) var isConnectedButSilent = false
    /// Bumps when a calibration is learned, so views can celebrate once.
    private(set) var calibrationsLearned = 0
    /// Bumps on every click the pointer makes.
    private(set) var clicksMade = 0
    private(set) var isRecording = false
    private(set) var lastRecording: URL?
    var launchAtLogin = LoginItem.isEnabled
    var loginItemProblem: String?
    /// "They're in my hand": the user's answer when the in-ears guess is wrong.
    var handOverride = false { didSet { if handOverride != oldValue { refresh() } } }

    /// Set by the interface while something that draws live motion is on screen.
    var windowVisible = false { didSet { if windowVisible != oldValue { refresh() } } }
    var popoverVisible = false { didSet { if popoverVisible != oldValue { refresh() } } }
    /// Set once the user has agreed to the motion prompt in setup.
    private var motionRequested = false

    /// True while a recording stands in for the AirPods. Development only.
    private(set) var isRehearsing = false

    private var looksWornTicks = 0
    private var looksWorn = false
    private var streamBegan: Date?
    private var lastStreamed: Date?
    private var nudgeInterval = 4.0
    private var askedForPointerAccess = false
    private var connected = false
    private var silentSince: Date?
    private var lastNudge = Date.distantPast
    private var lastAirPodsRead = Date.distantPast
    private var ticker: Timer?
    private var activity: NSObjectProtocol?

    init() {
        prefs = Self.load("prefs", from: defaults) ?? PointerPreferences()
        calibration = Self.load("calibration", from: defaults) ?? GripCalibration()
        isOn = defaults.object(forKey: "isOn") as? Bool ?? true
        keepSoundOnMac = defaults.object(forKey: "keepSoundOnMac") as? Bool ?? true
        showClickRings = defaults.object(forKey: "showClickRings") as? Bool ?? true
        hasFinishedSetup = defaults.bool(forKey: "hasFinishedSetup")
        toggleShortcut = defaults.object(forKey: "toggleShortcut") == nil ? .toggle : Self.load("toggleShortcut", from: defaults)
        calibrateShortcut = defaults.object(forKey: "calibrateShortcut") == nil ? .calibrate : Self.load("calibrateShortcut", from: defaults)

        runtime.onEvent = { [weak self] event in self?.handle(event) }
        runtime.source.onConnection = { [weak self] isConnected in
            self?.connected = isConnected
            self?.refresh()
        }
        runtime.apply(calibration)
        pushSettings()
        registerShortcuts()

        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        Rehearsal.beginIfAsked(self)
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.pushSettings() }
        }
        // Quitting in the middle of a drag must not leave the button down.
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [runtime] _ in
            runtime.shutdown()
        }
        refresh()
    }

}
