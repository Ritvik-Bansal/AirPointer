import SceneKit
import simd

/// The AirPods case and its AirPods as SceneKit geometry.
///
/// The shapes are not drawn here. They come from `CaseModelData`, which is generated from
/// the same solids the spot (`Video/Spot`) is rendered from: the real case's published size,
/// and the rest measured off photographs of one. This unpacks them and scales them from
/// millimetres to the scene's units, in which the case has always been 6.06 wide.
enum CaseModel {
    /// Scene units to a millimetre.
    static let scale: Float = 3.03 / CaseModelData.half.x
    /// Half the case's width, height and depth, in scene units.
    static let half = CaseModelData.half * scale
    /// Height of the line where the lid meets the body. The lid turns about this line on
    /// the back face.
    static let seam = CaseModelData.seam * scale
    /// The status light, on the front face.
    static let light = CaseModelData.light * scale

    /// Where an AirPod sits. Both lean back the same way; the right one is across the
    /// middle from the left.
    static func podTransform(right: Bool) -> simd_float4x4 {
        var m = CaseModelData.pod
        m.columns.3 = SIMD4<Float>(m.columns.3.x * scale * (right ? -1 : 1), m.columns.3.y * scale, m.columns.3.z * scale, 1)
        return m
    }

    private static let bytes = Data(base64Encoded: CaseModelData.packed.joined()) ?? Data()

    /// One part, in scene units.
    /// - Parameters:
    ///   - mirrored: Flipped left to right: the right AirPod is the left one in a mirror.
    ///   - tint: Multiplies the tone baked into each vertex (its share of ambient light,
    ///     and on an AirPod its black windows). Leave it at 1 for a part whose shade is its
    ///     material's.
    static func geometry(_ name: String, material: SCNMaterial, mirrored: Bool = false, tint: Float = 1) -> SCNGeometry {
        guard let part = CaseModelData.parts.first(where: { $0.name == name }) else {
            assertionFailure("No part named \(name) in the case model")
            return SCNGeometry()
        }
        var positions = [SIMD3<Float>](repeating: .zero, count: part.vertices)
        var normals = [SIMD3<Float>](repeating: .zero, count: part.vertices)
        var colors = [SIMD4<Float>](repeating: .zero, count: part.vertices)
        var indices = [UInt32](repeating: 0, count: part.indices)
        let span = part.high - part.low
        let flip: Float = mirrored ? -1 : 1

        bytes.withUnsafeBytes { raw in
            guard raw.count >= part.offset + part.vertices * 10 + part.indices * (part.wide ? 4 : 2) else { return }
            for v in 0..<part.vertices {
                let at = part.offset + v * 10
                var p = SIMD3<Float>.zero, n = SIMD3<Float>.zero
                for axis in 0..<3 {
                    let step = UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: at + axis * 2, as: UInt16.self))
                    p[axis] = part.low[axis] + span[axis] * Float(step) / 65535
                    n[axis] = Float(raw.load(fromByteOffset: at + 6 + axis, as: Int8.self)) / 127
                }
                p.x *= flip
                n.x *= flip
                let tone = Float(raw[at + 9]) / 255 * tint
                positions[v] = p * scale
                normals[v] = simd_normalize(n)
                colors[v] = SIMD4(tone, tone, tone, 1)
            }
            let start = part.offset + part.vertices * 10
            for i in 0..<part.indices {
                indices[i] = part.wide
                    ? UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: start + i * 4, as: UInt32.self))
                    : UInt32(UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: start + i * 2, as: UInt16.self)))
            }
        }
        // A mirror turns every triangle inside out; winding each the other way turns it back.
        if mirrored {
            for t in stride(from: 0, to: indices.count - 2, by: 3) { indices.swapAt(t + 1, t + 2) }
        }

        func source(_ values: [SIMD3<Float>], _ semantic: SCNGeometrySource.Semantic) -> SCNGeometrySource {
            SCNGeometrySource(
                data: values.withUnsafeBufferPointer { Data(buffer: $0) }, semantic: semantic, vectorCount: values.count,
                usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4,
                dataOffset: 0, dataStride: MemoryLayout<SIMD3<Float>>.stride
            )
        }
        let tone = SCNGeometrySource(
            data: colors.withUnsafeBufferPointer { Data(buffer: $0) }, semantic: .color, vectorCount: colors.count,
            usesFloatComponents: true, componentsPerVector: 4, bytesPerComponent: 4,
            dataOffset: 0, dataStride: MemoryLayout<SIMD4<Float>>.stride
        )
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [source(positions, .vertex), source(normals, .normal), tone], elements: [element])
        geometry.materials = [material]
        return geometry
    }
}
