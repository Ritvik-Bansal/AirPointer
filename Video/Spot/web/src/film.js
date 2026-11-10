// Puts the storyboard on the stage: for any moment, where everything is and how it is lit.
//
// DIRECTION CONTRACT
//
// THESIS: One unbroken take in a dark studio. A white case hangs in front of a Mac; the
// camera never cuts, it travels: in on the case, over it to the screen, once round it,
// into the app and back out. It refuses the screen recording with captions.
// OWN-WORLD: Black, with three lights that have colour: the app's keyline blue from one
// side, amber from the other, the screen's own glow between them. One white glossy object.
// Real depth of field, real motion blur. Type in the app's own rounded face, bottom left,
// one line at a time. The app's window on the screen is the app's own design, redrawn.
// STORY: That is my AirPods case. It is a pointer: I aim it and the cursor goes; I tap it
// and the Mac clicks; I can tune how it feels. It is called AirPointer.
// FIRST VIEWPORT: the closed case, lit, alone against the dark, with the Mac only a shape
// behind it. It is the frame a player shows before anyone presses play.
// FORM: a thirty-second product spot in five shots (the brief: an ultra-premium tech
// commercial, cinematic tones, vivid light, depth of field, continuous transitions).
// The earlier film in this project is flat by rule, at the user's word: no gradients. This
// one was asked for as its opposite, and light and focus are tonal by nature, so here the
// rule is kept where it still can be: nothing is filled, tinted or titled with a gradient;
// every change of tone in the frame is light falling on a surface, or focus.
// No concept roll was run and there is no seed to record: the brief fixed the form (five
// shots, one continuous film, Three.js), and the look follows from the app's own palette.
// FINISH: unreviewed and undocumented is unfinished; this build ends with the finish
// review, the verdict, and its section in DESIGN.md.

import * as THREE from 'three'
import * as T from './timeline.js'
import { CASE, SCREEN, UI } from './layout.js'
import { DIM } from './model/airpods.js'
import { buildCase, TAP_LIFE } from './model/case.js'
import { buildSet } from './set.js'
import { makeScreen } from './screen.js'
import { makeTitles } from './titles.js'
import { KEY_BLUE } from './studio.js'

