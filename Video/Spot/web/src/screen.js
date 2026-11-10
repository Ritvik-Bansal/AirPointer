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

