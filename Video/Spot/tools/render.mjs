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

