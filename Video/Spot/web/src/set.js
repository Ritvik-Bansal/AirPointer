// The set: a dark desk and an open laptop whose screen is a live canvas.
//
// The laptop is a plain aluminium notebook, not a model of any particular one: a slab with
// a keyboard and trackpad, and a lid with a glass face. It is here to carry the screen.

import * as THREE from 'three'
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js'
import { LAPTOP, SCREEN } from './layout.js'

/// A flat rounded rectangle in the XY plane, with texture coordinates across its bounds.
function roundedPlane(width, height, radius, segments = 10) {
  const shape = roundedShape(width, height, radius)
  const geometry = new THREE.ShapeGeometry(shape, segments)
  const position = geometry.attributes.position
  const uv = new Float32Array(position.count * 2)
  for (let i = 0; i < position.count; i++) {
    uv[i * 2] = position.getX(i) / width + 0.5
    uv[i * 2 + 1] = position.getY(i) / height + 0.5
  }
  geometry.setAttribute('uv', new THREE.BufferAttribute(uv, 2))
  return geometry
}

function roundedShape(width, height, radius) {
  const w = width / 2, h = height / 2, r = Math.min(radius, w, h)
  const shape = new THREE.Shape()
  shape.moveTo(-w + r, -h)
  shape.lineTo(w - r, -h)
  shape.absarc(w - r, -h + r, r, -Math.PI / 2, 0)
  shape.lineTo(w, h - r)
  shape.absarc(w - r, h - r, r, 0, Math.PI / 2)
  shape.lineTo(-w + r, h)
  shape.absarc(-w + r, h - r, r, Math.PI / 2, Math.PI)
  shape.lineTo(-w, -h + r)
  shape.absarc(-w + r, -h + r, r, Math.PI, Math.PI * 1.5)
  return shape
}

/// A slab with a rounded outline and softened edges, lying flat: width along x, depth along
/// z, its underside at y = 0.
function slab(width, depth, thickness, corner, edge) {
  const geometry = new THREE.ExtrudeGeometry(roundedShape(width - edge * 2, depth - edge * 2, corner - edge), {
    depth: thickness - edge * 2, bevelEnabled: true, bevelThickness: edge, bevelSize: edge, bevelSegments: 4, curveSegments: 16,
  })
  geometry.rotateX(-Math.PI / 2)
  geometry.translate(0, edge, 0)
  return geometry
}

