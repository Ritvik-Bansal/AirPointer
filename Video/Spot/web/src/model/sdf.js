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

/// Meshes the zero surface of `field` inside `bounds` = [x0, y0, z0, x1, y1, z1].
/// Returns { positions, normals, indices } as typed arrays.
export function surfaceNets(field, bounds, cell, { reach = 1.6 } = {}) {
  const [x0, y0, z0, x1, y1, z1] = bounds
  const nx = Math.ceil((x1 - x0) / cell) + 1
  const ny = Math.ceil((y1 - y0) / cell) + 1
  const nz = Math.ceil((z1 - z0) / cell) + 1
  const vals = new Float32Array(nx * ny * nz)
  const at = (i, j, k) => i + nx * (j + ny * k)

  // Blocks of cells far from the surface are filled in one go rather than sampled.
  const B = 8
  const bx = Math.ceil((nx - 1) / B), by = Math.ceil((ny - 1) / B), bz = Math.ceil((nz - 1) / B)
  const near = new Uint8Array(bx * by * bz)
  const far = Math.sqrt(3) * B * cell * 0.5 * reach + cell
  for (let c = 0; c < bz; c++) for (let b = 0; b < by; b++) for (let a = 0; a < bx; a++) {
    const f = field(x0 + (a * B + B / 2) * cell, y0 + (b * B + B / 2) * cell, z0 + (c * B + B / 2) * cell)
    if (Math.abs(f) < far) { near[a + bx * (b + by * c)] = 1; continue }
    const i1 = Math.min(a * B + B, nx - 1), j1 = Math.min(b * B + B, ny - 1), k1 = Math.min(c * B + B, nz - 1)
    for (let k = c * B; k <= k1; k++) for (let j = b * B; j <= j1; j++) for (let i = a * B; i <= i1; i++) {
      vals[at(i, j, k)] = f
    }
  }
  const done = new Uint8Array(nx * ny * nz)
  for (let c = 0; c < bz; c++) for (let b = 0; b < by; b++) for (let a = 0; a < bx; a++) {
    if (!near[a + bx * (b + by * c)]) continue
    const i1 = Math.min(a * B + B, nx - 1), j1 = Math.min(b * B + B, ny - 1), k1 = Math.min(c * B + B, nz - 1)
    for (let k = c * B; k <= k1; k++) for (let j = b * B; j <= j1; j++) for (let i = a * B; i <= i1; i++) {
      const id = at(i, j, k)
      if (done[id]) continue
      done[id] = 1
      vals[id] = field(x0 + i * cell, y0 + j * cell, z0 + k * cell)
    }
  }

  // One vertex per cell the surface crosses, at the mean of the crossings on its edges.
  const cx = nx - 1, cy = ny - 1, cz = nz - 1
  const cellVertex = new Int32Array(cx * cy * cz).fill(-1)
  const cellAt = (i, j, k) => i + cx * (j + cy * k)
  const pos = []
  const corner = new Float64Array(8)
  const EDGES = [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
  for (let c = 0; c < bz; c++) for (let b = 0; b < by; b++) for (let a = 0; a < bx; a++) {
    if (!near[a + bx * (b + by * c)]) continue
    const i1 = Math.min(a * B + B, cx), j1 = Math.min(b * B + B, cy), k1 = Math.min(c * B + B, cz)
    for (let k = c * B; k < k1; k++) for (let j = b * B; j < j1; j++) for (let i = a * B; i < i1; i++) {
      let mask = 0
      for (let n = 0; n < 8; n++) {
        const v = vals[at(i + (n & 1), j + ((n >> 1) & 1), k + ((n >> 2) & 1))]
        corner[n] = v
        if (v < 0) mask |= 1 << n
      }
      if (mask === 0 || mask === 255) continue
      let sx = 0, sy = 0, sz = 0, count = 0
      for (const [p, q] of EDGES) {
        const vp = corner[p], vq = corner[q]
        if ((vp < 0) === (vq < 0)) continue
        const t = vp / (vp - vq)
        sx += (p & 1) + t * ((q & 1) - (p & 1))
        sy += ((p >> 1) & 1) + t * (((q >> 1) & 1) - ((p >> 1) & 1))
        sz += ((p >> 2) & 1) + t * (((q >> 2) & 1) - ((p >> 2) & 1))
        count++
      }
      cellVertex[cellAt(i, j, k)] = pos.length / 3
      pos.push(x0 + (i + sx / count) * cell, y0 + (j + sy / count) * cell, z0 + (k + sz / count) * cell)
    }
  }

  // A quad around every grid edge the surface crosses.
  const idx = []
  let holes = 0
  const quad = (a, b, c, d, flip) => {
    if (a < 0 || b < 0 || c < 0 || d < 0) { holes++; return }
    // Split along the shorter diagonal.
    const d1 = dist2(pos, a, c), d2 = dist2(pos, b, d)
    if (d1 <= d2) {
      if (flip) idx.push(a, c, b, a, d, c); else idx.push(a, b, c, a, c, d)
    } else {
      if (flip) idx.push(b, a, d, b, d, c); else idx.push(a, b, d, b, c, d)
    }
  }
  for (let k = 0; k < cz; k++) for (let j = 0; j < cy; j++) for (let i = 0; i < cx; i++) {
    if (cellVertex[cellAt(i, j, k)] < 0) continue
    const v0 = vals[at(i, j, k)]
    if (j > 0 && k > 0) {
      const v1 = vals[at(i + 1, j, k)]
      if ((v0 < 0) !== (v1 < 0)) {
        quad(cellVertex[cellAt(i, j - 1, k - 1)], cellVertex[cellAt(i, j, k - 1)],
          cellVertex[cellAt(i, j, k)], cellVertex[cellAt(i, j - 1, k)], !(v0 < 0))
      }
    }
    if (i > 0 && k > 0) {
      const v1 = vals[at(i, j + 1, k)]
      if ((v0 < 0) !== (v1 < 0)) {
        quad(cellVertex[cellAt(i - 1, j, k - 1)], cellVertex[cellAt(i - 1, j, k)],
          cellVertex[cellAt(i, j, k)], cellVertex[cellAt(i, j, k - 1)], !(v0 < 0))
      }
    }
    if (i > 0 && j > 0) {
      const v1 = vals[at(i, j, k + 1)]
      if ((v0 < 0) !== (v1 < 0)) {
        quad(cellVertex[cellAt(i - 1, j - 1, k)], cellVertex[cellAt(i, j - 1, k)],
          cellVertex[cellAt(i, j, k)], cellVertex[cellAt(i - 1, j, k)], !(v0 < 0))
      }
    }
  }

  // Pull each vertex onto the surface, and take its normal from the field.
  const positions = new Float32Array(pos)
  const normals = new Float32Array(pos.length)
  const g = [0, 0, 0, 0]
  const h = Math.min(0.02, cell * 0.2)
  for (let v = 0; v < positions.length; v += 3) {
    let x = positions[v], y = positions[v + 1], z = positions[v + 2]
    const xs = x, ys = y, zs = z
    for (let pass = 0; pass < 3; pass++) {
      gradient(field, x, y, z, h, g)
      const len2 = g[0] * g[0] + g[1] * g[1] + g[2] * g[2]
      if (len2 < 1e-12) break
      const step = g[3] / len2
      x -= g[0] * step; y -= g[1] * step; z -= g[2] * step
    }
    // A vertex may not leave its neighbourhood: at a crease the pull is unreliable.
    if (Math.hypot(x - xs, y - ys, z - zs) > cell * 1.5) { x = xs; y = ys; z = zs }
    gradient(field, x, y, z, h, g)
    const len = Math.hypot(g[0], g[1], g[2]) || 1
    positions[v] = x; positions[v + 1] = y; positions[v + 2] = z
    normals[v] = g[0] / len; normals[v + 1] = g[1] / len; normals[v + 2] = g[2] / len
  }
  return { positions, normals, indices: new Uint32Array(idx), holes }
}

function dist2(p, a, b) {
  const dx = p[a * 3] - p[b * 3], dy = p[a * 3 + 1] - p[b * 3 + 1], dz = p[a * 3 + 2] - p[b * 3 + 2]
  return dx * dx + dy * dy + dz * dz
}

/// Gradient and value from four samples on a tetrahedron: out = [gx, gy, gz, value].
function gradient(field, x, y, z, h, out) {
  const a = field(x + h, y - h, z - h)
  const b = field(x - h, y - h, z + h)
  const c = field(x - h, y + h, z - h)
  const d = field(x + h, y + h, z + h)
  out[0] = (a - b - c + d) / (4 * h)
  out[1] = (-a - b + c + d) / (4 * h)
  out[2] = (-a + b - c + d) / (4 * h)
  out[3] = (a + b + c + d) / 4
}

