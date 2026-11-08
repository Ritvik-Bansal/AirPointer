import CoreMotion
import Foundation
import PointerKit
import simd

/// The AirPods' motion stream, as `MotionSample`s.
///
/// Motion comes from whichever earbud the AirPods choose, at a fixed 50 Hz, and only while
/// the earbud believes it is in use: out of a closed case, with Automatic Ear Detection off.
final class MotionSource: NSObject, CMHeadphoneMotionManagerDelegate, @unchecked Sendable {
    enum Authorization {
        case undetermined, allowed, denied
    }

    private let manager = CMHeadphoneMotionManager()
    private let operations = OperationQueue()
    private(set) var isRunning = false

    /// Called on the engine queue for every sample.
    var onSample: ((MotionSample) -> Void)?
    /// Called on the main queue when the AirPods connect to or drop from this Mac.
    var onConnection: ((Bool) -> Void)?

    /// - Parameter queue: Serial queue samples are delivered on.
    init(queue: DispatchQueue) {
        operations.underlyingQueue = queue
        operations.maxConcurrentOperationCount = 1
        super.init()
        manager.delegate = self
    }

    static var authorization: Authorization {
        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .authorized: .allowed
        case .denied, .restricted: .denied
        default: .undetermined
        }
    }

    var isSupported: Bool { manager.isDeviceMotionAvailable }

    /// Starts the stream. The first call makes macOS ask for Motion & Fitness access.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        manager.startConnectionStatusUpdates()
        beginUpdates()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        manager.stopDeviceMotionUpdates()
        manager.stopConnectionStatusUpdates()
    }

    /// Re-requests the stream. After the case lid reopens the AirPods reconnect on their own,
    /// but the stream can take several seconds to follow; asking again brings it back sooner.
    func nudge() {
        guard isRunning else { return }
        manager.stopDeviceMotionUpdates()
        beginUpdates()
    }

    private func beginUpdates() {
        manager.startDeviceMotionUpdates(to: operations) { [weak self] motion, _ in
            guard let self, let m = motion else { return }
            let q = m.attitude.quaternion
            let location: SensorLocation = switch m.sensorLocation {
            case .headphoneLeft: .left
            case .headphoneRight: .right
            default: .unknown
            }
            self.onSample?(MotionSample(
                timestamp: m.timestamp,
                arrival: ProcessInfo.processInfo.systemUptime,
                rotationRate: Vec3(m.rotationRate.x, m.rotationRate.y, m.rotationRate.z),
                userAcceleration: Vec3(m.userAcceleration.x, m.userAcceleration.y, m.userAcceleration.z),
                gravity: Vec3(m.gravity.x, m.gravity.y, m.gravity.z),
                attitude: simd_quatd(ix: q.x, iy: q.y, iz: q.z, r: q.w),
                location: location
            ))
        }
    }

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async { self.onConnection?(true) }
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async { self.onConnection?(false) }
    }
}
