// Solids described as distance fields, and a mesher that turns one into triangles.
//
// A field is a function (x, y, z) -> number: negative inside the solid, positive outside,
// and close to the distance from the surface in millimetres. Shapes are combined with min
// and max; the smooth versions leave a small fillet where two surfaces meet, which is what
// catches the light on a real moulded part.
//
// The mesher is naive surface nets: one vertex in every grid cell the surface passes
// through, joined into quads. Each vertex is then pulled exactly onto the surface, and its
// normal is the field's own gradient, so shading is smooth however coarse the grid is.
//
// Runs unchanged in Node (the bake) and in the browser.

export const smin = (a, b, k) => {
  const h = Math.max(k - Math.abs(a - b), 0) / k
  return Math.min(a, b) - h * h * k * 0.25
}
export const smax = (a, b, k) => {
  const h = Math.max(k - Math.abs(a - b), 0) / k
  return Math.max(a, b) + h * h * k * 0.25
}

/// Rounded rectangle in the plane: half-size (hx, hy), corner radius r.
export const roundRect2 = (x, y, hx, hy, r) => {
  const qx = Math.abs(x) - (hx - r), qy = Math.abs(y) - (hy - r)
  return Math.min(Math.max(qx, qy), 0) + Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) - r
}

/// Rounded box: half-size (hx, hy, hz) measured to the outside, edge radius r.
export const roundBox = (x, y, z, hx, hy, hz, r) => {
  const qx = Math.abs(x) - (hx - r), qy = Math.abs(y) - (hy - r), qz = Math.abs(z) - (hz - r)
  return Math.min(Math.max(qx, qy, qz), 0)
    + Math.hypot(Math.max(qx, 0), Math.max(qy, 0), Math.max(qz, 0)) - r
}

/// Ellipsoid with semi-axes (a, b, c). Not an exact distance, but a good one near the surface.
export const ellipsoid = (x, y, z, a, b, c) => {
  const k0 = Math.hypot(x / a, y / b, z / c)
  if (k0 < 1e-9) return -Math.min(a, b, c)
  const k1 = Math.hypot(x / (a * a), y / (b * b), z / (c * c))
  return k0 * (k0 - 1) / k1
}

/// A box with every face bulged: |x/a|^n + |y/b|^n + |z/c|^n = 1.
export const superEllipsoid = (x, y, z, a, b, c, n) => {
  const m = Math.pow(
    Math.pow(Math.abs(x) / a, n) + Math.pow(Math.abs(y) / b, n) + Math.pow(Math.abs(z) / c, n),
    1 / n
  )
  return (m - 1) * Math.min(a, b, c)
}

/// Capsule between two points, radius r.
export const capsule = (x, y, z, ax, ay, az, bx, by, bz, r) => {
  const px = x - ax, py = y - ay, pz = z - az
  const dx = bx - ax, dy = by - ay, dz = bz - az
  let t = (px * dx + py * dy + pz * dz) / (dx * dx + dy * dy + dz * dz)
  t = t < 0 ? 0 : t > 1 ? 1 : t
  return Math.hypot(px - dx * t, py - dy * t, pz - dz * t) - r
}

/// Stadium (a line with rounded ends) in the plane, along the first axis.
export const stadium2 = (u, v, halfLength, r) =>
  Math.hypot(Math.max(Math.abs(u) - halfLength, 0), v) - r

// ---------------------------------------------------------------------------------------

