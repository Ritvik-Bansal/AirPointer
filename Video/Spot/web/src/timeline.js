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

// --- The lid and the light -------------------------------------------------------------

/// Lid angle in degrees.
export function lid(t) {
  if (t < CUE.lidShuts) {
    // It lifts, runs past by a couple of degrees and comes to rest.
    const s = span(t, CUE.lidOpens, 0.8)
    const over = Math.sin(clamp(span(t, CUE.lidOpens + 0.5, 0.55)) * Math.PI) * 2.2
    return 102 * outCubic(s) + over * (s > 0 ? 1 : 0)
  }
  // It shuts faster than it opened and lands with a small bounce.
  const s = span(t, CUE.lidShuts, 0.42)
  const bounce = Math.sin(span(t, CUE.lidShuts + 0.42, 0.2) * Math.PI) * 2.4
  return 102 * (1 - inCubic(s)) + (s >= 1 ? bounce : 0)
}

/// How bright the hidden light on the case is, 0 to 1. It comes on when the lid opens and,
/// as on the real case, goes out again a few seconds later.
export const caseLight = t => smooth(span(t, CUE.lightOn, 0.35)) * (1 - smooth(span(t, 9.2, 1.2)))

/// How bright the Mac's screen is, 0 to 1.
export const screenLevel = t => smoother(span(t, CUE.screenWakes, 0.9))

/// True while the pointer is live: lid open and AirPods awake.
export const pointing = t => t > CUE.lidOpens + 0.9 && t < CUE.lidShuts + 0.2

// --- The cursor, and so the case -------------------------------------------------------

// Where the cursor is, in the screen's own points (origin top left). The case is then
// turned to match: it is always aimed at the cursor.
const FEEL_PILL = [UI.window.x + 200, UI.window.y + 631]
/// What the Speed slider is set to by the click in shot 4, and where on its track that is.
export const SPEED_AFTER = 2.0
const SPEED_TRACK = [
  UI.window.x + UI.panel.trackFrom + 12 + (UI.panel.trackWidth - 24) * (SPEED_AFTER - 0.4) / 2.1,
  UI.window.y + 144,
]
const cursorPath = track3([
  [0.0, [790, 470, 0]],
  [5.9, [790, 470, 0]],
  [6.9, [405, 300, 0]],
  [7.8, [300, 250, 0]],
  [8.9, [930, 215, 0]],
  [9.6, [1010, 330, 0]],
  [10.5, [720, 560, 0]],
  [11.5, [FEEL_PILL[0] + 6, FEEL_PILL[1] + 3, 0]],
  [12.0, [FEEL_PILL[0], FEEL_PILL[1], 0]],
  [16.5, [FEEL_PILL[0], FEEL_PILL[1], 0]],
  [17.3, [560, 520, 0]],
  [18.5, [SPEED_TRACK[0] - 22, SPEED_TRACK[1] + 26, 0]],
  [19.4, [SPEED_TRACK[0], SPEED_TRACK[1], 0]],
  [20.9, [SPEED_TRACK[0], SPEED_TRACK[1], 0]],
  [21.6, [735, 420, 0]],
  [22.3, [1035, 300, 0]],
  [23.0, [690, 250, 0]],
  [23.7, [880, 470, 0]],
  [24.6, [760, 440, 0]],
  [30.0, [760, 440, 0]],
])
export function cursor(t) {
  const p = cursorPath(t)
  return { x: p[0], y: p[1] }
}

/// How fast the hand is turning, in degrees a second (what the app's response curve shows).
export function handSpeed(t) {
  const a = aim(t - 1 / 120), b = aim(t + 1 / 120)
  return Math.hypot(b.yaw - a.yaw, b.pitch - a.pitch) * 60
}

// How far the case turns to carry the cursor across the whole screen, in degrees.
const YAW_RANGE = 46, PITCH_RANGE = 28
/// Where the case is aimed, in degrees: yaw positive to the left, pitch positive upward.
function aim(t) {
  const c = cursor(t)
  return { yaw: (0.5 - c.x / UI.width) * YAW_RANGE, pitch: (0.5 - c.y / UI.height) * PITCH_RANGE }
}

/// One tap's knock on the case: 1 at the instant, ringing down quickly.
const knock = age => (age < 0 ? 0 : Math.exp(-age / 0.045) * Math.cos(age * 95))

/// The case: position in metres and turn in degrees.
export function casePose(t) {
  const a = aim(t)
  // Before the lid opens the case is simply presented; it settles into the hand's aim after.
  const held = smooth(span(t, 3.4, 1.6)) * (1 - smooth(span(t, 25.2, 1.0)))
  let x = CASE[0] + 0.0012 * wander(t, 1.3)
  let y = CASE[1] + 0.0016 * wander(t, 4.1)
  let z = CASE[2] + 0.0012 * wander(t, 7.7)
  let yaw = a.yaw * held + 0.35 * wander(t * 1.3, 2.2)
  let pitch = lerp(3, 7, held) + a.pitch * held + 0.3 * wander(t * 1.3, 5.5)
  let roll = 0.35 * wander(t * 1.1, 9.1)
  // Taps land on the back of the case and push it forward.
  for (const tap of TAPS) {
    const k = knock(t - tap)
    z += 0.0008 * k
    pitch -= 0.7 * k
    yaw += 0.4 * k
  }
  return { x, y, z, yaw, pitch, roll }
}

/// Where a tap lands on the back of the case, in its own millimetres: low, and toward the
/// side the camera is on, so that the ring it sends out comes round into view.
export const TAP_AT = { x: -17, y: -6 }

