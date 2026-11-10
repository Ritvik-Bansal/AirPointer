import SwiftUI

// Timing helpers. Every move in the film uses one of two curves: `settle` for things
// arriving (fast out of the gate, easing to rest) and `glide` for things travelling.

/// 0 before `start`, 1 after `start + duration`, linear between.
func span(_ t: Double, from start: Double, over duration: Double) -> Double {
    guard duration > 0 else { return t >= start ? 1 : 0 }
    return min(max((t - start) / duration, 0), 1)
}

/// Exponential ease-out.
func settle(_ x: Double) -> Double { x >= 1 ? 1 : 1 - pow(2, -10 * x) }

/// Ease in and out, for moves that start and stop.
func glide(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }

func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

