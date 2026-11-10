// The lighting: a black studio with three soft lights, and one hard-edged key.
//
// The soft lights are panels in an environment that every surface reflects: a large white
// one overhead, a tall blue one behind on the right and a smaller warm one behind on the
// left. They are what draws the long highlights on the case. The blue is the app's own
// keyline colour; the warm one is its opposite, there so that white plastic has two edges.
//
// The key is a spot that casts shadows. The renderer moves it about its own width between
// samples, so its shadows come out soft-edged like a real lamp's.

import * as THREE from 'three'
import { RectAreaLightUniformsLib } from 'three/addons/lights/RectAreaLightUniformsLib.js'

export const KEY_BLUE = 0x48b9f5

export function buildStudio(renderer, scene) {
  RectAreaLightUniformsLib.init()

  const room = new THREE.Scene()
  const panel = (width, height, color, power, at) => {
    const material = new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(power), side: THREE.DoubleSide })
    const mesh = new THREE.Mesh(new THREE.PlaneGeometry(width, height), material)
    mesh.position.set(...at)
    mesh.lookAt(0, 0, 0)
    room.add(mesh)
    return mesh
  }
  const panels = {
    top: panel(2.6, 1.5, 0xffffff, 1.5, [0.2, 2.4, 0.5]),
    // The two colours are narrow strips: bright enough to draw a clean edge on the plastic,
    // too small to flood it. Blue is on the side the camera mostly looks toward, so it is
    // what lies behind the subject; amber is the smaller of the two and stays an accent.
    blue: panel(0.15, 2.2, 0x2f9cff, 26, [2.3, 0.7, -1.5]),
    warm: panel(0.1, 2.0, 0xff7a2e, 9, [-2.4, 0.6, -1.3]),
    fill: panel(3.6, 2.2, 0xdfe8ff, 0.55, [0.5, 0.9, 3.0]),
    back: panel(2.2, 0.9, 0xe6efff, 3.2, [0.1, 1.5, -2.4]),
    // A tall, narrow, bright panel in front, opposite the camera's side: it is what the
    // flat face of the case mirrors, as a hard-edged band of light that slides across it.
    band: panel(0.2, 1.8, 0xffffff, 15, [1.15, 0.3, 2.4]),
    // The same again, low: the end card looks down on the case, and from up there its face
    // mirrors what is below and in front.
    low: panel(0.13, 1.2, 0xffffff, 7, [1.3, -1.15, 1.9]),
  }
  // The room itself is not quite black, so that metal has something to reflect.
  const walls = new THREE.Mesh(
    new THREE.SphereGeometry(12, 32, 16),
    new THREE.MeshBasicMaterial({ color: new THREE.Color(0x8fa6c8).multiplyScalar(0.035), side: THREE.BackSide })
  )
  room.add(walls)
  const pmrem = new THREE.PMREMGenerator(renderer)
  const environment = pmrem.fromScene(room, 0, 0.1, 30, { size: 512 }).texture
  scene.environment = environment
  scene.environmentIntensity = 1

  // The key: a narrow spot on the case, so its shadow map is fine enough for close-ups.
  const key = new THREE.SpotLight(0xffffff, 2.7, 0, 0.14, 0.7, 2)
  const keyHome = new THREE.Vector3(-0.3, 0.8, 0.9)
  key.position.copy(keyHome)
  key.castShadow = true
  key.shadow.mapSize.set(3072, 3072)
  key.shadow.camera.near = 0.5
  key.shadow.camera.far = 2.4
  key.shadow.bias = -0.00006
  key.shadow.normalBias = 0.00025
  key.shadow.radius = 1.2
  scene.add(key)
  scene.add(key.target)

  // A kicker from behind and above, so the far side of the case is white and not only tinted.
  const kicker = new THREE.SpotLight(0xe9f1ff, 5.0, 0, 0.1, 0.9, 2)
  kicker.position.set(-0.18, 0.62, -0.72)
  scene.add(kicker)
  scene.add(kicker.target)

  return { key, keyHome, keySize: 0.11, kicker, environment, panels }
}
