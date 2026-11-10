// AirPods Pro 3 and their case, as solids. Millimetres throughout.
//
// Axes of the case: x to the right as you face its front, y up, z out of the front toward
// you. The origin is the middle of the closed case.
//
// Sources for the numbers:
//  - Overall size from the published specification: the case is 62.2 wide, 47.2 tall and
//    21.8 deep; an AirPod is 30.9 tall, 19.2 wide and 27.0 deep.
//  - Everything else is measured off photographs of a real case and scaled by those: the lid
//    line 14.1 below the top, the rounder bottom corners, the hinge plate on the back (28.6
//    by 5.6, split into a T and two blocks), the lanyard plate on the right side, the port,
//    the one hole to its left and three to its right, the thumb scoop on the front, the
//    hidden light under it, and how the AirPods sit: stems down at the outer ends, tips
//    turned in toward each other.
//
// Measured off photographs means close, not exact: expect a few tenths of a millimetre.

import { smin, smax, roundRect2, roundBox, ellipsoid, superEllipsoid, capsule, stadium2 } from './sdf.js'

export const DIM = { W: 31.1, H: 23.6, D: 10.9, lid: 14.1, gap: 0.24, wall: 1.5 }
export const SEAM = DIM.H - DIM.lid
const BODY_TOP = SEAM - DIM.gap / 2
const LID_BOTTOM = SEAM + DIM.gap / 2

/// Where the lid turns: along x, on the back surface at the lid line.
export const HINGE_AXIS = { y: SEAM, z: -DIM.D }
/// How far the lid swings open, in degrees.
export const LID_OPEN = 102

// --- The outer shape -------------------------------------------------------------------

// The outline seen from the front is a rectangle whose corners are superellipse arcs rather
// than circles, so curvature builds gradually into each corner (no line where flat meets
// round). The bottom corners are rounder than the top ones.
const R_TOP = 13.4, R_BOTTOM = 16.2, N_OUTLINE = 2.55
// Front to back the profile is a superellipse too: nearly flat faces rolling over into
// sides that are almost, but not quite, a half circle.
const R_PROFILE = 12.0, N_PROFILE = 2.3

function outline(x, y) {
  const r = y >= 0 ? R_TOP : R_BOTTOM
  const qx = Math.abs(x) - (DIM.W - r), qy = Math.abs(y) - (DIM.H - r)
  if (qx > 0 && qy > 0) return Math.pow(Math.pow(qx, N_OUTLINE) + Math.pow(qy, N_OUTLINE), 1 / N_OUTLINE) - r
  return Math.max(qx, qy) - r
}

/// The closed case as one pebble.
export function shell(x, y, z) {
  const u = Math.max(outline(x, y) + R_PROFILE, 0) / R_PROFILE
  const v = Math.abs(z) / DIM.D
  if (u <= 0) return (v - 1) * DIM.D
  return (Math.pow(Math.pow(u, N_PROFILE) + Math.pow(v, N_PROFILE), 1 / N_PROFILE) - 1) * DIM.D
}

// --- Details cut into the plastic ------------------------------------------------------

// The shallow dip on the front where a thumb lifts the lid. It straddles the lid line, and
// is a soft change of level rather than a cut: the surface simply sits lower there.
const smooth = (a, b, v) => { const t = Math.min(Math.max((v - a) / (b - a), 0), 1); return t * t * (3 - 2 * t) }
const scoop = (x, y, z) => 0.2
  * (1 - smooth(10.4, 14.9, Math.abs(x)))
  * (1 - smooth(0.3, 2.7, Math.abs(y - (SEAM + 0.5))))
  * smooth(DIM.D - 3, DIM.D - 1.2, z)

// The hinge plate on the back: one rounded rectangle of metal, split into a T that stays
// with the body and two blocks that travel with the lid.
const HINGE = { half: 14.3, bottom: SEAM - 1.9, top: SEAM + 3.7, corner: 1.0, depth: 1.25, tab: 8.1, slit: 0.07 }
const hingeOutline = (x, y, grow) => roundRect2(
  x, y - (HINGE.bottom + HINGE.top) / 2,
  HINGE.half + grow, (HINGE.top - HINGE.bottom) / 2 + grow, HINGE.corner + grow
)
const hingePocket = (x, y, z) => Math.max(hingeOutline(x, y, 0.08), z - (-DIM.D + HINGE.depth))

