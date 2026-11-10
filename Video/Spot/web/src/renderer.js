// Draws one frame of the film the slow, correct way.
//
// A frame is the average of many renders. Between them three things are nudged:
//   - the camera, across the opening of its lens, which gives true depth of field (anything
//     off the plane of focus lands in a different place each time and blurs into a disc);
//   - the clock, across the time the shutter is open, which gives motion blur;
//   - the key light, across its own width, which gives soft-edged shadows.
// Sub-pixel jitter rides along, so edges are anti-aliased by the same averaging.
//
// The average is kept in linear light and then finished: bloom on what is brighter than
// white, a tone curve, the grade, grain, and the titles laid over the top.

import * as THREE from 'three'
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js'
import { FullScreenQuad } from 'three/addons/postprocessing/Pass.js'

const GOLDEN = Math.PI * (3 - Math.sqrt(5))

export class FilmRenderer {
  constructor(canvas, width, height) {
    this.width = width
    this.height = height
    const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, preserveDrawingBuffer: true, powerPreference: 'high-performance' })
    renderer.setPixelRatio(1)
    renderer.setSize(width, height, false)
    renderer.toneMapping = THREE.NoToneMapping
    renderer.shadowMap.enabled = true
    renderer.shadowMap.type = THREE.PCFShadowMap
    renderer.autoClear = true
    this.renderer = renderer

    const gl = renderer.getContext()
    const canBlendFloat = !!gl.getExtension('EXT_float_blend')
    this.one = new THREE.WebGLRenderTarget(width, height, { type: THREE.HalfFloatType, depthBuffer: true })
    this.sum = new THREE.WebGLRenderTarget(width, height, { type: canBlendFloat ? THREE.FloatType : THREE.HalfFloatType, depthBuffer: false })
    this.mean = new THREE.WebGLRenderTarget(width, height, { type: THREE.HalfFloatType, depthBuffer: false })

    this.add = new FullScreenQuad(new THREE.ShaderMaterial({
      uniforms: { tMap: { value: null }, uWeight: { value: 1 } },
      vertexShader: 'varying vec2 vUv; void main() { vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }',
      fragmentShader: 'uniform sampler2D tMap; uniform float uWeight; varying vec2 vUv; void main() { gl_FragColor = vec4(min(texture2D(tMap, vUv).rgb, vec3(64.0)) * uWeight, 1.0); }',
      blending: THREE.CustomBlending, blendEquation: THREE.AddEquation, blendSrc: THREE.OneFactor, blendDst: THREE.OneFactor,
      depthTest: false, depthWrite: false,
    }))
    this.copy = new FullScreenQuad(new THREE.ShaderMaterial({
      uniforms: { tMap: { value: null } },
      vertexShader: 'varying vec2 vUv; void main() { vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }',
      fragmentShader: 'uniform sampler2D tMap; varying vec2 vUv; void main() { gl_FragColor = vec4(texture2D(tMap, vUv).rgb, 1.0); }',
      depthTest: false, depthWrite: false,
    }))
    this.bloom = new UnrealBloomPass(new THREE.Vector2(width, height), 0.08, 0.4, 1.2)

    this.overlay = new THREE.Texture()
    this.overlay.colorSpace = THREE.NoColorSpace
    this.overlay.minFilter = THREE.LinearFilter
    this.overlay.generateMipmaps = false
    this.overlay.premultiplyAlpha = true
    this.finish = new FullScreenQuad(new THREE.ShaderMaterial({
      uniforms: {
        tMap: { value: null }, tOver: { value: this.overlay }, uHasOver: { value: 0 },
        uExposure: { value: 1 }, uFade: { value: 1 }, uSeed: { value: 0 }, uGrain: { value: 0.018 },
        uContrast: { value: 1.08 }, uSaturation: { value: 1.06 }, uVignette: { value: 0.16 },
        uSize: { value: new THREE.Vector2(width, height) },
      },
      vertexShader: 'varying vec2 vUv; void main() { vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }',
      fragmentShader: FINISH,
      depthTest: false, depthWrite: false,
    }))

    this.patterns = new Map()
    this.base = new THREE.Matrix4()
    this.right = new THREE.Vector3()
    this.up = new THREE.Vector3()
    this.home = new THREE.Vector3()
  }

  /// Renders one frame to the canvas.
  ///  - pose(time): puts the scene and the camera where they are at `time`.
  ///  - shot: { time, shutter, samples, aperture, focus, key, keyHome, keySize }
  ///  - look: uniforms of the finishing pass to set (exposure, fade, ...)
  frame(scene, camera, pose, shot, look = {}) {
    const { renderer } = this
    const samples = Math.max(1, shot.samples | 0)
    const { lens, order, lamp } = this.pattern(samples)
    renderer.setRenderTarget(this.sum)
    renderer.setClearColor(0x000000, 1)
    renderer.clear()

    for (let i = 0; i < samples; i++) {
      // Time runs evenly across the shutter. Which point of the lens goes with which moment
      // is a fixed shuffle: paired in any regular order, something that is both moving and
      // out of focus comes out as a row of separate copies instead of a smear.
      const when = shot.time + shot.shutter * ((i + 0.5) / samples - 0.5)
      pose(when)
      camera.updateMatrixWorld(true)

      const point = lens[order[i]]
      this.home.copy(camera.position)
      this.right.setFromMatrixColumn(camera.matrixWorld, 0)
      this.up.setFromMatrixColumn(camera.matrixWorld, 1)
      const ox = point[0] * shot.aperture, oy = point[1] * shot.aperture
      camera.position.addScaledVector(this.right, ox).addScaledVector(this.up, oy)
      camera.updateMatrixWorld(true)
      // Shear the view so that the plane of focus does not move as the lens position does,
      // and slide it by a fraction of a pixel for anti-aliasing.
      camera.updateProjectionMatrix()
      const p = camera.projectionMatrix.elements
      const jx = samples > 1 ? halton(i + 1, 2) - 0.5 : 0, jy = samples > 1 ? halton(i + 1, 3) - 0.5 : 0
      p[8] += -ox * p[0] / shot.focus + jx * 2 / this.width
      p[9] += -oy * p[5] / shot.focus + jy * 2 / this.height
      camera.projectionMatrixInverse.copy(camera.projectionMatrix).invert()

      if (shot.key) {
        const k = lens[lamp[i]]
        shot.key.position.copy(shot.keyHome)
        shot.key.position.x += k[0] * shot.keySize
        shot.key.position.z += k[1] * shot.keySize
      }

      renderer.setRenderTarget(this.one)
      renderer.setClearColor(scene.userData.ground || 0x000000, 1)
      renderer.clear()
      renderer.render(scene, camera)
      camera.position.copy(this.home)

      this.add.material.uniforms.tMap.value = this.one.texture
      this.add.material.uniforms.uWeight.value = 1 / samples
      renderer.setRenderTarget(this.sum)
      renderer.autoClear = false
      this.add.render(renderer)
      renderer.autoClear = true
    }
    camera.updateProjectionMatrix()
    camera.updateMatrixWorld(true)

    this.copy.material.uniforms.tMap.value = this.sum.texture
    renderer.setRenderTarget(this.mean)
    this.copy.render(renderer)
    if (look.bloom !== 0) {
      this.bloom.strength = look.bloom ?? 0.08
      this.bloom.render(renderer, null, this.mean, 0, false)
    }

    const u = this.finish.material.uniforms
    u.tMap.value = this.mean.texture
    u.uExposure.value = look.exposure ?? 1
    u.uFade.value = look.fade ?? 1
    u.uSeed.value = look.seed ?? 0
    u.uGrain.value = look.grain ?? 0.018
    u.uHasOver.value = look.overlay ? 1 : 0
    if (look.overlay) {
      this.overlay.image = look.overlay
      this.overlay.needsUpdate = true
    }
    renderer.setRenderTarget(null)
    this.finish.render(renderer)
  }
}

FilmRenderer.prototype.pattern = function (count) {
  if (!this.patterns.has(count)) {
    this.patterns.set(count, { lens: lensPattern(count), order: shuffled(count, 0x9e3779b9), lamp: shuffled(count, 0x85ebca6b) })
  }
  return this.patterns.get(count)
}