export async function buildFilm({ film, scene, studio, model, holder, camera, width, height, address }) {
  const renderer = film.renderer

  // The Mac's screen is a canvas, redrawn every frame.
  const ui = makeScreen()
  const screenTexture = new THREE.CanvasTexture(ui.canvas)
  screenTexture.colorSpace = THREE.SRGBColorSpace
  screenTexture.anisotropy = renderer.capabilities.getMaxAnisotropy()
  screenTexture.generateMipmaps = true
  screenTexture.minFilter = THREE.LinearMipmapLinearFilter
  const set = buildSet(scene, screenTexture, studio.environment)
  const titles = makeTitles(width, height, address)

  // The little case in the app's window: the same model, lit plainly, seen from the front.
  const little = await buildCase({ level: 1 })
  const littleScene = new THREE.Scene()
  littleScene.environment = studio.environment
  littleScene.environmentIntensity = 0.5
  const littleHolder = new THREE.Group()
  littleHolder.scale.setScalar(0.001)
  littleHolder.add(little.root)
  littleScene.add(littleHolder)
  const sun = new THREE.DirectionalLight(0xffffff, 2.3)
  sun.position.set(-0.4, 1, 0.9)
  littleScene.add(sun, new THREE.HemisphereLight(0xdfeaf5, 0x39424d, 1.1))
  const littleCamera = new THREE.PerspectiveCamera(20, 300 / 231, 0.05, 5)
  littleCamera.position.set(0, 0.105, 0.33)
  littleCamera.lookAt(0, 0.009, 0)
  const LW = Math.round(300 * UI.scale), LH = Math.round(231 * UI.scale)
  const littleTarget = new THREE.WebGLRenderTarget(LW, LH, { samples: 4 })
  littleTarget.texture.colorSpace = THREE.SRGBColorSpace
  const pixels = new Uint8Array(LW * LH * 4)
  const littleCanvas = document.createElement('canvas')
  littleCanvas.width = LW
  littleCanvas.height = LH
  const littleCtx = littleCanvas.getContext('2d')
  const littleImage = littleCtx.createImageData(LW, LH)

  function drawLittle(t) {
    const pose = T.casePose(t)
    little.setLid(T.lid(t))
    little.setLight(new THREE.Color(0x7dffa0).multiplyScalar(1.4 * T.caseLight(t)))
    littleHolder.rotation.set(pose.pitch * Math.PI / 180, pose.yaw * Math.PI / 180, pose.roll * Math.PI / 180, 'YXZ')
    renderer.setRenderTarget(littleTarget)
    renderer.setClearColor(0x000000, 0)
    renderer.clear()
    renderer.render(littleScene, littleCamera)
    renderer.readRenderTargetPixels(littleTarget, 0, 0, LW, LH, pixels)
    renderer.setRenderTarget(null)
    // Rows come back bottom first.
    const out = littleImage.data
    for (let y = 0; y < LH; y++) out.set(pixels.subarray((LH - 1 - y) * LW * 4, (LH - y) * LW * 4), y * LW * 4)
    littleCtx.putImageData(littleImage, 0, 0)
    return littleCanvas
  }

  const green = new THREE.Color(0x7dffa0)
  const lightColor = new THREE.Color()
  const keyOffset = new THREE.Vector3(-0.3, 0.74, 0.82)
  const tapsNow = []
  model.setTapPoint(T.TAP_AT.x, T.TAP_AT.y, -DIM.D)
  let turnOverride = null

  /// Everything that moves, at time t.
  function pose(t) {
    const p = T.casePose(t)
    holder.position.set(p.x, p.y, p.z)
    holder.rotation.set(p.pitch * Math.PI / 180, p.yaw * Math.PI / 180, p.roll * Math.PI / 180, 'YXZ')
    model.setLid(T.lid(t))
    model.setLight(lightColor.copy(green).multiplyScalar(1.5 * T.caseLight(t)))
    tapsNow.length = 0
    for (const tap of T.TAPS) {
      const age = t - tap
      if (age >= 0 && age < TAP_LIFE) tapsNow.push({ age, strength: 4.5 })
    }
    model.setTaps(tapsNow.slice(-3))

    const c = T.camera(t)
    camera.position.set(c.at[0], c.at[1], c.at[2])
    camera.up.set(0, 1, 0)
    camera.lookAt(c.look[0], c.look[1], c.look[2])
    camera.fov = c.fov
    scene.environmentRotation.y = (turnOverride ?? T.lightTurn(t)) * Math.PI / 180
    set.setScreen(T.screenLevel(t))
  }

  // How far, in pixels, the picture slides while the shutter is open: the larger of how far
  // the case and the middle of the Mac's screen move across the frame.
  const probe = new THREE.PerspectiveCamera(30, width / height, 0.01, 40)
  const spot = new THREE.Vector3()
  const marks = [CASE, SCREEN.centre]
  function place(t) {
    const c = T.camera(t)
    probe.position.set(c.at[0], c.at[1], c.at[2])
    probe.lookAt(c.look[0], c.look[1], c.look[2])
    probe.fov = c.fov
    probe.updateProjectionMatrix()
    probe.updateMatrixWorld(true)
    return marks.map(m => { spot.set(m[0], m[1], m[2]).project(probe); return [spot.x * width / 2, spot.y * height / 2] })
  }
  function slide(t, shutter) {
    const a = place(t - shutter / 2), b = place(t + shutter / 2)
    return Math.max(...a.map((p, i) => Math.hypot(b[i][0] - p[0], b[i][1] - p[1])))
  }

  /// Draws frame `index` to the canvas.
  function frame(index, { samples, turn = null } = {}) {
    const t = (index + 0.5) / T.FPS
    turnOverride = turn
    // A fast move needs more renders in the average: with too few, a fine bright line that
    // is both out of focus and moving comes out as a row of separate copies, not a smear.
    const shutter = 0.5 / T.FPS
    const base = samples || 96
    const count = Math.round(base * Math.min(2, Math.max(1, slide(t, shutter) * (1920 / width) / 60)))
    ui.draw(t, drawLittle(t))
    screenTexture.needsUpdate = true
    const overlay = titles.draw(t)
    const c = T.camera(t)
    studio.keyHome.set(CASE[0], CASE[1], CASE[2]).add(keyOffset)
    studio.key.target.position.set(CASE[0], CASE[1], CASE[2])
    studio.kicker.target.position.set(CASE[0], CASE[1], CASE[2])
    film.frame(scene, camera, pose, {
      time: t, shutter, samples: count, aperture: c.lens, focus: c.focus,
      key: studio.key, keyHome: studio.keyHome, keySize: studio.keySize,
    }, { overlay, seed: index })
  }

  return { frame, pose, set, ui, titles }
}
