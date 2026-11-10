// The words laid over the picture.
//
// One block, bottom left, in the app's own display face. A line rises into place as it
// arrives and leaves by fading; nothing spins, bounces or types itself.

import * as T from './timeline.js'

const ROUND = '"SF Rounded", system-ui, sans-serif'
const TEXT = '"SF Text", system-ui, sans-serif'
const INK = [243, 247, 251]
const KEY = [72, 185, 245]

export function makeTitles(width, height, address) {
  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  const ctx = canvas.getContext('2d')
  const s = width / 1920

  /// Draws one line: rising over its first 0.7 s, fading over its last 0.4 s.
  function line(string, x, y, font, color, t, from, to, { align = 'left', rise = 30, tracking = 0 } = {}) {
    if (t < from || t > to) return
    const arrive = T.outExpo(T.span(t, from, 0.7))
    const leave = 1 - T.smooth(T.span(t, to - 0.4, 0.4))
    const alpha = Math.min(T.span(t, from, 0.28), 1) * leave
    if (alpha <= 0) return
    ctx.save()
    // The line comes up from behind an edge, so it is cut off below its own baseline box.
    ctx.beginPath()
    ctx.rect(0, (y - 130) * s, width, 160 * s)
    ctx.clip()
    ctx.font = font
    ctx.letterSpacing = `${tracking * s}px`
    ctx.textAlign = align
    ctx.textBaseline = 'alphabetic'
    ctx.fillStyle = `rgba(${color[0]}, ${color[1]}, ${color[2]}, ${alpha})`
    ctx.fillText(string, x * s, (y + rise * (1 - arrive)) * s)
    ctx.restore()
  }

  function draw(t) {
    ctx.clearRect(0, 0, width, height)
    const head = `700 ${88 * s}px ${ROUND}`, sub = `400 ${35 * s}px ${TEXT}`
    for (const title of T.TITLES) {
      if (title.line === 1) {
        line(title.head, 128, 944, head, KEY, t, title.from, title.to, { tracking: -1.2 })
      } else if (title.side === 'right') {
        // Set against the right margin, where this shot leaves the picture dark.
        line(title.head, 1792, 838, head, INK, t, title.from, title.to, { tracking: -1.2, align: 'right' })
        line(title.sub, 1790, 898, sub, INK.map(v => v * 0.82), t, title.from + 0.22, title.to, { rise: 22, align: 'right' })
        line(title.sub2, 1790, 944, sub, INK.map(v => v * 0.82), t, title.from + 0.3, title.to, { rise: 22, align: 'right' })
      } else if (title.sub) {
        line(title.head, 128, 884, head, INK, t, title.from, title.to, { tracking: -1.2 })
        line(title.sub, 130, 944, sub, INK.map(v => v * 0.82), t, title.from + 0.22, title.to, { rise: 22 })
      } else {
        line(title.head, 128, 848, head, INK, t, title.from, title.to, { tracking: -1.2 })
      }
    }
    // The end card: the name, what it is, where it lives.
    const e = T.END.from
    line(T.END.name, 1010, 506, `700 ${132 * s}px ${ROUND}`, INK, t, e, 99, { tracking: -2.4, rise: 40 })
    line(T.END.line, 1014, 574, `400 ${37 * s}px ${TEXT}`, INK.map(v => v * 0.84), t, e + 0.3, 99, { rise: 24 })
    if (address) line(address, 1014, 652, `600 ${31 * s}px ${ROUND}`, KEY, t, e + 0.6, 99, { rise: 24, tracking: 0.2 })
    return canvas
  }
  return { canvas, draw }
}
