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

