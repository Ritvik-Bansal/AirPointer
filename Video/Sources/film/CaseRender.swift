import AppKit
import Metal
import SceneKit

/// Renders the app's own 3D case to an image, posed by hand.
@MainActor
final class CaseRenderer {
    struct Pose: Equatable {
        /// Degrees. Right, up and clockwise are positive, as in the app.
        var yaw = 0.0
        var pitch = 0.0
        var roll = 0.0
        /// 0 shut, 1 open.
        var lid = 1.0
        /// Tap ring: nil hidden, 0…1 spreading.
        var ring: Double?
    }

    private let scene: CaseScene
    private let renderer: SCNRenderer

    init() {
        // The film is set at night; resolve the app's colours that way.
        var built: CaseScene!
        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            built = CaseScene(runtime: nil)
            built.setDark(true)
        }
        scene = built
        renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = scene.scene
        renderer.pointOfView = scene.camera
        renderer.autoenablesDefaultLighting = false
    }

    /// - Parameter size: Pixel size of the image. The case is framed by height.
    func image(_ pose: Pose, size: CGSize) -> CGImage? {
        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            scene.poseLid(openness: pose.lid)
            scene.poseRing(progress: pose.ring)
        }
        scene.pose(yaw: pose.yaw, pitch: pose.pitch, roll: pose.roll)
        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    /// Where a point on the case (in the model's own units) lands in a picture of `size`
    /// taken at the pose last rendered.
    func pictured(_ point: SIMD3<Float>, size: CGSize) -> CGPoint {
        scene.pictured(point, in: size)
    }

    /// Named places on the case, in the model's units.
    enum Spot {
        /// The crown of the AirPod on the viewer's right.
        static let airPod = SIMD3<Float>(1.74, 1.9, 0.1)
        /// The front of the body, low on the viewer's left.
        static let body = SIMD3<Float>(-1.75, -1.05, CaseModel.half.z)
        static let centre = SIMD3<Float>(0, 0, 0)
    }
}
