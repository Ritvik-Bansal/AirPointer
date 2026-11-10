// Bakes the AirPods model into meshes.
//
//   node tools/bake.mjs <output folder> [--only name] [--force]
//
// Each part in web/src/model/airpods.js is meshed twice (a fine copy for the film, a light
// one for small views), with a normal and an ambient-light value per vertex, and written as
// raw arrays next to a manifest. The work is skipped when the model's source has not changed.

import { Worker, isMainThread, parentPort, workerData } from 'node:worker_threads'
import { createHash } from 'node:crypto'
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import os from 'node:os'

const here = path.dirname(fileURLToPath(import.meta.url))
const modelDir = path.join(here, '../web/src/model')

if (isMainThread) {
  const args = process.argv.slice(2)
  const out = args.find(a => !a.startsWith('--'))
  if (!out) { console.error('usage: node tools/bake.mjs <output folder> [--only name] [--force]'); process.exit(1) }
  const only = args.includes('--only') ? args[args.indexOf('--only') + 1] : null
  mkdirSync(out, { recursive: true })
  const hash = createHash('sha256')
    .update(readFileSync(path.join(modelDir, 'sdf.js')))
    .update(readFileSync(path.join(modelDir, 'airpods.js')))
    .digest('hex').slice(0, 16)
  const manifestPath = path.join(out, 'manifest.json')
  if (!args.includes('--force') && !only && existsSync(manifestPath)) {
    const old = JSON.parse(readFileSync(manifestPath, 'utf8'))
    if (old.hash === hash) { console.log('Model unchanged; meshes are up to date.'); process.exit(0) }
  }
  const { PARTS } = await import(path.join(modelDir, 'airpods.js'))
  const jobs = []
  for (const part of PARTS) {
    if (only && part.name !== only) continue
    part.cell.forEach((cell, level) => jobs.push({ name: part.name, level, cell }))
  }
  // Biggest first, so the long ones start at once.
  jobs.sort((a, b) => a.cell - b.cell)
  const started = Date.now()
  const results = []
  let next = 0
  await new Promise((resolve, reject) => {
    let running = 0
    const launch = () => {
      while (running < Math.max(2, os.availableParallelism() - 2) && next < jobs.length) {
        const job = jobs[next++]
        running++
        const worker = new Worker(fileURLToPath(import.meta.url), { workerData: { job, out } })
        worker.on('message', r => {
          results.push(r)
          console.log(`${r.name}.${r.level}  ${String(r.vertices).padStart(7)} vertices  ${String(r.triangles).padStart(7)} triangles  ${r.seconds.toFixed(1)} s${r.holes ? `  HOLES: ${r.holes}` : ''}`)
        })
        worker.on('error', reject)
        worker.on('exit', () => { running--; if (next >= jobs.length && running === 0) resolve(); else launch() })
      }
    }
    launch()
  })
  if (!only) {
    results.sort((a, b) => a.name.localeCompare(b.name) || a.level - b.level)
    writeFileSync(manifestPath, JSON.stringify({ hash, parts: results }, null, 1))
  }
  console.log(`Baked ${results.length} meshes in ${((Date.now() - started) / 1000).toFixed(1)} s.`)
} else {
  const { job, out } = workerData
  const { surfaceNets, ambient } = await import(path.join(modelDir, 'sdf.js'))
  const { PARTS } = await import(path.join(modelDir, 'airpods.js'))
  const part = PARTS.find(p => p.name === job.name)
  const t0 = Date.now()
  const mesh = surfaceNets(part.field, part.bounds, job.cell)
  const ao = ambient(mesh.positions, mesh.normals, part.occluder)
  const stem = path.join(out, `${job.name}.${job.level}`)
  writeFileSync(stem + '.pos', Buffer.from(mesh.positions.buffer))
  writeFileSync(stem + '.nrm', Buffer.from(mesh.normals.buffer))
  writeFileSync(stem + '.idx', Buffer.from(mesh.indices.buffer))
  writeFileSync(stem + '.ao', Buffer.from(ao.buffer))
  parentPort.postMessage({
    name: job.name, level: job.level, cell: job.cell,
    vertices: mesh.positions.length / 3, triangles: mesh.indices.length / 3,
    holes: mesh.holes, seconds: (Date.now() - t0) / 1000,
  })
}
