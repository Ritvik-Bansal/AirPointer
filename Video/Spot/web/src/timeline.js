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

// --- The camera ------------------------------------------------------------------------

const rad = Math.PI / 180
/// A point on a circle about the case: azimuth 0 is in front, positive toward the right.
const orbit = (az, r, h) => [CASE[0] + r * Math.sin(az * rad), CASE[1] + h, CASE[2] + r * Math.cos(az * rad)]
const mix3 = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)]
const add3 = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]]
const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2])
const toScreen = w => mix3(CASE, SCREEN.centre, w)
const SLIDER_POINT = screenPoint(SPEED_TRACK[0], SPEED_TRACK[1] + 60)
// Shot 4 holds the whole window, set to the left so the right of the picture is free for
// the words: this is the point on the screen that sits in the middle of the frame.
const WINDOW_VIEW = screenPoint(UI.window.x + 672, UI.window.y + 342)
// A quarter of the way from the case to the screen. With the lens stopped down and the
// focus set here, the case and the screen are both held: a tap and its click in one look.
const MIDWAY = toScreen(0.25)
/// A place in front of the screen: `out` metres off a point on it, a little left and above.
function before(point, out) {
  const d = [0, 1, 2].map(i => SCREEN.facing[i] - 0.17 * SCREEN.right[i] + 0.07 * SCREEN.up[i])
  const n = Math.hypot(d[0], d[1], d[2])
  return [point[0] + d[0] / n * out, point[1] + d[1] / n * out, point[2] + d[2] / n * out]
}

// Each key: time, where the camera is, what it looks at, field of view (degrees, vertical),
// what is in focus ('case', 'screen', or a point), and the lens opening (its radius in mm).
const KEYS = [
  // 1 Reveal: a slow arc in on the closed case, rising as the lid opens.
  { t: 0.0, at: orbit(-34, 0.305, 0.03), look: add3(CASE, [-0.036, 0.002, 0]), fov: 21, focus: 'case', lens: 1.6 },
  { t: 2.4, at: orbit(-23, 0.262, 0.045), look: add3(CASE, [-0.031, 0.006, 0]), fov: 21, focus: 'case', lens: 1.6 },
  { t: 3.9, at: orbit(-13, 0.255, 0.098), look: add3(CASE, [-0.022, 0.016, 0]), fov: 21.5, focus: 'case', lens: 1.8 },
  { t: 4.8, at: orbit(-12, 0.30, 0.106), look: add3(toScreen(0.32), [-0.01, 0.01, 0]), fov: 23, focus: 'case', lens: 2.2 },
  // 2 Aim: over the case to the screen, on a longer lens so the screen is large behind it
  // and stopped down so the case in front stays readable as it turns.
  { t: 5.9, at: orbit(-15, 0.40, 0.082), look: toScreen(0.66), fov: 20, focus: 'screen', lens: 1.1 },
  { t: 9.0, at: orbit(-18, 0.385, 0.078), look: toScreen(0.66), fov: 20, focus: 'screen', lens: 1.1 },
  { t: 11.7, at: orbit(-16, 0.36, 0.072), look: toScreen(0.6), fov: 20.5, focus: 'screen', lens: 1.1 },
  // 3 Tap: once round the case, the long way: past its right side, low behind it to look
  // up at the hinge, and round to land in front of its left side.
  { t: 12.5, at: orbit(-4, 0.30, 0.056), look: toScreen(0.2), fov: 23, focus: 'case', lens: 2.2 },
  { t: 12.9, at: orbit(34, 0.225, 0.036), look: CASE, fov: 24, focus: 'case', lens: 2.2 },
  { t: 13.25, at: orbit(88, 0.195, 0.012), look: CASE, fov: 24, focus: 'case', lens: 2.2 },
  { t: 13.6, at: orbit(146, 0.186, -0.04), look: add3(CASE, [0, 0.004, 0]), fov: 24, focus: 'case', lens: 2.2 },
  { t: 13.95, at: orbit(200, 0.186, -0.052), look: add3(CASE, [0, 0.005, 0]), fov: 24, focus: 'case', lens: 2.2 },
  { t: 14.3, at: orbit(258, 0.20, -0.012), look: CASE, fov: 24, focus: 'case', lens: 2.2 },
  { t: 14.65, at: orbit(302, 0.25, 0.04), look: toScreen(0.06), fov: 24, focus: 'case', lens: 2.0 },
  // It lands with the case in front and the screen behind, and holds both in focus while
  // the two taps land and the click they make plays out on the screen.
  { t: 15.1, at: orbit(318, 0.302, 0.056), look: toScreen(0.21), fov: 23, focus: MIDWAY, lens: 0.85 },
  { t: 16.3, at: orbit(321, 0.316, 0.06), look: toScreen(0.27), fov: 23, focus: MIDWAY, lens: 0.85 },
  { t: 17.2, at: orbit(322, 0.32, 0.064), look: toScreen(0.3), fov: 23, focus: 'screen', lens: 2.4 },
  // 4 Tune: over the case and in, until the app's window fills the left of the picture.
  { t: 18.4, at: [-0.118, 0.262, 0.03], look: mix3(toScreen(0.8), WINDOW_VIEW, 0.65), fov: 23.5, focus: 'screen', lens: 2.8 },
  { t: 19.6, at: before(WINDOW_VIEW, 0.477), look: WINDOW_VIEW, fov: 23, focus: SLIDER_POINT, lens: 2.6 },
  { t: 22.8, at: before(WINDOW_VIEW, 0.447), look: WINDOW_VIEW, fov: 23, focus: SLIDER_POINT, lens: 2.6 },
  { t: 23.5, at: before(WINDOW_VIEW, 0.452), look: WINDOW_VIEW, fov: 23, focus: 'screen', lens: 2.6 },
  // 5 Close: straight back out the way it came in, so the case comes back into the picture
  // with the screen still behind it; then up, to look down on it with the desk behind.
  { t: 24.6, at: orbit(322, 0.325, 0.068), look: toScreen(0.27), fov: 23, focus: 'case', lens: 2.2 },
  { t: 25.5, at: orbit(325, 0.30, 0.104), look: add3(toScreen(0.06), [0.02, 0, 0]), fov: 22.5, focus: 'case', lens: 1.7 },
  { t: 26.7, at: orbit(330, 0.268, 0.142), look: add3(CASE, [0.052, -0.006, 0]), fov: 21.5, focus: 'case', lens: 1.3 },
  { t: 30.0, at: orbit(336, 0.258, 0.148), look: add3(CASE, [0.054, -0.006, 0]), fov: 21.5, focus: 'case', lens: 1.3 },
]