// The lanyard plate on the right side: a small metal stadium with two holes.
const LANYARD = { y: SEAM - 5.7, half: 1.25, r: 1.95, sink: 0.1, depth: 0.9, hole: 0.98, pitch: 1.32 }
const lanyardPocket = (x, y, z) => Math.min(
  Math.max(stadium2(y - LANYARD.y, z, LANYARD.half, LANYARD.r + 0.05), (DIM.W - LANYARD.depth) - x),
  Math.max(lanyardHoles(y, z) - 0.02, (DIM.W - 2.6) - x)
)
const lanyardHoles = (y, z) => Math.min(
  Math.hypot(y - LANYARD.y - LANYARD.pitch, z), Math.hypot(y - LANYARD.y + LANYARD.pitch, z)
) - LANYARD.hole

// The port on the bottom, the hole to its left and the three speaker holes to its right.
const PORT = { half: 2.89, r: 1.28, liner: 0.42, depth: 5.2 }
const portHole = (x, y, z) => Math.max(stadium2(x, z, PORT.half, PORT.r + PORT.liner + 0.03), y - (-DIM.H + PORT.depth))
export const HOLES = [-12.3, 12.2, 14.5, 16.9]
const smallHoles = (x, y, z) => {
  let d = 1e9
  for (const hx of HOLES) d = Math.min(d, Math.hypot(x - hx, z) - 0.5)
  return Math.max(d, y - (-DIM.H + 1.1))
}

// --- How an AirPod sits in the case ----------------------------------------------------

// An AirPod has its own axes: origin at the foot of the stem, y up the stem, x toward the
// ear tip, z toward the face that carries the black sensor window. In the left well the tip
// points right (toward the middle) and the stem leans back a little.
const LEAN = -8 * Math.PI / 180
export const BUD_HOME = { x: -24.3, y: -10.42, z: 2.7, lean: LEAN }

/// A point of the left AirPod, from its own axes into the case's.
function budToCase(px, py, pz) {
  const c = Math.cos(LEAN), s = Math.sin(LEAN)
  return [BUD_HOME.x + px, BUD_HOME.y + py * c - pz * s, BUD_HOME.z + py * s + pz * c]
}
/// A point in the case's axes, into the left AirPod's own.
function caseToBud(x, y, z) {
  const c = Math.cos(LEAN), s = Math.sin(LEAN)
  const qy = y - BUD_HOME.y, qz = z - BUD_HOME.z
  return [x - BUD_HOME.x, qy * c + qz * s, -qy * s + qz * c]
}

const HEAD = { x: 5.6, y: 22.3, a: 8.9, b: 8.2, c: 7.7 }
const TIP = (() => {
  const down = -5 * Math.PI / 180, out = 6 * Math.PI / 180
  return {
    x: 13.0, y: 20.4, z: 0.3,
    dx: Math.cos(down) * Math.cos(out), dy: Math.sin(down), dz: Math.cos(down) * Math.sin(out),
    length: 9.5, bore: 2.15, boreFrom: 6.7,
  }
})()

// The two wells in the body: a bore for the stem, a bowl for the head, a rest for the tip.
const [boreFootX, boreFootY, boreFootZ] = budToCase(0, -0.7, 0)
const [boreTopX, boreTopY, boreTopZ] = budToCase(0, 26, 0)
const [bowlX, bowlY, bowlZ] = budToCase(HEAD.x, HEAD.y, 0)
const [restX, restY, restZ] = budToCase(TIP.x + TIP.dx * 4.4, TIP.y + TIP.dy * 4.4, TIP.z + TIP.dz * 4.4)
function wells(x, y, z) {
  const ax = -Math.abs(x) // both wells, as the left one
  const bore = capsule(ax, y, z, boreFootX, boreFootY, boreFootZ, boreTopX, boreTopY, boreTopZ, 3.75)
  const bowl = ellipsoid(ax - bowlX, y - bowlY, z - bowlZ, 9.5, 8.9, 8.35)
  const rest = ellipsoid(ax - restX, y - restY, z - restZ, 4.75, 6.5, 6.5)
  return smin(smin(bore, bowl, 2.4), rest, 1.8)
}

// --- The parts -------------------------------------------------------------------------

