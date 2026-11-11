import SceneKit
import SwiftUI
import simd

/// The AirPods case, in 3D, turning as the real one turns.
///
/// Shown the way a mirror would show it: facing you, lid open behind the two AirPods
/// docked inside, and turning to your right when you turn yours to the right. The lid
/// shuts when the AirPods go to sleep.
struct CaseView: NSViewRepresentable {
    let runtime: PointerRuntime
    var isAwake: Bool

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> CaseScene { CaseScene(runtime: runtime) }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.camera
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = false
        view.allowsCameraControl = false
        view.delegate = context.coordinator
        view.isPlaying = true
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.image)
        view.setAccessibilityLabel("Your AirPods case with both AirPods docked, mirroring how you hold it")
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        context.coordinator.reduceMotion = reduceMotion
        context.coordinator.setAwake(isAwake)
        // Only a live stream needs a frame every refresh. Asleep, the lid shuts and then
        // nothing moves, so the scene stops drawing altogether until it wakes.
        let scene = context.coordinator
        if isAwake {
            view.isPlaying = true
            view.rendersContinuously = true
        } else {
            view.rendersContinuously = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak view] in
                if !scene.isAwake { view?.isPlaying = false }
            }
        }
        context.coordinator.setDark(scheme == .dark)
    }

    static func dismantleNSView(_ view: SCNView, coordinator: CaseScene) {
        view.isPlaying = false
        view.delegate = nil
    }
}

