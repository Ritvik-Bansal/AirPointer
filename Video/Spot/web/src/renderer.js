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

/// The numbers 0 to count - 1 in a fixed scrambled order.
function shuffled(count, seed) {
  const order = Array.from({ length: count }, (_, i) => i)
  let a = seed >>> 0
  const next = () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296 }
  for (let i = count - 1; i > 0; i--) { const j = Math.floor(next() * (i + 1)); [order[i], order[j]] = [order[j], order[i]] }
  return order
}

/// Points spread evenly over a disc (a sunflower), radius 1.
function lensPattern(count) {
  const points = []
  for (let i = 0; i < count; i++) {
    const r = Math.sqrt((i + 0.5) / count), a = i * GOLDEN
    points.push([r * Math.cos(a), r * Math.sin(a)])
  }
  return points
}

function halton(index, base) {
  let f = 1, r = 0
  while (index > 0) { f /= base; r += f * (index % base); index = Math.floor(index / base) }
  return r
}

const FINISH = /* glsl */`
  uniform sampler2D tMap, tOver;
  uniform float uHasOver, uExposure, uFade, uSeed, uGrain, uContrast, uSaturation, uVignette;
  uniform vec2 uSize;
  varying vec2 vUv;

  // Khronos PBR Neutral: leaves colours alone until they are nearly white, then rolls them off.
  vec3 neutral(vec3 color) {
    const float start = 0.8 - 0.04;
    const float desaturation = 0.15;
    float x = min(color.r, min(color.g, color.b));
    float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
    color -= offset;
    float peak = max(color.r, max(color.g, color.b));
    if (peak < start) return color;
    float d = 1.0 - start;
    float newPeak = 1.0 - d * d / (peak + d - start);
    color *= newPeak / peak;
    float g = 1.0 - 1.0 / (desaturation * (peak - newPeak) + 1.0);
    return mix(color, vec3(newPeak), g);
  }
  vec3 toDisplay(vec3 c) {
    return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
  }
  float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
  }

  void main() {
    vec3 c = texture2D(tMap, vUv).rgb * uExposure;
    // The corners fall off a little, as through a real lens.
    vec2 centred = (vUv - 0.5) * vec2(uSize.x / uSize.y, 1.0);
    c *= 1.0 - uVignette * smoothstep(0.35, 1.05, length(centred));
    c = neutral(c);
    c = toDisplay(clamp(c, 0.0, 1.0));
    // Grade, in display space: a touch more contrast about mid-grey, a touch more colour.
    c = clamp((c - 0.5) * uContrast + 0.5 + 0.012, 0.0, 1.0);
    float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
    c = clamp(mix(vec3(luma), c, uSaturation), 0.0, 1.0);
    // Grain, strongest in the mid-tones, which also hides banding in the dark.
    float n = hash(gl_FragCoord.xy + uSeed * 17.0) + hash(gl_FragCoord.yx * 1.3 + uSeed * 29.0) - 1.0;
    c += n * uGrain * (0.35 + 0.65 * (1.0 - abs(2.0 * luma - 1.0)));
    c *= uFade;
    if (uHasOver > 0.5) {
      vec4 over = texture2D(tOver, vUv);
      c = c * (1.0 - over.a) + over.rgb;
    }
    gl_FragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
  }
`
