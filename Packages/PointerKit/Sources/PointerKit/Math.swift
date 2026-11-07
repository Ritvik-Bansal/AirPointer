import Foundation
import simd

public typealias Vec2 = SIMD2<Double>
public typealias Vec3 = SIMD3<Double>

public extension Double {
    /// Degrees → radians.
    var radians: Double { self * .pi / 180 }
    /// Radians → degrees.
    var degrees: Double { self * 180 / .pi }
}

@inlinable public func clamp<T: Comparable>(_ x: T, _ lo: T, _ hi: T) -> T { min(max(x, lo), hi) }

@inlinable public func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

/// Hermite ease between 0 and 1, clamped outside that range.
@inlinable public func smoothstep(_ x: Double) -> Double {
    let t = clamp(x, 0, 1)
    return t * t * (3 - 2 * t)
}

/// Blend factor for a one-pole low-pass with the given cutoff, over one step of `dt`.
@inlinable public func lowPassAlpha(cutoffHz: Double, dt: Double) -> Double {
    1 - exp(-2 * .pi * cutoffHz * dt)
}

public extension SIMD3 where Scalar == Double {
    var length: Double { simd_length(self) }
    /// Unit vector, or nil when the vector is too short to have a direction.
    var unit: Vec3? {
        let l = simd_length(self)
        return l > 1e-9 ? self / l : nil
    }
    func dot(_ o: Vec3) -> Double { simd_dot(self, o) }
    func cross(_ o: Vec3) -> Vec3 { simd_cross(self, o) }
}

public extension SIMD2 where Scalar == Double {
    var length: Double { simd_length(self) }
}
