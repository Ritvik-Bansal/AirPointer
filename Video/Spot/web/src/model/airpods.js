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

