// Starts the page and hands the harness something to call.
//
//   SPOT.ready            resolves once everything is loaded
//   SPOT.frame(i, opts)   draws frame i of the film
//   SPOT.still(view)      draws the model alone from a given camera (for checking it)
//   SPOT.png()            the canvas as a PNG data URL

import * as THREE from 'three'
import { FilmRenderer } from './renderer.js'
import { buildStudio } from './studio.js'
import { buildCase } from './model/case.js'
import { buildFilm } from './film.js'
import { FPS, FRAMES } from './timeline.js'
import { renderSound } from './sound.js'

const query = new URLSearchParams(location.search)
const scale = Number(query.get('scale') || 1)
const WIDTH = Math.round(1920 * scale), HEIGHT = Math.round(1080 * scale)
const canvas = document.getElementById('film')

async function start() {
  // The display and text faces the app itself uses.
  const faces = [
    new FontFace('SF Rounded', 'url(/fonts/SFNSRounded.ttf)', { weight: '100 900' }),
    new FontFace('SF Text', 'url(/fonts/SFNS.ttf)', { weight: '100 900' }),
  ]
  for (const face of faces) { document.fonts.add(await face.load()) }

  const film = new FilmRenderer(canvas, WIDTH, HEIGHT)
  const scene = new THREE.Scene()
  scene.userData.ground = 0x020305
  const studio = buildStudio(film.renderer, scene)
  const model = await buildCase({ level: 0 })
  const holder = new THREE.Group()
  holder.scale.setScalar(0.001)
  holder.add(model.root)
  scene.add(holder)
  const camera = new THREE.PerspectiveCamera(30, WIDTH / HEIGHT, 0.01, 40)

  const api = { film, scene, studio, model, holder, camera, THREE, fps: FPS, frames: FRAMES }
  const address = query.get('address') ?? 'github.com/Ritvik-Bansal/AirPointer'
  const movie = await buildFilm({ film, scene, studio, model, holder, camera, width: WIDTH, height: HEIGHT, address })
  api.frame = movie.frame
  api.sound = () => renderSound()
  api.movie = movie

  api.still = view => {
    const v = { lid: 0, yaw: 0, pitch: 0, roll: 0, fov: 22, samples: 32, aperture: 0, exposure: 1, light: 0, env: 0, ...view }
    model.setLid(v.lid)
    model.setLight(new THREE.Color(0xffffff).multiplyScalar(v.light))
    holder.rotation.set(v.pitch * Math.PI / 180, v.yaw * Math.PI / 180, v.roll * Math.PI / 180, 'YXZ')
    scene.environmentRotation.y = v.env * Math.PI / 180
    camera.fov = v.fov
    camera.position.set(...v.from)
    camera.up.set(0, 1, 0)
    camera.lookAt(...v.at)
    studio.key.target.position.set(0, 0, 0)
    studio.key.intensity = v.key ?? 4.6
    studio.key.castShadow = v.shadows ?? true
    scene.environmentIntensity = v.envPower ?? 1
    const focus = v.focus ?? camera.position.distanceTo(new THREE.Vector3(...v.at))
    const t0 = performance.now()
    film.frame(scene, camera, () => {}, {
      time: 0, shutter: 0, samples: v.samples, aperture: v.aperture, focus,
      key: studio.key, keyHome: studio.keyHome, keySize: studio.keySize,
    }, { exposure: v.exposure, grain: v.grain ?? 0 })
    return performance.now() - t0
  }
  api.png = () => canvas.toDataURL('image/png')
  return api
}

window.SPOT = { ready: start().then(api => { Object.assign(window.SPOT, api); return true }) }