// The keys round the case are close enough together that the curve through them stays round.
const camAt = track3(KEYS.map(k => [k.t, k.at]))
const camLook = track3(KEYS.map(k => [k.t, k.look]))
const camFov = track(KEYS.map(k => [k.t, k.fov]))
const camLens = track(KEYS.map(k => [k.t, k.lens]))
// Focus is interpolated as its reciprocal, the way a lens barrel turns: a pull from near to
// far spends its time evenly across the blur rather than rushing the near end.
const camFocus = track(KEYS.map(k => {
  const target = k.focus === 'case' ? CASE : k.focus === 'screen' ? SCREEN.centre : k.focus
  return [k.t, 1 / dist(k.at, target)]
}))

export function camera(t) {
  const at = camAt(t), look = camLook(t)
  // The camera arm is never dead still.
  at[0] += 0.0009 * wander(t * 0.6, 11.3)
  at[1] += 0.0007 * wander(t * 0.6, 14.9)
  let focus = 1 / camFocus(t)
  // Leaving shot 4, the focus follows the screen as the camera backs away from it, and goes
  // to the case only as the case comes into the picture. Pulled evenly across the move,
  // there is a stretch in the middle with nothing sharp.
  if (t > 23.5 && t < 24.6) {
    const pull = smooth((t - 24.22) / 0.38)
    focus = 1 / lerp(1 / dist(at, SCREEN.centre), 1 / dist(at, CASE), pull)
  }
  return { at, look, fov: camFov(t), focus, lens: camLens(t) / 1000 }
}

// --- What is on the screen -------------------------------------------------------------

/// How far the Feel panel has slid in: 0 closed, 1 open.
export const panelOpen = t => settle(span(t, CLICKS[0] + 0.03, 0.42))
/// The Speed setting.
export const speed = t => lerp(1.0, SPEED_AFTER, outCubic(span(t, CLICKS[1] + 0.03, 0.2)))
/// Whether the cursor is over a pill or a control (it is drawn pressed at a click).
export const pressed = t => CLICKS.some(c => t >= c && t < c + 0.12)

