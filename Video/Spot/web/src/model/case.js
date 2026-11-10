// The AirPods case as a Three.js object, assembled from the baked meshes.
//
// Everything here is in millimetres, in the case's own axes (see airpods.js). The caller
// scales the root to the scene.

import * as THREE from 'three'
import { DIM, SEAM, HINGE_AXIS, WINDOWS, TIP_MESH, LIGHT, PRINT, HOLES, budMatrix } from './airpods.js'

async function array(url, Type) {
  const response = await fetch(url)
  if (!response.ok) throw new Error(`Missing mesh file ${url}. Run the bake first.`)
  return new Type(await response.arrayBuffer())
}

export async function loadGeometry(name, level = 0) {
  const stem = `/meshes/${name}.${level}`
  const [pos, nrm, idx, ao] = await Promise.all([
    array(stem + '.pos', Float32Array), array(stem + '.nrm', Float32Array),
    array(stem + '.idx', Uint32Array), array(stem + '.ao', Uint8Array),
  ])
  const geometry = new THREE.BufferGeometry()
  geometry.setAttribute('position', new THREE.BufferAttribute(pos, 3))
  geometry.setAttribute('normal', new THREE.BufferAttribute(nrm, 3))
  geometry.setAttribute('ao', new THREE.BufferAttribute(ao, 1, true))
  geometry.setIndex(new THREE.BufferAttribute(idx, 1))
  geometry.computeBoundingSphere()
  geometry.computeBoundingBox()
  return geometry
}

/// How long a tap's ring lasts, seconds.
export const TAP_LIFE = 0.6

const glsl = n => (Number.isInteger(n) ? n.toFixed(1) : String(n))
const vec3 = a => `vec3(${a.map(glsl).join(', ')})`