/// Builds the case and keeps it in step with the motion stream.
final class CaseScene: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    let camera = SCNNode()

    private let runtime: PointerRuntime?
    private let aim = SCNNode()
    private let lidPivot = SCNNode()
    private let ring = SCNNode()
    private let keyLight = SCNNode()
    private let fillLight = SCNNode()

    private var yaw = 0.0, pitch = 0.0, roll = 0.0
    private var lastTime: TimeInterval?
    private var lastTapCount: Int?
    private var awake: Bool?
    private var dark: Bool?
    var isAwake: Bool { awake == true }
    private let led = SCNMaterial()
    private let lamp = SCNNode()
    /// Set from the system's Reduce Motion setting: the lid snaps and the tap ring only fades.
    var reduceMotion = false

    /// Height of the tap ring relative to its width.
    private let ringSquash = 0.76

    /// Lid angle when open, radians about the hinge.
    private let openAngle = -105.0 * .pi / 180

    init(runtime: PointerRuntime?) {
        self.runtime = runtime
        super.init()
        build()
    }

    // MARK: State

    func setAwake(_ on: Bool, animated: Bool = true) {
        guard awake != on else { return }
        let animate = animated && awake != nil && !reduceMotion
        awake = on
        // The status light on the front: lit in the keyline colour while awake. The colour is
        // given once, as light it gives off; given as its surface colour too, the two add up
        // and it renders as a paler, greener blue than the keyline.
        led.emission.contents = on ? NSColor(Theme.keyline) : NSColor.black
        led.diffuse.contents = NSColor.black
        // Unlit, the light is not there to see: on the real case it sits behind the plastic.
        lamp.isHidden = !on
        let angle = on ? openAngle : 0
        lidPivot.removeAllActions()
        if animate {
            let turn = SCNAction.rotateTo(x: angle, y: 0, z: 0, duration: on ? 0.42 : 0.3, usesShortestUnitArc: true)
            turn.timingMode = .easeOut
            lidPivot.runAction(turn)
        } else {
            lidPivot.eulerAngles.x = angle
        }
    }

    func setDark(_ on: Bool) {
        guard dark != on else { return }
        dark = on
        // The case is white in any light; at night the room around it dims.
        scene.lightingEnvironment.contents = CaseScene.environment(dark: on)
        // In daylight the white case sits on a near-white stage, so it is lit to keep its
        // shading rather than to look as bright as possible.
        scene.lightingEnvironment.intensity = on ? 0.55 : 0.5
        keyLight.light?.intensity = on ? 700 : 470
        fillLight.light?.intensity = on ? 260 : 150
    }

    /// Sets the lid by hand, from 0 (shut) to 1 (fully open), and the status light with it.
    /// For renders made one frame at a time, where nothing runs on a clock.
    func poseLid(openness: Double) {
        let open = min(max(openness, 0), 1)
        lidPivot.removeAllActions()
        lidPivot.eulerAngles.x = openAngle * open
        let on = open > 0.5
        awake = on
        led.emission.contents = on ? NSColor(Theme.keyline) : NSColor.black
        led.diffuse.contents = NSColor.black
        lamp.isHidden = !on
    }

    /// Sets the tap ring by hand: nil hides it, 0…1 is how far it has spread.
    func poseRing(progress: Double?) {
        ring.removeAllActions()
        guard let progress, progress >= 0, progress < 1 else {
            ring.opacity = 0
            return
        }
        let size = 0.8 + 0.36 * (1 - pow(1 - progress, 3))
        ring.scale = SCNVector3(size, 1, size * ringSquash)
        ring.opacity = 0.95 * (1 - progress * progress)
    }

    /// Where a point on the case lands in a picture of the given size, origin top-left.
    /// Used to draw labels that point at parts of the case.
    func pictured(_ point: SIMD3<Float>, in viewport: CGSize) -> CGPoint {
        guard let lens = camera.camera else { return .zero }
        let world = aim.simdWorldTransform * SIMD4<Float>(point.x, point.y, point.z, 1)
        let view = camera.simdWorldTransform.inverse * world
        let clip = simd_float4x4(lens.projectionTransform(withViewportSize: viewport)) * view
        guard clip.w != 0 else { return .zero }
        let x = (CGFloat(clip.x / clip.w) + 1) / 2 * viewport.width
        let y = (1 - CGFloat(clip.y / clip.w)) / 2 * viewport.height
        return CGPoint(x: x, y: y)
    }

    /// Sets the pose directly. Used for still renders.
    func pose(yaw: Double, pitch: Double, roll: Double) {
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
        applyPose()
    }

    // MARK: Frame

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let runtime else { return }
        let dt = min(0.05, max(0, time - (lastTime ?? time)))
        lastTime = time
        let live = runtime.snapshot()

        if live.isStreaming {
            // Pitch is read from gravity, so it is the true tilt. Yaw and roll have no fixed
            // reference, so they follow the motion and ease back to centre.
            yaw += live.telemetry.yaw * dt
            roll += live.telemetry.roll * dt
            pitch += (live.telemetry.elevation - pitch) * (1 - exp(-dt / 0.05))
        } else {
            pitch *= exp(-dt / 0.3)
        }
        let ease = exp(-dt / 2.2)
        yaw = min(max(yaw * ease, -55), 55)
        roll = min(max(roll * ease, -75), 75)
        applyPose()

        if let last = lastTapCount, live.tapCount != last { pulse(strength: live.lastTapStrength) }
        lastTapCount = live.tapCount
    }

    private func applyPose() {
        let p = min(max(pitch, -45), 55)
        // A mirror image: aim right and the front swings to the right of the screen; aim up
        // and the front tips up; twist clockwise and the top leans right.
        let turn = simd_quatf(angle: Float(yaw * .pi / 180), axis: [0, 1, 0])
        let tilt = simd_quatf(angle: Float(-p * .pi / 180), axis: [1, 0, 0])
        let twist = simd_quatf(angle: Float(-roll * .pi / 180), axis: [0, 0, 1])
        aim.simdOrientation = turn * tilt * twist
    }

    /// A ring spreading out from behind the case, where the finger landed.
    private func pulse(strength: Double) {
        ring.removeAllActions()
        ring.opacity = 0.95
        guard !reduceMotion else {
            ring.scale = SCNVector3(1.08, 1, 1.08 * ringSquash)
            ring.runAction(.fadeOut(duration: 0.4))
            return
        }
        // Wider than it is tall, like the case, so it spreads sideways and stays clear of
        // the screen above.
        ring.scale = SCNVector3(0.8, 1, 0.8 * ringSquash)
        let grow = SCNAction.customAction(duration: 0.5) { [ringSquash] node, elapsed in
            let t = 1 - pow(1 - Double(elapsed) / 0.5, 3)
            let s = 0.8 + 0.36 * t
            node.scale = SCNVector3(s, 1, s * ringSquash)
        }
        let fade = SCNAction.fadeOut(duration: 0.5)
        fade.timingMode = .easeIn
        ring.runAction(.group([grow, fade]))
    }

    // MARK: Construction

    private func build() {
        let cam = SCNCamera()
        cam.fieldOfView = 26
        cam.zNear = 0.5
        cam.zFar = 60
        camera.camera = cam
        // In front of the case and a little above, looking down into its open top.
        camera.position = SCNVector3(0, 5.6, 15.4)
        camera.look(at: SCNVector3(0, 0.35, 0))
        scene.rootNode.addChildNode(camera)

        let key = SCNLight()
        key.type = .directional
        key.intensity = 760
        key.color = NSColor.white
        keyLight.light = key
        keyLight.eulerAngles = SCNVector3(-52 * Double.pi / 180, -26 * Double.pi / 180, 0)
        scene.rootNode.addChildNode(keyLight)

        let fill = SCNLight()
        fill.type = .ambient
        fill.intensity = 420
        fill.color = NSColor(hex: 0xEAF2FA)
        fillLight.light = fill
        scene.rootNode.addChildNode(fillLight)

        // The tap ring sits behind the case and does not turn with it: it spreads out past
        // the silhouette, as if from the tap on the back.
        let tube = SCNTube(innerRadius: 3.42, outerRadius: 3.59, height: 0.01)
        tube.radialSegmentCount = 96
        let glow = SCNMaterial()
        glow.lightingModel = .constant
        glow.diffuse.contents = NSColor(Theme.keyline)
        glow.isDoubleSided = true
        tube.materials = [glow]
        ring.geometry = tube
        ring.eulerAngles.x = .pi / 2   // the tube's axis is y; lay it in the plane facing the viewer
        // Far enough back to stay behind the lid however the case is tilted, and lowered and
        // widened to match, so that from the camera it is where and as large as it would be
        // just behind the case.
        ring.position = SCNVector3(0, -0.75, -3.4)
        ring.opacity = 0
        scene.rootNode.addChildNode(ring)

        scene.rootNode.addChildNode(aim)
        let rest = aim

        // The case and the AirPods are the model the spot is rendered from (CaseModel): the
        // real case's size and details, not a rounded box standing in for it.
        let shell = CaseScene.plastic(white: 0.97, roughness: 0.3)
        let silicone = CaseScene.plastic(white: 0.93, roughness: 0.82)
        let metal = CaseScene.metal()
        let dark = SCNMaterial()
        dark.lightingModel = .physicallyBased
        dark.diffuse.contents = NSColor(white: 0.16, alpha: 1)
        dark.roughness.contents = 0.6

        // The body, and what is let into it: the hinge plate on the back, the lanyard plate
        // on one side, the port underneath.
        rest.addChildNode(SCNNode(geometry: CaseModel.geometry("body", material: shell)))
        rest.addChildNode(SCNNode(geometry: CaseModel.geometry("hingeBody", material: metal)))
        rest.addChildNode(SCNNode(geometry: CaseModel.geometry("lanyard", material: metal)))
        rest.addChildNode(SCNNode(geometry: CaseModel.geometry("port", material: metal)))
        rest.addChildNode(SCNNode(geometry: CaseModel.geometry("portCore", material: dark)))

        // The two AirPods, docked as they really sit: stems down at the outer ends, ear tips
        // turned in toward each other, the black sensor window on each head facing forward.
        for right in [false, true] {
            let pod = SCNNode()
            pod.simdTransform = CaseModel.podTransform(right: right)
            pod.addChildNode(SCNNode(geometry: CaseModel.geometry("bud", material: shell, mirrored: right)))
            pod.addChildNode(SCNNode(geometry: CaseModel.geometry("tip", material: silicone, mirrored: right)))
            rest.addChildNode(pod)
        }

        // Status light, centred on the front under the lid line.
        led.lightingModel = .constant
        let bulb = SCNSphere(radius: 0.085)
        bulb.materials = [led]
        lamp.geometry = bulb
        lamp.simdPosition = CaseModel.light - SIMD3<Float>(0, 0, 0.015)
        lamp.scale = SCNVector3(1, 1, 0.3)
        rest.addChildNode(lamp)

        // The lid swings back about the hinge line on the rear face, showing its inside. The
        // two blocks of the hinge plate that belong to it go with it.
        lidPivot.simdPosition = SIMD3<Float>(0, CaseModel.seam, -CaseModel.half.z)
        rest.addChildNode(lidPivot)
        for (name, material) in [("lid", shell), ("hingeLid", metal)] {
            let node = SCNNode(geometry: CaseModel.geometry(name, material: material))
            node.simdPosition = SIMD3<Float>(0, -CaseModel.seam, CaseModel.half.z)
            lidPivot.addChildNode(node)
        }

        setDark(false)
        setAwake(false, animated: false)
    }

    private static func plastic(white: CGFloat, roughness: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = NSColor(white: white, alpha: 1)
        m.metalness.contents = 0.0
        m.roughness.contents = roughness
        return m
    }

    /// Satin metal, for the hinge plate, the lanyard plate and the lining of the port.
    private static func metal() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = NSColor(white: 0.84, alpha: 1)
        m.metalness.contents = 0.7
        m.roughness.contents = 0.42
        return m
    }

    /// A soft studio: bright above, cool below. Gives the white plastic something to reflect.
    private static func environment(dark: Bool) -> CGImage? {
        let width = 256, height = 128
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let stops: [NSColor] = dark
            ? [NSColor(hex: 0x0B1118), NSColor(hex: 0x3A5068), NSColor(hex: 0xE4EFF9)]
            : [NSColor(hex: 0xAEBFCF), NSColor(hex: 0xF2F6FA), NSColor(hex: 0xFFFFFF)]
        let gradient = CGGradient(colorsSpace: nil, colors: stops.map(\.cgColor) as CFArray, locations: [0, 0.55, 1])!
        // Bottom of the image is the floor, top is the ceiling.
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: height), options: [])
        return context.makeImage()
    }
}
