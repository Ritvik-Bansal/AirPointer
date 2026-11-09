import SceneKit
import SwiftUI
import simd

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
