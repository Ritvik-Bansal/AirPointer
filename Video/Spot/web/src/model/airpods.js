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

