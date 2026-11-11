// Renders the spot: serves the page, drives it in headless Chrome one frame at a time, and
// has ffmpeg encode the frames once they are all drawn.
//
//   node tools/render.mjs film <out.mp4> [--from s] [--to s] [--samples n] [--scale n]
//   node tools/render.mjs stills <folder> <seconds>... [--samples n] [--scale n]
//   node tools/render.mjs views <folder> <views.json> [--scale n]     the model alone
//   node tools/render.mjs sound <out.wav>
//   node tools/render.mjs serve                                       a page to scrub the film in
//
// --address "text" sets the line under the name on the end card ("" for none).
//
// The folder that holds node_modules and the baked meshes is given by SPOT_CACHE.

import http from 'node:http'
import { createReadStream, existsSync, statSync, mkdirSync, writeFileSync, readFileSync, readdirSync, renameSync, rmSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { spawn } from 'node:child_process'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const here = path.dirname(fileURLToPath(import.meta.url))
const web = path.join(here, '../web')
const cache = process.env.SPOT_CACHE
if (!cache || !existsSync(path.join(cache, 'node_modules'))) {
  console.error('spot: set SPOT_CACHE to the folder holding node_modules (render.sh does this).')
  process.exit(1)
}
const require = createRequire(path.join(cache, 'node_modules') + '/')
const puppeteer = require('puppeteer-core')

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.ttf': 'font/ttf', '.png': 'image/png', '.wasm': 'application/wasm' }
const ROUTES = [
  ['/vendor/three/', path.join(cache, 'node_modules/three/')],
  ['/meshes/', path.join(cache, 'meshes/')],
  ['/fonts/', '/System/Library/Fonts/'],
  ['/', web + '/'],
]
const FONTS = new Set(['SFNSRounded.ttf', 'SFNS.ttf', 'SFNSMono.ttf'])

function serve() {
  const server = http.createServer((request, response) => {
    const url = decodeURIComponent(new URL(request.url, 'http://x').pathname)
    for (const [prefix, folder] of ROUTES) {
      if (!url.startsWith(prefix)) continue
      let rest = url.slice(prefix.length) || 'index.html'
      if (prefix === '/fonts/' && !FONTS.has(rest)) break
      const file = path.normalize(path.join(folder, rest))
      if (!file.startsWith(folder) || !existsSync(file) || !statSync(file).isFile()) break
      response.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' })
      createReadStream(file).pipe(response)
      return
    }
    response.writeHead(404); response.end('not found')
  })
  return new Promise(resolve => server.listen(0, '127.0.0.1', () => resolve(server)))
}

function chromePath() {
  const candidates = [
    process.env.SPOT_CHROME,
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
  ].filter(Boolean)
  const found = candidates.find(existsSync)
  if (!found) { console.error('spot: no Chrome found. Install Google Chrome, or set SPOT_CHROME to a Chromium binary.'); process.exit(1) }
  return found
}

function flag(args, name, fallback) {
  const i = args.indexOf(name)
  if (i < 0) return fallback
  const value = args[i + 1]
  args.splice(i, 2)
  return value
}

async function open(scale, extra = '') {
  const server = await serve()
  const browser = await puppeteer.launch({
    executablePath: chromePath(),
    headless: true,
    args: ['--headless=new', '--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist', '--hide-scrollbars',
      '--force-device-scale-factor=1', '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
      '--autoplay-policy=no-user-gesture-required', `--window-size=${Math.round(1920 * scale)},${Math.round(1080 * scale)}`],
    defaultViewport: { width: Math.round(1920 * scale), height: Math.round(1080 * scale), deviceScaleFactor: 1 },
    protocolTimeout: 600000,
  })
  const page = await browser.newPage()
  page.on('console', m => { if ((m.type() === 'error' || m.type() === 'warning') && !/404/.test(m.text())) console.error(`[page ${m.type()}] ${m.text()}`) })
  page.on('pageerror', e => console.error(`[page error] ${e.message}`))
  // Loading can fail for reasons that have nothing to do with the film (Chrome drops
  // requests in flight when the Mac changes network, even ones to this machine), so it is
  // tried again before giving up.
  for (let attempt = 1; ; attempt++) {
    try {
      await page.goto(`http://127.0.0.1:${server.address().port}/index.html?scale=${scale}${extra}`, { waitUntil: 'load' })
      await page.evaluate(() => window.SPOT.ready)
      break
    } catch (error) {
      if (attempt >= 4) { await browser.close(); server.close(); throw error }
      console.error(`Loading the page failed (${String(error.message).split('\n')[0]}); trying again.`)
      await new Promise(resolve => setTimeout(resolve, 1500 * attempt))
    }
  }
  const close = async () => { await browser.close(); server.close() }
  return { page, close }
}

const png = async page => Buffer.from((await page.evaluate(() => window.SPOT.png())).split(',')[1], 'base64')

/// Draws one frame and returns it as a PNG, or throws if the browser did not really draw it.
/// A browser short of memory can lose its graphics context without raising anything: the
/// page carries on and every frame after that comes back the same blank picture. Grain
/// makes every true frame different from the last, so a repeat is proof of a failure.
let lastDigest = null
async function draw(page, index, count) {
  await page.evaluate((n, s) => window.SPOT.frame(n, { samples: s }), index, count)
  if (await page.evaluate(() => window.SPOT.film.renderer.getContext().isContextLost())) {
    throw new Error('the browser lost its graphics context')
  }
  const image = await png(page)
  const digest = createHash('md5').update(image).digest('hex')
  if (digest === lastDigest) throw new Error('the frame came out identical to the one before')
  lastDigest = digest
  return image
}

const args = process.argv.slice(2)
const command = args.shift()
const scale = Number(flag(args, '--scale', 1))
const samples = flag(args, '--samples', null)
const address = flag(args, '--address', null)
const extra = address === null ? '' : `&address=${encodeURIComponent(address)}`

if (command === 'views') {
  const [folder, file] = args
  mkdirSync(folder, { recursive: true })
  const views = JSON.parse(readFileSync(file, 'utf8'))
  const { page, close } = await open(scale, extra)
  for (const view of views) {
    const ms = await page.evaluate(v => window.SPOT.still(v), view)
    writeFileSync(path.join(folder, view.name + '.png'), await png(page))
    console.log(`${view.name}  ${Math.round(ms)} ms`)
  }
  await close()
} else if (command === 'stills') {
  const folder = args.shift()
  mkdirSync(folder, { recursive: true })
  const { page, close } = await open(scale, extra)
  const fps = await page.evaluate(() => window.SPOT.fps)
  for (const t of args.map(Number)) {
    const started = Date.now()
    const name = `t${t.toFixed(2).padStart(5, '0')}.png`
    writeFileSync(path.join(folder, name), await draw(page, Math.round(t * fps), samples ? Number(samples) : null))
    console.log(`${name}  ${((Date.now() - started) / 1000).toFixed(1)} s`)
  }
  await close()
} else if (command === 'film') {
  // Frames are drawn to disk first and encoded afterwards. Encoding while drawing has the
  // two fight for the processor, and on a Mac running on battery the encoder wins: frames
  // that take half a second each then take twenty. Drawing to disk also means a run that is
  // interrupted picks up where it stopped.
  const out = args.shift()
  const folder = path.join(path.dirname(out), 'frames')
  mkdirSync(folder, { recursive: true })
  // Frames left by an earlier run are kept only if nothing they depend on has changed.
  const hash = createHash('sha256')
  const walk = dir => readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name)).forEach(entry => {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) walk(full); else hash.update(entry.name).update(readFileSync(full))
  })
  walk(web)
  walk(path.join(cache, 'meshes'))
  const key = hash.update(JSON.stringify([scale, samples, address])).digest('hex')
  const keyFile = path.join(folder, 'key')
  if (!existsSync(keyFile) || readFileSync(keyFile, 'utf8') !== key) {
    for (const name of readdirSync(folder)) rmSync(path.join(folder, name))
    writeFileSync(keyFile, key)
  }

  let session = await open(scale, extra)
  const { fps, frames } = await session.page.evaluate(() => ({ fps: window.SPOT.fps, frames: window.SPOT.frames }))
  const first = Math.round(Number(flag(args, '--from', 0)) * fps)
  const last = Math.min(frames, Math.round(Number(flag(args, '--to', frames / fps)) * fps))
  const file = i => path.join(folder, `f${String(i).padStart(5, '0')}.png`)
  const started = Date.now()
  let drawn = 0
  for (let i = first; i < last; i++) {
    if (existsSync(file(i))) continue
    if (lastDigest === null && i > first && existsSync(file(i - 1))) lastDigest = createHash('md5').update(readFileSync(file(i - 1))).digest('hex')
    for (let attempt = 1; ; attempt++) {
      try {
        writeFileSync(file(i) + '.part', await draw(session.page, i, samples ? Number(samples) : null))
        renameSync(file(i) + '.part', file(i))
        break
      } catch (error) {
        if (attempt >= 5) throw error
        console.error(`\nframe ${i + 1}: ${String(error.message).split('\n')[0]}. Reopening the browser and trying again.`)
        try { await session.close() } catch {}
        session = await open(scale, extra)
      }
    }
    drawn++
    if (drawn % 30 === 0 || i === last - 1) {
      const each = (Date.now() - started) / 1000 / drawn
      process.stdout.write(`\rframe ${i + 1} of ${last}  ${each.toFixed(2)} s each  ${Math.round(each * (last - i - 1))} s to go   `)
    }
  }
  await session.close()
  console.log(`\nDrew ${drawn} frames in ${Math.round((Date.now() - started) / 1000)} s${drawn < last - first ? ` (${last - first - drawn} were already there)` : ''}.`)

  const encoder = spawn('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y',
    '-framerate', String(fps), '-start_number', String(first), '-i', path.join(folder, 'f%05d.png'), '-frames:v', String(last - first),
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '14', '-pix_fmt', 'yuv420p',
    '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709',
    '-vf', 'scale=out_color_matrix=bt709:out_range=tv', '-movflags', '+faststart', out], { stdio: ['ignore', 'inherit', 'inherit'] })
  await new Promise((resolve, reject) => { encoder.on('exit', code => code === 0 ? resolve() : reject(new Error(`ffmpeg exited with ${code}`))) })
  console.log(`Wrote ${out}: ${last - first} frames.`)
} else if (command === 'sound') {
  const out = args.shift()
  const { page, close } = await open(scale, extra)
  const b64 = await page.evaluate(() => window.SPOT.sound())
  writeFileSync(out, Buffer.from(b64, 'base64'))
  await close()
  console.log(`Wrote ${out}.`)
} else if (command === 'serve') {
  const server = await serve()
  const url = `http://127.0.0.1:${server.address().port}/preview.html`
  console.log(`The film is at ${url}\nPress Ctrl-C to stop.`)
  if (!process.env.SPOT_NO_OPEN) spawn('open', [url], { stdio: 'ignore' })
} else {
  console.error('usage: render.mjs film|stills|views|sound|serve ... (see the top of this file)')
  process.exit(1)
}
