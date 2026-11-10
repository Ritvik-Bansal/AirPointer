// What the Mac's screen shows: a desktop with the AirPointer window open on it.
//
// The window is redrawn here from the app's own source rather than screen-recorded, so it
// can be driven frame by frame: the same sizes, colours, type and wording as the SwiftUI
// views (App/UI), the dot screen from the same formula as DotScreen.swift, the response
// curve from the same maths as PointerKit's RateShaper, the click ring from ClickHUD.swift.
// The desktop around it is generic.

import { UI } from './layout.js'
import * as T from './timeline.js'

// The app's dark palette (App/UI/Theme.swift).
const C = {
  stage: '#0E151D', floor: '#090E14', panel: '#16202B', ink: '#EAF2F8', inkSoft: '#9FB2C4',
  hairline: '#27343F', key: '#48B9F5', onAction: '#06202F', dotOff: '#2B3947',
}
const rgba = (hex, a) => {
  const n = parseInt(hex.slice(1), 16)
  return `rgba(${n >> 16}, ${(n >> 8) & 255}, ${n & 255}, ${a})`
}
const ROUND = '"SF Rounded", system-ui, sans-serif'
const TEXT = '"SF Text", system-ui, sans-serif'

export function makeScreen() {
  const canvas = document.createElement('canvas')
  canvas.width = UI.width * UI.scale
  canvas.height = UI.height * UI.scale
  const ctx = canvas.getContext('2d', { alpha: false })
  return { canvas, draw: (t, mini) => draw(ctx, t, mini) }
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath()
  ctx.roundRect(x, y, w, h, r)
}
function text(ctx, string, x, y, font, color, align = 'left') {
  ctx.font = font
  ctx.fillStyle = color
  ctx.textAlign = align
  ctx.textBaseline = 'middle'
  ctx.fillText(string, x, y)
}

function draw(ctx, t, mini) {
  ctx.setTransform(UI.scale, 0, 0, UI.scale, 0, 0)
  desktop(ctx)
  const W = UI.window
  ctx.save()
  ctx.translate(W.x, W.y)
  windowFrame(ctx, W)
  ctx.save()
  roundRect(ctx, 0, 0, W.w, W.h, 16)
  ctx.clip()
  room(ctx, W)
  topBar(ctx, W, t)
  const open = T.panelOpen(t)
  stage(ctx, t, -224 * open, mini)
  if (open > 0.001) feelPanel(ctx, t, open)
  tabBar(ctx, t)
  ctx.restore()
  // The hairline the system draws round a dark window.
  roundRect(ctx, 0.5, 0.5, W.w - 1, W.h - 1, 15.5)
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.10)'
  ctx.lineWidth = 1
  ctx.stroke()
  ctx.restore()
  clickRings(ctx, t)
  pointer(ctx, t)
}

// --- The desktop -----------------------------------------------------------------------

function desktop(ctx) {
  // A plain wallpaper: one deep blue, and one large flat shape for the eye to rest on.
  ctx.fillStyle = '#0B1A2E'
  ctx.fillRect(0, 0, UI.width, UI.height)
  ctx.fillStyle = '#0F2440'
  ctx.beginPath()
  ctx.arc(1010, 940, 620, 0, Math.PI * 2)
  ctx.fill()
  ctx.fillStyle = '#12305A'
  ctx.beginPath()
  ctx.arc(1240, 1010, 420, 0, Math.PI * 2)
  ctx.fill()

  ctx.fillStyle = 'rgba(6, 10, 16, 0.74)'
  ctx.fillRect(0, 0, UI.width, UI.menuBar)
  const y = UI.menuBar / 2 + 0.5
  const ink = 'rgba(236, 242, 248, 0.92)'
  text(ctx, 'AirPointer', 20, y, `700 13px ${TEXT}`, ink)
  let x = 20 + measure(ctx, 'AirPointer', `700 13px ${TEXT}`) + 20
  for (const item of ['File', 'Edit', 'View', 'Window', 'Help']) {
    text(ctx, item, x, y, `500 13px ${TEXT}`, ink)
    x += measure(ctx, item, `500 13px ${TEXT}`) + 20
  }
  text(ctx, '9:41', UI.width - 16, y, `500 13px ${TEXT}`, ink, 'right')
  text(ctx, 'Tue 10 Nov', UI.width - 58, y, `500 13px ${TEXT}`, ink, 'right')
  // The app's place in the menu bar: a small case, lit.
  const gx = UI.width - 158
  roundRect(ctx, gx - 7, y - 5.5, 14, 11, 3.6)
  ctx.strokeStyle = C.key
  ctx.lineWidth = 1.5
  ctx.stroke()
  ctx.beginPath()
  ctx.moveTo(gx - 7, y - 1.6)
  ctx.lineTo(gx + 7, y - 1.6)
  ctx.stroke()
}
function measure(ctx, string, font) {
  ctx.font = font
  return ctx.measureText(string).width
}

