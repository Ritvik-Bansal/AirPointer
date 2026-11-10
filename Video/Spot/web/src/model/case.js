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