/// The lower part of the case.
export function body(x, y, z) {
  const whole = shell(x, y, z)
  const s = whole + scoop(x, y, z)
  let d = smax(s, y - BODY_TOP, 0.3)
  const inside = whole + DIM.wall
  const deck = smax(inside, (BODY_TOP - 1.0) - y, 0.7)
  const hollow = smin(deck, smax(wells(x, y, z), inside, 0.8), 1.0)
  d = smax(d, -hollow, 0.36)
  d = smax(d, -hingePocket(x, y, z), 0.1)
  d = smax(d, -lanyardPocket(x, y, z), 0.12)
  d = smax(d, -portHole(x, y, z), 0.16)
  d = smax(d, -smallHoles(x, y, z), 0.1)
  return d
}

/// The lid, in the closed position.
export function lid(x, y, z) {
  const whole = shell(x, y, z)
  const s = whole + scoop(x, y, z)
  let d = smax(s, LID_BOTTOM - y, 0.3)
  const inside = whole + DIM.wall
  const step = smax(inside, y - (LID_BOTTOM + 0.55), 0.7)
  const bowl = smax(
    superEllipsoid(Math.abs(x) - 14.35, y - (LID_BOTTOM + 0.2), z + 0.15, 12.55, 11.3, 8.55, 2.5),
    whole + 1.25, 0.8
  )
  d = smax(d, -smin(step, bowl, 1.3), 0.36)
  d = smax(d, -hingePocket(x, y, z), 0.1)
  return d
}

/// The T of the hinge plate, and the bar seen at the back of the open body.
export function hingeBody(x, y, z) {
  const region = Math.max(hingeOutline(x, y, 0), Math.min(y - (SEAM - HINGE.slit), Math.abs(x) - (HINGE.tab - HINGE.slit)))
  const plate = smax(smax(region, z - (-DIM.D + HINGE.depth - 0.03), 0.1), (-DIM.D + 0.025) - z, 0.14)
  const bar = roundBox(x, y - (BODY_TOP - 0.75), z - (-DIM.D + 1.75), 9.4, 0.8, 0.42, 0.2)
  return Math.min(plate, bar)
}

/// The two blocks of the hinge plate that belong to the lid, and the bar inside it.
export function hingeLid(x, y, z) {
  const region = Math.max(hingeOutline(x, y, 0), (SEAM + HINGE.slit) - y, (HINGE.tab + HINGE.slit) - Math.abs(x))
  const plate = smax(smax(region, z - (-DIM.D + HINGE.depth - 0.03), 0.1), (-DIM.D + 0.025) - z, 0.14)
  const bar = roundBox(x, y - (LID_BOTTOM + 1.05), z - (-DIM.D + 1.7), 13.2, 1.0, 0.42, 0.2)
  return Math.min(plate, bar)
}

/// The lanyard plate.
export function lanyard(x, y, z) {
  const outline = stadium2(y - LANYARD.y, z, LANYARD.half, LANYARD.r)
  let d = smax(smax(outline, x - (DIM.W - LANYARD.sink), 0.16), (DIM.W - LANYARD.depth + 0.03) - x, 0.1)
  d = smax(d, -(lanyardHoles(y, z)), 0.22)
  return d
}

/// The metal liner of the port.
export function port(x, y, z) {
  const outer = stadium2(x, z, PORT.half, PORT.r + PORT.liner)
  const inner = stadium2(x, z, PORT.half, PORT.r)
  let d = smax(outer, -inner, 0.1)
  d = smax(d, (-DIM.H + 0.05) - y, 0.16)
  d = Math.max(d, y - (-DIM.H + PORT.depth - 0.1))
  return d
}

/// The tongue inside the port and the floor behind it.
export function portCore(x, y, z) {
  const tongue = roundBox(x, y - (-DIM.H + 2.6), z, 3.3, 1.9, 0.36, 0.2)
  const floor = Math.max(stadium2(x, z, PORT.half, PORT.r + 0.1), Math.abs(y - (-DIM.H + 4.7)) - 0.3)
  return Math.min(tongue, floor)
}

