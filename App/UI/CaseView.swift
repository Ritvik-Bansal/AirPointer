import SceneKit
import SwiftUI
import simd

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

        let shell = CaseScene.plastic(white: 0.97, roughness: 0.3)
        let inside = CaseScene.plastic(white: 0.84, roughness: 0.8)
        let socket = CaseScene.plastic(white: 0.72, roughness: 0.85)

        rest.addChildNode(SCNNode(geometry: CaseMesh.body(material: shell)))
        // The line where the lid meets the body. It is what makes a shut case read as a
        // case rather than a pebble.
        let groove = CaseScene.plastic(white: 0.62, roughness: 0.9)
        rest.addChildNode(SCNNode(geometry: CaseMesh.seamLine(material: groove)))
        rest.addChildNode(SCNNode(geometry: CaseMesh.deck(y: CaseMesh.seam - 0.015, facingUp: true, material: inside)))

        // The two AirPods, docked: their heads stand clear of the open top, as they do in
        // the real case. Left plain: a dark vent on each reads, at any size, as a pair of eyes.
        for side in [-1.0, 1.0] {
            let head = SCNSphere(radius: 0.62)
            head.segmentCount = 40
            head.materials = [shell]
            let node = SCNNode(geometry: head)
            node.position = SCNVector3(side * 1.36, Double(CaseMesh.seam) + 0.4, 0.04)
            node.scale = SCNVector3(1.02, 1.26, 0.9)
            node.eulerAngles.z = side * -0.17
            rest.addChildNode(node)

        }

        // Status light, centred on the front just under the seam.
        led.lightingModel = .constant
        let lamp = SCNSphere(radius: 0.1)
        lamp.materials = [led]
        let lampNode = SCNNode(geometry: lamp)
        lampNode.position = SCNVector3(0, Double(CaseMesh.seam) - 0.5, Double(CaseMesh.r) - 0.03)
        lampNode.scale = SCNVector3(1, 1, 0.4)
        rest.addChildNode(lampNode)

        // The bottom end: charging port between two rows of speaker holes. Out of sight
        // until the case is tipped back.
        let dark = SCNMaterial()
        dark.lightingModel = .physicallyBased
        dark.diffuse.contents = NSColor(white: 0.16, alpha: 1)
        dark.roughness.contents = 0.6
        let port = SCNCapsule(capRadius: 0.13, height: 0.96)
        port.materials = [dark]
        let portNode = SCNNode(geometry: port)
        portNode.eulerAngles.z = .pi / 2
        portNode.position = SCNVector3(0, Double(-CaseMesh.half.y) + 0.105, 0)
        rest.addChildNode(portNode)
        for side in [-1.0, 1.0] {
            for k in 0..<4 {
                let hole = SCNCylinder(radius: 0.042, height: 0.05)
                hole.materials = [dark]
                let node = SCNNode(geometry: hole)
                node.position = SCNVector3(side * (0.82 + Double(k) * 0.17), Double(-CaseMesh.half.y) + 0.014, 0)
                rest.addChildNode(node)
            }
        }

        // The lid swings back about the hinge on the rear edge, showing its inside.
        lidPivot.position = SCNVector3(0, Double(CaseMesh.seam), Double(-CaseMesh.r))
        rest.addChildNode(lidPivot)
        let lidOffset = SCNVector3(0, Double(-CaseMesh.seam), Double(CaseMesh.r))
        let lid = SCNNode(geometry: CaseMesh.lid(material: shell))
        lid.position = lidOffset
        lidPivot.addChildNode(lid)
        let lidInside = SCNNode(geometry: CaseMesh.deck(y: CaseMesh.seam + 0.015, facingUp: false, material: inside))
        lidInside.position = lidOffset
        lidPivot.addChildNode(lidInside)
        // The two hollows the AirPods' heads tuck into.
        for side in [-1.0, 1.0] {
            let hollow = SCNSphere(radius: 0.6)
            hollow.materials = [socket]
            let node = SCNNode(geometry: hollow)
            node.position = SCNVector3(side * 1.36, Double(CaseMesh.seam) + 0.02, 0.04)
            node.scale = SCNVector3(1.0, 0.06, 0.82)
            node.position = SCNVector3(side * 1.36 + lidOffset.x, Double(CaseMesh.seam) + 0.03 + lidOffset.y, 0.04 + lidOffset.z)
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
        m.isDoubleSided = true
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

/// The case's shell, generated rather than modelled: a box rounded so far that its ends
/// are half-cylinders, cut across at the lid seam into a body and a lid.
enum CaseMesh {
    /// Half-extents: width, height (lid end at +y), depth. Proportions of the real case.
    static let half = SIMD3<Float>(3.03, 2.26, 1.085)
    /// Edge radius. Equal to the half-depth, so the sides are fully round.
    static let r: Float = 1.085
    /// Height of the lid seam.
    static let seam: Float = 0.62
    private static let around = 22
    private static let over = 14

    private struct Vertex {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
    }

    /// One loop around the shell at a given tilt of the surface normal.
    private static func loop(latitude: Float, y: Float) -> [Vertex] {
        let ix = half.x - r
        var out: [Vertex] = []
        for end in [Float(1), Float(-1)] {
            for k in 0...around {
                let phi = (end > 0 ? -Float.pi / 2 : Float.pi / 2) + Float.pi * Float(k) / Float(around)
                let n = SIMD3<Float>(cos(phi) * cos(latitude), sin(latitude), sin(phi) * cos(latitude))
                out.append(Vertex(position: SIMD3(end * ix + r * n.x, y + r * n.y, r * n.z), normal: n))
            }
        }
        return out
    }

    private static func geometry(loops: [[Vertex]], material: SCNMaterial) -> SCNGeometry {
        let vertices = loops.flatMap { $0 }
        let count = loops[0].count
        var indices: [UInt32] = []
        for l in 0..<(loops.count - 1) {
            for i in 0..<count {
                let a = UInt32(l * count + i), b = UInt32(l * count + (i + 1) % count)
                let c = UInt32((l + 1) * count + i), d = UInt32((l + 1) * count + (i + 1) % count)
                // Wound so each face's front is its outside; the vertex normals point outward too.
                indices += [a, c, b, b, c, d]
            }
        }
        return make(vertices: vertices, indices: indices, material: material)
    }

    private static func make(vertices: [Vertex], indices: [UInt32], material: SCNMaterial) -> SCNGeometry {
        let positions = SCNGeometrySource(vertices: vertices.map { SCNVector3($0.position.x, $0.position.y, $0.position.z) })
        let normals = SCNGeometrySource(normals: vertices.map { SCNVector3($0.normal.x, $0.normal.y, $0.normal.z) })
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let g = SCNGeometry(sources: [positions, normals], elements: [element])
        g.materials = [material]
        return g
    }

    /// From the rounded bottom up to the seam.
    static func body(material: SCNMaterial) -> SCNGeometry {
        let iy = half.y - r
        var loops: [[Vertex]] = []
        for m in 0...over {
            loops.append(loop(latitude: -Float.pi / 2 + Float.pi / 2 * Float(m) / Float(over), y: -iy))
        }
        loops.append(loop(latitude: 0, y: seam))
        return geometry(loops: loops, material: material)
    }

    /// From the seam over the rounded top.
    static func lid(material: SCNMaterial) -> SCNGeometry {
        let iy = half.y - r
        var loops: [[Vertex]] = [loop(latitude: 0, y: seam)]
        for m in 0...over {
            loops.append(loop(latitude: Float.pi / 2 * Float(m) / Float(over), y: iy))
        }
        return geometry(loops: loops, material: material)
    }

    /// A narrow band round the shell at the seam, standing a hair proud of it.
    static func seamLine(material: SCNMaterial) -> SCNGeometry {
        func band(_ y: Float) -> [Vertex] {
            loop(latitude: 0, y: y).map { Vertex(position: $0.position + $0.normal * 0.008, normal: $0.normal) }
        }
        return geometry(loops: [band(seam - 0.028), band(seam + 0.028)], material: material)
    }

    /// The flat face that closes an open half at the seam.
    static func deck(y: Float, facingUp: Bool, material: SCNMaterial) -> SCNGeometry {
        let normal = SIMD3<Float>(0, facingUp ? 1 : -1, 0)
        let rim = loop(latitude: 0, y: y).map { Vertex(position: SIMD3($0.position.x * 0.985, y, $0.position.z * 0.985), normal: normal) }
        var vertices = [Vertex(position: SIMD3(0, y, 0), normal: normal)] + rim
        vertices.reserveCapacity(rim.count + 1)
        var indices: [UInt32] = []
        for i in 0..<rim.count {
            let a = UInt32(1 + i), b = UInt32(1 + (i + 1) % rim.count)
            indices += facingUp ? [0, b, a] : [0, a, b]
        }
        return make(vertices: vertices, indices: indices, material: material)
    }
}
