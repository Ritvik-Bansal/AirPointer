// The sound, made the same way as the picture: from the timeline, by code.
//
// Nothing here is recorded or sampled. A slow pad and a quiet pulse hold the film
// together; over them sit the few sounds the picture asks for, each placed on the cue
// that the picture itself is drawn from: the lid, the taps on the case, the clicks they
// become, the air of each camera move, and a short chime under the name.
//
// There is no voice. The only voices on this Mac are the compact system ones, which sound
// like a machine reading, and the words are on the screen already.

import { CUE, TAPS, CLICKS, DURATION } from './timeline.js'

const RATE = 48000
const hz = midi => 440 * Math.pow(2, (midi - 69) / 12)

// Four chords, D minor rising to rest on F: one for each stretch of the film.
const CHORDS = [
  { from: 0.0, bass: 38, notes: [57, 62, 65, 69, 76] },
  { from: 5.5, bass: 34, notes: [58, 62, 65, 69, 74] },
  { from: 9.0, bass: 41, notes: [57, 60, 65, 69, 72] },
  { from: 12.5, bass: 36, notes: [55, 60, 64, 67, 74] },
  { from: 15.0, bass: 38, notes: [57, 62, 65, 69, 76] },
  { from: 19.0, bass: 34, notes: [58, 62, 65, 69, 74] },
  { from: 22.0, bass: 36, notes: [55, 60, 64, 67, 72] },
  { from: 25.0, bass: 41, notes: [53, 60, 65, 69, 72, 77] },
]

/// A repeatable random source, so the same film always has the same sound.
function seeded(seed) {
  let a = seed >>> 0
  return () => {
    a = (a + 0x6D2B79F5) >>> 0
    let t = a
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

export async function renderSound() {
  const length = Math.ceil((DURATION + 0.02) * RATE)
  const ctx = new OfflineAudioContext(2, length, RATE)
  const random = seeded(20261110)

  const noise = ctx.createBuffer(1, RATE * 4, RATE)
  { const d = noise.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = random() * 2 - 1 }

  // The room: a few seconds of decaying noise, darker as it dies away.
  const room = ctx.createConvolver()
  {
    const seconds = 3.4
    const ir = ctx.createBuffer(2, Math.ceil(seconds * RATE), RATE)
    for (let c = 0; c < 2; c++) {
      const d = ir.getChannelData(c)
      let low = 0
      for (let i = 0; i < d.length; i++) {
        const t = i / RATE
        const raw = (random() * 2 - 1) * Math.pow(1 - t / seconds, 2.2) * Math.exp(-t * 1.5)
        const k = 0.18 + 0.75 * Math.exp(-t * 2.4) // the one-pole filter closes over time
        low += (raw - low) * k
        d[i] = low * (t < 0.012 ? t / 0.012 : 1)
      }
    }
    room.buffer = ir
  }

  // Master: a gentle compressor, then the fade at the very end.
  const master = ctx.createGain()
  const squeeze = ctx.createDynamicsCompressor()
  squeeze.threshold.value = -18
  squeeze.knee.value = 14
  squeeze.ratio.value = 2.5
  squeeze.attack.value = 0.012
  squeeze.release.value = 0.28
  const out = ctx.createGain()
  out.gain.setValueAtTime(1, 0)
  out.gain.setValueAtTime(1, DURATION - 1.5)
  out.gain.linearRampToValueAtTime(0.0001, DURATION - 0.02)
  master.connect(squeeze).connect(out).connect(ctx.destination)
  const wet = ctx.createGain()
  wet.gain.value = 0.5
  room.connect(wet).connect(master)

  /// A gain that starts silent. (A fresh gain passes everything until its first scheduled
  /// value, which would let a note through at full level for the instant before its fade-in.)
  const quiet = () => { const g = ctx.createGain(); g.gain.value = 0; return g }

  /// Sends a node to the mix: `dry` straight in, `space` through the room.
  const send = (node, dry, space) => {
    if (dry > 0) { const g = ctx.createGain(); g.gain.value = dry; node.connect(g).connect(master) }
    if (space > 0) { const g = ctx.createGain(); g.gain.value = space; node.connect(g).connect(room) }
  }
  const panned = (node, pan) => { const p = ctx.createStereoPanner(); p.pan.value = pan; node.connect(p); return p }

  const rendered = await ctx.startRendering()
  return wav(rendered)
}

/// 16-bit stereo WAV, as base64.
function wav(buffer) {
  const frames = buffer.length, channels = 2
  const bytes = new Uint8Array(44 + frames * channels * 2)
  const view = new DataView(bytes.buffer)
  const text = (at, s) => { for (let i = 0; i < s.length; i++) view.setUint8(at + i, s.charCodeAt(i)) }
  text(0, 'RIFF'); view.setUint32(4, 36 + frames * channels * 2, true); text(8, 'WAVE')
  text(12, 'fmt '); view.setUint32(16, 16, true); view.setUint16(20, 1, true); view.setUint16(22, channels, true)
  view.setUint32(24, buffer.sampleRate, true); view.setUint32(28, buffer.sampleRate * channels * 2, true)
  view.setUint16(32, channels * 2, true); view.setUint16(34, 16, true)
  text(36, 'data'); view.setUint32(40, frames * channels * 2, true)
  const left = buffer.getChannelData(0), right = buffer.getChannelData(1)
  let peak = 0
  for (let i = 0; i < frames; i++) peak = Math.max(peak, Math.abs(left[i]), Math.abs(right[i]))
  // Leave the level as mixed unless it would clip; the harness sets the final loudness.
  const scale = peak > 0.97 ? 0.97 / peak : 1
  for (let i = 0; i < frames; i++) {
    view.setInt16(44 + i * 4, Math.round(Math.max(-1, Math.min(1, left[i] * scale)) * 32767), true)
    view.setInt16(46 + i * 4, Math.round(Math.max(-1, Math.min(1, right[i] * scale)) * 32767), true)
  }
  let binary = ''
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000))
  return btoa(binary)
}