/// One AirPod without its ear tip, in its own axes.
export function bud(x, y, z) {
  // The stem: very slightly oval, with a flat foot.
  // (A capsule that ends inside the head: a hard cap there would crease the head's surface.)
  const stem = smax(capsule(x, y, z / 0.94, 0, -6, 0, 0, 21.5, 0, 3.02), -y, 0.5)
  // The head: an egg, fuller toward the tip and underneath.
  const crown = ellipsoid(x - HEAD.x, y - HEAD.y, z, HEAD.a, HEAD.b, HEAD.c)
  const jaw = ellipsoid(x - 8.3, y - 20.5, z, 6.3, 6.6, 6.45)
  let d = smin(smin(crown, jaw, 2.6), stem, 4.4)
  // The short collar the tip clips over.
  const sx = x - TIP.x, sy = y - TIP.y, sz = z - TIP.z
  const along = sx * TIP.dx + sy * TIP.dy + sz * TIP.dz
  const across = Math.sqrt(Math.max(sx * sx + sy * sy + sz * sz - along * along, 0))
  d = smin(d, Math.max(across - 3.4, along - 3.0, -along - 6), 1.2)
  return d
}

/// The silicone ear tip, in the AirPod's axes.
export function tip(x, y, z) {
  const sx = x - TIP.x, sy = y - TIP.y, sz = z - TIP.z
  const along = sx * TIP.dx + sy * TIP.dy + sz * TIP.dz
  const across = Math.sqrt(Math.max(sx * sx + sy * sy + sz * sz - along * along, 0))
  // A dome: widest just off the base, closing toward the front.
  const k0 = Math.hypot((along - 2.2) / 9.2, across / 5.75)
  const k1 = Math.hypot((along - 2.2) / 84.64, across / 33.06)
  let d = k0 * (k0 - 1) / k1
  d = smax(d, along - TIP.length, 1.0)
  d = smax(d, 0.15 - along, 0.5)
  d = smax(d, -Math.max(across - TIP.bore, TIP.boreFrom - along), 0.8)
  return d
}

/// The dark mesh a little way down the tip's bore, as a centre and a facing direction.
export const TIP_MESH = {
  at: [TIP.x + TIP.dx * (TIP.boreFrom + 0.9), TIP.y + TIP.dy * (TIP.boreFrom + 0.9), TIP.z + TIP.dz * (TIP.boreFrom + 0.9)],
  facing: [TIP.dx, TIP.dy, TIP.dz],
  radius: TIP.bore + 0.3,
}

// --- The black windows on an AirPod ----------------------------------------------------

// Each is an ellipse laid on the head's surface: a centre on the surface, the direction it
// faces, the direction of its long axis, and its two half-sizes. They are flush with the
// head, so they are painted by the material (colour, finish and a fine groove at the edge)
// rather than cut into the mesh, which keeps their edges sharp at any distance.
function onCrown(px, py, sign) {
  const t = 1 - ((px - HEAD.x) / HEAD.a) ** 2 - ((py - HEAD.y) / HEAD.b) ** 2
  return sign * HEAD.c * Math.sqrt(Math.max(t, 0))
}
function crownNormal(px, py, pz) {
  const n = [(px - HEAD.x) / HEAD.a ** 2, (py - HEAD.y) / HEAD.b ** 2, pz / HEAD.c ** 2]
  const len = Math.hypot(...n)
  return n.map(v => v / len)
}
function makeWindow(name, px, py, pz, long, a, b, finish) {
  const normal = crownNormal(px, py, pz)
  // Long axis: the given direction with its out-of-surface part removed.
  const dot = long[0] * normal[0] + long[1] * normal[1] + long[2] * normal[2]
  let u = [long[0] - normal[0] * dot, long[1] - normal[1] * dot, long[2] - normal[2] * dot]
  const ul = Math.hypot(...u); u = u.map(v => v / ul)
  const v = [normal[1] * u[2] - normal[2] * u[1], normal[2] * u[0] - normal[0] * u[2], normal[0] * u[1] - normal[1] * u[0]]
  return { name, at: [px, py, pz], normal, u, v, a, b, finish }
}
export const WINDOWS = [
  // The sensor window on the front of the head: glossy black, the one you see in the case.
  makeWindow('sensor', 9.3, 27.5, onCrown(9.3, 27.5, 1), [0.82, -0.57, 0], 2.25, 1.5, 'gloss'),
  // The vent on top.
  makeWindow('top', 3.4, 30.2, onCrown(3.4, 30.2, -1) * 0.999, [0, 0, 1], 2.3, 1.05, 'mesh'),
  // The long grille down the back of the head.
  makeWindow('back', HEAD.x - HEAD.a * Math.sqrt(1 - ((24.2 - HEAD.y) / HEAD.b) ** 2 - 0.05), 24.2, -HEAD.c * Math.sqrt(0.05), [0, 1, 0], 4.3, 1.75, 'mesh'),
]
// --- What gets baked -------------------------------------------------------------------

