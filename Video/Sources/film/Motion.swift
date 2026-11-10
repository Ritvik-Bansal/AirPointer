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

/// When a piece of text is on screen: in at `start`, out at `end` (nil stays to the scene's end).
struct Cue {
    var start: Double
    var end: Double?

    /// 0…1 arrival.
    func arrive(_ t: Double, over duration: Double = 0.7) -> Double { settle(span(t, from: start, over: duration)) }
    /// 0…1 departure.
    func leave(_ t: Double, over duration: Double = 0.28) -> Double {
        guard let end else { return 0 }
        return span(t, from: end - duration, over: duration)
    }
}

extension View {
    /// Text rises into place from behind its own baseline and fades out when its cue ends.
    /// The mask is the text's own frame, so nothing is seen below the line it sits on.
    func reveal(_ t: Double, _ cue: Cue, delay: Double = 0) -> some View {
        let shifted = Cue(start: cue.start + delay, end: cue.end)
        let a = shifted.arrive(t), out = shifted.leave(t)
        return self
            .hidden()
            .overlay(alignment: .topLeading) {
                GeometryReader { proxy in
                    self.offset(y: (1 - a) * proxy.size.height * 1.05)
                }
            }
            .clipped()
            .opacity((t >= shifted.start ? 1 : 0) * (1 - out))
    }
}
