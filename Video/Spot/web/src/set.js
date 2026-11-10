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

export function buildSet(scene, screenTexture, environment) {
  const set = new THREE.Group()
  scene.add(set)
  // The desk runs off into darkness rather than to a hard horizon.
  scene.fog = new THREE.Fog(scene.userData.ground ?? 0x000000, 1.3, 4.2)

  // The desk: dark, a little glossy, so the screen and the lights pool on it.
  const desk = new THREE.Mesh(
    new THREE.PlaneGeometry(8, 8),
    // (A material only has its own say over the environment when the map is set on it,
    // rather than taken from the scene. The desk takes none: it is lit by lamps alone.)
    new THREE.MeshPhysicalMaterial({ color: 0x23272e, roughness: 0.4, metalness: 0, envMap: environment, envMapIntensity: 0 })
  )
  desk.rotation.x = -Math.PI / 2
  desk.receiveShadow = true
  set.add(desk)

  const aluminium = new THREE.MeshPhysicalMaterial({ color: 0x2a2d33, roughness: 0.46, metalness: 1 })
  const laptop = new THREE.Group()
  laptop.position.set(LAPTOP.centre[0], 0.0012, LAPTOP.centre[2])
  set.add(laptop)

  const base = new THREE.Mesh(slab(LAPTOP.width, LAPTOP.depth, LAPTOP.base, 0.012, 0.0022), aluminium)
  base.receiveShadow = true
  laptop.add(base)

  // The keyboard: a shallow black well and its keys.
  const top = LAPTOP.base
  const unit = 0.01862, gap = 0.0021
  const rows = [
    { depth: 0.55, keys: new Array(14).fill(14.5 / 14) },
    { depth: 1, keys: [...new Array(13).fill(1), 1.5] },
    { depth: 1, keys: [1.5, ...new Array(13).fill(1)] },
    { depth: 1, keys: [1.75, ...new Array(11).fill(1), 1.75] },
    { depth: 1, keys: [2.25, ...new Array(10).fill(1), 2.25] },
    { depth: 1, keys: [1, 1, 1, 1.25, 5, 1.25, 1, 1, 1, 1] },
  ]
  const boardWidth = 14.5 * unit, boardDepth = rows.reduce((sum, r) => sum + r.depth, 0) * unit
  const boardBack = -LAPTOP.depth / 2 + 0.0135
  const well = new THREE.Mesh(
    roundedPlane(boardWidth + 0.004, boardDepth + 0.004, 0.004),
    new THREE.MeshStandardMaterial({ color: 0x050506, roughness: 0.75 })
  )
  well.rotation.x = -Math.PI / 2
  well.position.set(0, top + 0.00005, boardBack + boardDepth / 2)
  laptop.add(well)

  const keyCount = rows.reduce((sum, r) => sum + r.keys.length, 0)
  const cap = new RoundedBoxGeometry(1, 1, 1, 3, 0.09)
  const keys = new THREE.InstancedMesh(cap, new THREE.MeshPhysicalMaterial({ color: 0x0b0b0d, roughness: 0.5, metalness: 0, clearcoat: 0.15, clearcoatRoughness: 0.5 }), keyCount)
  const place = new THREE.Matrix4()
  let n = 0, z = boardBack
  for (const row of rows) {
    let x = -boardWidth / 2
    for (const k of row.keys) {
      const w = k * unit - gap, d = row.depth * unit - gap
      place.makeScale(w, 0.0016, d)
      place.setPosition(x + k * unit / 2, top + 0.0009, z + row.depth * unit / 2)
      keys.setMatrixAt(n++, place)
      x += k * unit
    }
    z += row.depth * unit
  }
  keys.instanceMatrix.needsUpdate = true
  laptop.add(keys)

  // The trackpad: a pane of glass set flush, told apart by its finish and a hairline.
  const padWidth = 0.128, padDepth = 0.079
  const padZ = LAPTOP.depth / 2 - 0.0085 - padDepth / 2
  const padLine = new THREE.Mesh(roundedPlane(padWidth + 0.0007, padDepth + 0.0007, 0.0042), new THREE.MeshStandardMaterial({ color: 0x08090a, roughness: 0.8 }))
  padLine.rotation.x = -Math.PI / 2
  padLine.position.set(0, top + 0.00004, padZ)
  laptop.add(padLine)
  const pad = new THREE.Mesh(roundedPlane(padWidth, padDepth, 0.004), new THREE.MeshPhysicalMaterial({ color: 0x25282d, roughness: 0.52, metalness: 1 }))
  pad.rotation.x = -Math.PI / 2
  pad.position.set(0, top + 0.00008, padZ)
  laptop.add(pad)

  // The lid turns about the hinge line at the back of the base.
  const hinge = new THREE.Group()
  hinge.position.set(0, SCREEN.hinge[1] - 0.0012, -LAPTOP.depth / 2 + 0.0045)
  hinge.rotation.x = -SCREEN.tilt
  laptop.add(hinge)
  const barrel = new THREE.Mesh(new THREE.CylinderGeometry(0.0042, 0.0042, LAPTOP.width * 0.82, 24), new THREE.MeshStandardMaterial({ color: 0x0c0d0f, roughness: 0.6, metalness: 0.4 }))
  barrel.rotation.z = Math.PI / 2
  hinge.add(barrel)

  // Standing up from the hinge: the lid's shell, its glass face, and the lit screen on it.
  const shell = new THREE.Mesh(slab(LAPTOP.width, LAPTOP.depth, LAPTOP.lidThick, 0.012, 0.0014), aluminium)
  shell.rotation.x = Math.PI / 2 // the slab's depth now runs up the lid
  shell.position.set(0, LAPTOP.depth / 2, -LAPTOP.lidThick)
  hinge.add(shell)
  const glass = new THREE.Mesh(
    roundedPlane(LAPTOP.width - 0.002, LAPTOP.depth - 0.002, 0.011),
    new THREE.MeshPhysicalMaterial({ color: 0x020203, roughness: 0.12, metalness: 0, clearcoat: 1, clearcoatRoughness: 0.05, envMap: environment, envMapIntensity: 0.06 })
  )
  glass.position.set(0, LAPTOP.depth / 2, 0.0004)
  hinge.add(glass)

  const display = new THREE.MeshPhysicalMaterial({
    color: 0x000000, emissive: 0xffffff, emissiveMap: screenTexture, emissiveIntensity: 0,
    // The lit area mirrors almost nothing: a studio panel reflected across it veils the app.
    roughness: 0.16, metalness: 0, clearcoat: 1, clearcoatRoughness: 0.06, envMap: environment, envMapIntensity: 0.02,
  })
  const screen = new THREE.Mesh(roundedPlane(SCREEN.width, SCREEN.height, 0.0042, 12), display)
  const reach = LAPTOP.depth - LAPTOP.bezel - LAPTOP.screenHeight / 2 - 0.0005
  screen.position.set(0, reach, 0.0012)
  hinge.add(screen)

  // The screen also lights what is in front of it.
  const glow = new THREE.RectAreaLight(0x6f9eea, 0, SCREEN.width, SCREEN.height)
  glow.position.set(0, reach, 0.004)
  glow.rotation.y = Math.PI // a panel light shines along its own -z
  hinge.add(glow)

  // Two tall coloured panels, far off to either side behind the Mac: blue on the right,
  // a fainter amber on the left. The desk has no reflections of its own, so these are what
  // lay colour across it.
  const streak = (color, power, x, z) => {
    const light = new THREE.RectAreaLight(color, power, 0.13, 1.6)
    light.position.set(x, 0.72, z)
    light.lookAt(0, 0.05, -0.1)
    set.add(light)
    return light
  }
  const streaks = [streak(0x2f9cff, 3.4, 1.85, -1.25), streak(0xff7a2e, 1.0, -1.75, -1.1)]

  return {
    desk, laptop, screen, streaks,
    /// Screen brightness, 0 to 1.
    setScreen(level) {
      display.emissiveIntensity = 1.05 * level
      glow.intensity = 2.6 * level
    },
  }
}