const leftBud = (x, y, z) => { const p = caseToBud(x, y, z); return bud(p[0], p[1], p[2]) }
const leftTip = (x, y, z) => { const p = caseToBud(x, y, z); return tip(p[0], p[1], p[2]) }
/// Everything in the open case below the lid, for working out where light cannot reach.
function docked(x, y, z) {
  const ax = -Math.abs(x)
  return Math.min(body(x, y, z), leftBud(ax, y, z), leftTip(ax, y, z))
}
/// The same seen from an AirPod's own axes.
function dockedFromBud(x, y, z) {
  const p = budToCase(x, y, z)
  return docked(p[0], p[1], p[2])
}

const B = DIM
export const PARTS = [
  { name: 'body', field: body, bounds: [-B.W - 0.6, -B.H - 0.6, -B.D - 0.6, B.W + 0.6, BODY_TOP + 0.8, B.D + 0.6], cell: [0.2, 0.5], occluder: docked },
  { name: 'lid', field: lid, bounds: [-B.W - 0.6, LID_BOTTOM - 0.8, -B.D - 0.6, B.W + 0.6, B.H + 0.6, B.D + 0.6], cell: [0.2, 0.5], occluder: lid },
  { name: 'hingeBody', field: hingeBody, bounds: [-15, SEAM - 3.2, -B.D - 0.5, 15, SEAM + 4.4, -B.D + 3.6], cell: [0.09, 0.2], occluder: (x, y, z) => Math.min(hingeBody(x, y, z), body(x, y, z)) },
  { name: 'hingeLid', field: hingeLid, bounds: [-15, SEAM - 0.5, -B.D - 0.5, 15, SEAM + 4.4, -B.D + 3.4], cell: [0.09, 0.2], occluder: (x, y, z) => Math.min(hingeLid(x, y, z), lid(x, y, z)) },
  { name: 'lanyard', field: lanyard, bounds: [B.W - 1.4, LANYARD.y - 3.8, -2.6, B.W + 0.4, LANYARD.y + 3.8, 2.6], cell: [0.06, 0.15], occluder: lanyard },
  { name: 'port', field: port, bounds: [-5.4, -B.H - 0.4, -2.3, 5.4, -B.H + PORT.depth + 0.3, 2.3], cell: [0.07, 0.15], occluder: (x, y, z) => Math.min(port(x, y, z), portCore(x, y, z)) },
  { name: 'portCore', field: portCore, bounds: [-5.4, -B.H + 0.2, -2.3, 5.4, -B.H + PORT.depth + 0.6, 2.3], cell: [0.09, 0.2], occluder: (x, y, z) => Math.min(port(x, y, z), portCore(x, y, z)) },
  { name: 'bud', field: bud, bounds: [-4.6, -0.8, -9, 16.5, 31.6, 9], cell: [0.16, 0.4], occluder: dockedFromBud },
  { name: 'tip', field: tip, bounds: [12.5, 13, -7.5, 24.5, 27.5, 8.5], cell: [0.14, 0.35], occluder: dockedFromBud },
]

/// Placement of the left AirPod's own axes inside the case, as a column-major 4x4.
export function budMatrix() {
  const c = Math.cos(LEAN), s = Math.sin(LEAN)
  return [1, 0, 0, 0, 0, c, s, 0, 0, -s, c, 0, BUD_HOME.x, BUD_HOME.y, BUD_HOME.z, 1]
}

/// The hidden status light: on the front, below the lid line.
export const LIGHT = { x: 0, y: SEAM - 5.3, z: DIM.D, radius: 0.85 }
/// The two lines printed on the back under the hinge.
export const PRINT = { y: SEAM - 4.35, z: -DIM.D, lines: ['Designed by Apple in California', 'Assembled in China'], width: 16.2, pitch: 1.75 }
