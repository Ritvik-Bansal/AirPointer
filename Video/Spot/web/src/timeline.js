// The storyboard, as numbers.
//
// Thirty seconds, five shots, one camera that never cuts: each shot ends on the move that
// begins the next, so the film plays as a single take.
//
//   1  Reveal   0.0 -  5.5   The closed case, alone. The lid opens; behind it a screen wakes.
//   2  Aim      5.5 - 12.5   Over the case to the Mac. The case turns, the cursor goes with it.
//   3  Tap     12.5 - 19.0   The camera circles the case and lands beside it. Two taps: a click.
//   4  Tune    19.0 - 25.0   In close on the app. A click on Speed, and the curve answers.
//   5  Close   25.0 - 30.0   Back to the case. The lid shuts. The name.
//
// Everything that happens is a pure function of time, so any frame can be drawn on its own
// and the sound can be laid against the same cues.

import { CASE, SCREEN, UI, screenPoint } from './layout.js'

export const FPS = 30
export const DURATION = 30
export const FRAMES = FPS * DURATION

export const SHOTS = [
  { name: 'Reveal', from: 0.0, to: 5.5 },
  { name: 'Aim', from: 5.5, to: 12.5 },
  { name: 'Tap', from: 12.5, to: 19.0 },
  { name: 'Tune', from: 19.0, to: 25.0 },
  { name: 'Close', from: 25.0, to: 30.0 },
]

/// The moments everything else is hung on.
export const CUE = {
  lidOpens: 2.45,
  lightOn: 3.0,
  screenWakes: 4.1,
  orbit: [12.5, 15.0],
  /// The click that opens the Feel panel: two taps on the side of the case.
  click1: [15.45, 15.72],
  /// The click on the Speed slider.
  click2: [20.3, 20.57],
  lidShuts: 25.9,
  endCard: 26.7,
}
export const TAPS = [...CUE.click1, ...CUE.click2]
/// A click is what the Mac receives when the second tap of a pair lands.
export const CLICKS = [CUE.click1[1], CUE.click2[1]]

// --- Easing ----------------------------------------------------------------------------

export const clamp = (v, a = 0, b = 1) => Math.min(Math.max(v, a), b)
export const span = (t, from, over) => clamp((t - from) / over)
export const smooth = v => { const t = clamp(v); return t * t * (3 - 2 * t) }
export const smoother = v => { const t = clamp(v); return t * t * t * (t * (t * 6 - 15) + 10) }
export const outCubic = v => 1 - Math.pow(1 - clamp(v), 3)
export const outExpo = v => { const t = clamp(v); return t >= 1 ? 1 : 1 - Math.pow(2, -10 * t) }
export const inCubic = v => Math.pow(clamp(v), 3)
export const lerp = (a, b, t) => a + (b - a) * t
/// The app's own layout curve: cubic-bezier(0.16, 1, 0.3, 1).
export const settle = v => bezier(0.16, 1, 0.3, 1, clamp(v))
function bezier(x1, y1, x2, y2, x) {
  let t = x
  for (let i = 0; i < 8; i++) {
    const cx = 3 * x1 * t * (1 - t) ** 2 + 3 * x2 * t * t * (1 - t) + t ** 3
    const dx = 3 * x1 * (1 - t) * (1 - 3 * t) + 3 * x2 * t * (2 - 3 * t) + 3 * t * t
    if (Math.abs(dx) < 1e-6) break
    t = clamp(t - (cx - x) / dx)
  }
  return 3 * y1 * t * (1 - t) ** 2 + 3 * y2 * t * t * (1 - t) + t ** 3
}

/// A smooth curve through keys [[time, value], ...] that never overshoots them
/// (monotone cubic interpolation).
export function track(keys) {
  const n = keys.length
  const x = keys.map(k => k[0]), y = keys.map(k => k[1])
  const d = [], m = new Array(n).fill(0)
  for (let i = 0; i < n - 1; i++) d.push((y[i + 1] - y[i]) / (x[i + 1] - x[i]))
  for (let i = 1; i < n - 1; i++) {
    if (d[i - 1] * d[i] <= 0) continue
    const w1 = 2 * (x[i + 1] - x[i]) + (x[i] - x[i - 1]), w2 = (x[i + 1] - x[i]) + 2 * (x[i] - x[i - 1])
    m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])
  }
  return t => {
    if (t <= x[0]) return y[0]
    if (t >= x[n - 1]) return y[n - 1]
    let i = 0
    while (t > x[i + 1]) i++
    const h = x[i + 1] - x[i], s = (t - x[i]) / h
    const s2 = s * s, s3 = s2 * s
    return (2 * s3 - 3 * s2 + 1) * y[i] + (s3 - 2 * s2 + s) * h * m[i] + (-2 * s3 + 3 * s2) * y[i + 1] + (s3 - s2) * h * m[i + 1]
  }
}
/// The same, for points: keys are [[time, [x, y, z]], ...].
function track3(keys) {
  const parts = [0, 1, 2].map(i => track(keys.map(k => [k[0], k[1][i]])))
  return t => parts.map(p => p(t))
}

/// Slow, steady wander: a few sines that never line up. Used wherever something is held in
/// a hand or on a camera arm rather than bolted down.
const wander = (t, seed) =>
  0.5 * Math.sin(t * 0.83 + seed) + 0.3 * Math.sin(t * 1.37 + seed * 2.1) + 0.2 * Math.sin(t * 2.31 + seed * 3.7)