/// Adds to a standard material what the model needs beyond it: the baked ambient light,
/// and whatever is painted on this part rather than modelled (the black windows of an
/// AirPod, the print and the light on the case, the rings a tap sends out).
function extend(material, { windows = [], light = false, print = false, taps = false, shade = 1 } = {}) {
  const uniforms = {
    uLight: { value: new THREE.Color(0, 0, 0) },
    uPrint: { value: null },
    uTaps: { value: [new THREE.Vector2(-1, 0), new THREE.Vector2(-1, 0), new THREE.Vector2(-1, 0)] },
    uTapAt: { value: new THREE.Vector3(0, 0, -DIM.D) },
    uTapColor: { value: new THREE.Color(0x48b9f5) },
    uShade: { value: shade },
  }
  material.userData.uniforms = uniforms

  let paint = ''
  if (windows.length) {
    paint += 'float apGloss = 0.0, apMesh = 0.0, apLine = 0.0; vec2 apUv = vec2(0.0);\n'
    for (const w of windows) {
      paint += `{
        vec3 q = vObj - ${vec3(w.at)};
        vec2 uv = vec2(dot(q, ${vec3(w.u)}), dot(q, ${vec3(w.v)}));
        vec2 ab = vec2(${glsl(w.a)}, ${glsl(w.b)});
        float edge = (length(uv / ab) - 1.0) * min(ab.x, ab.y);
        float aa = max(fwidth(edge), 1e-4);
        float side = smoothstep(0.1, 0.35, dot(normalize(vObjN), ${vec3(w.normal)})) * step(abs(dot(q, ${vec3(w.normal)})), 5.0);
        float inside = (1.0 - smoothstep(-aa, aa, edge)) * side;
        ${w.finish === 'gloss' ? 'apGloss' : 'apMesh'} = max(${w.finish === 'gloss' ? 'apGloss' : 'apMesh'}, inside);
        ${w.finish === 'mesh' ? 'if (inside > 0.0) apUv = uv;' : ''}
        apLine = max(apLine, (1.0 - smoothstep(0.03, 0.03 + aa, abs(edge))) * side);
      }\n`
    }
    paint += `
      // A woven grille: fine dots that melt into a flat tone once they are smaller than a pixel.
      vec2 apCell = apUv / 0.17;
      float apDots = 0.5 + 0.5 * sin(apCell.x * 6.2832) * sin(apCell.y * 6.2832);
      float apFine = 1.0 - smoothstep(0.25, 0.7, max(fwidth(apCell.x), fwidth(apCell.y)));
      vec3 apGrille = mix(vec3(0.016), vec3(0.016) * mix(1.0, 0.25 + 1.6 * apDots, apFine), 1.0);
      diffuseColor.rgb = mix(diffuseColor.rgb, vec3(0.0025), apGloss);
      diffuseColor.rgb = mix(diffuseColor.rgb, apGrille, apMesh);
      diffuseColor.rgb *= 1.0 - 0.6 * apLine * (1.0 - max(apGloss, apMesh));
    `
  }
  if (print) {
    paint += `
      if (vObj.z < ${glsl(-DIM.D + 0.5)}) {
        vec2 puv = vec2(0.5 - vObj.x / ${glsl(PRINT.width + 1)}, (vObj.y - ${glsl(PRINT.y - PRINT.pitch * 1.25)}) / ${glsl(PRINT.pitch * 2.5)});
        if (puv.x > 0.0 && puv.x < 1.0 && puv.y > 0.0 && puv.y < 1.0) {
          diffuseColor.rgb = mix(diffuseColor.rgb, vec3(0.56, 0.57, 0.58), texture2D(uPrint, puv).r * 0.9);
        }
      }
    `
  }
  const finish = windows.length ? `
      roughnessFactor = mix(roughnessFactor, 0.05, apGloss);
      roughnessFactor = mix(roughnessFactor, 0.72, apMesh);
    ` : ''
  const coat = windows.length ? 'material.clearcoat *= 1.0 - apMesh;\n' : ''
  let glow = ''
  if (light) {
    glow += `
      {
        vec2 d = vObj.xy - vec2(${glsl(LIGHT.x)}, ${glsl(LIGHT.y)});
        float r2 = dot(d, d);
        // A small bright core, and the wider bloom of light scattering in the plastic.
        float core = exp(-r2 / ${glsl(2 * (LIGHT.radius * 0.5) ** 2)});
        float halo = 0.06 * exp(-r2 / ${glsl(2 * (LIGHT.radius * 1.5) ** 2)});
        totalEmissiveRadiance += uLight * (core + halo) * step(${glsl(DIM.D - 2)}, vObj.z);
      }
    `
  }
  if (taps) {
    // A tap lands on the back of the case, low and to one side, and sends a ring out across
    // the plastic from there: round the side and on over the front. Each entry of uTaps is
    // a tap's age in seconds (negative for none) and its strength.
    // The ring travels along the surface, not straight through the case: its distance is
    // measured round the case's waist from the tap, across the back, round the left side and
    // on over the front, as if the plastic were unrolled flat.
    const edge = -DIM.W + DIM.D
    glow += `
      float apBelt;
      {
        float fromEdge = uTapAt.x - ${glsl(edge)};
        if (vObj.x >= ${glsl(edge)}) {
          apBelt = vObj.z < 0.0 ? uTapAt.x - vObj.x : fromEdge + ${glsl(Math.PI * DIM.D)} + (vObj.x - ${glsl(edge)});
        } else {
          apBelt = fromEdge + (atan(vObj.z, ${glsl(edge)} - vObj.x) + 1.5708) * ${glsl(DIM.D)};
        }
      }
      for (int i = 0; i < 3; i++) {
        vec2 tap = uTaps[i];
        if (tap.x < 0.0) continue;
        float life = tap.x / ${glsl(TAP_LIFE)};
        float dist = length(vec2(apBelt, vObj.y - uTapAt.y));
        float radius = 1.0 + 76.0 * (1.0 - pow(1.0 - min(life, 1.0), 2.2));
        // A fine line with a defined edge, and a faint breath of light either side of it.
        float width = 0.6 + 0.9 * life;
        float off = abs(dist - radius);
        float line = 1.0 - smoothstep(width * 0.5, width, off);
        float breath = 0.14 * exp(-pow(off / (width * 3.0), 2.0));
        float ring = (line + breath) * pow(max(0.0, 1.0 - life), 1.2);
        float seed = exp(-dist * dist / 6.0) * max(0.0, 1.0 - tap.x / 0.12);
        totalEmissiveRadiance += uTapColor * tap.y * (ring + seed);
      }
    `
  }

  material.onBeforeCompile = shader => {
    Object.assign(shader.uniforms, uniforms)
    shader.vertexShader = shader.vertexShader
      .replace('#include <common>', '#include <common>\nattribute float ao;\nvarying float vAo;\nvarying vec3 vObj;\nvarying vec3 vObjN;')
      .replace('#include <begin_vertex>', '#include <begin_vertex>\nvAo = ao;\nvObj = position;\nvObjN = normal;')
    shader.fragmentShader = shader.fragmentShader
      .replace('#include <common>', `#include <common>
        varying float vAo; varying vec3 vObj; varying vec3 vObjN;
        uniform vec3 uLight; uniform sampler2D uPrint; uniform vec2 uTaps[3]; uniform vec3 uTapAt; uniform vec3 uTapColor; uniform float uShade;`)
      .replace('#include <color_fragment>', '#include <color_fragment>\n' + paint)
      .replace('#include <roughnessmap_fragment>', '#include <roughnessmap_fragment>\n' + finish)
      .replace('#include <lights_physical_fragment>', '#include <lights_physical_fragment>\n' + coat)
      .replace('#include <emissivemap_fragment>', '#include <emissivemap_fragment>\n' + glow)
      .replace('#include <aomap_fragment>', `
        // Baked ambient light. It closes off the sky fully and, because the fill lights here
        // cast no shadows of their own, the direct light partly too.
        float apAo = mix(1.0, vAo, uShade);
        float apNV = saturate(dot(geometryNormal, geometryViewDir));
        float apSpec = saturate(pow(apNV + apAo, exp2(-16.0 * material.roughness - 1.0)) - 1.0 + apAo);
        reflectedLight.indirectDiffuse *= apAo;
        reflectedLight.indirectSpecular *= apSpec;
        reflectedLight.directDiffuse *= mix(1.0, apAo, 0.55);
        reflectedLight.directSpecular *= mix(1.0, apAo, 0.55);
        #if defined( USE_CLEARCOAT )
          clearcoatSpecularIndirect *= apSpec;
          clearcoatSpecularDirect *= mix(1.0, apAo, 0.55);
        #endif
        #if defined( USE_SHEEN )
          sheenSpecularIndirect *= apAo;
        #endif
      `)
  }
  material.customProgramCacheKey = () => JSON.stringify([windows.map(w => w.name), light, print, taps])
  return material
}

