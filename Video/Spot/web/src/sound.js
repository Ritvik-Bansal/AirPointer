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

  // --- The pad -------------------------------------------------------------------------

  const padFilter = ctx.createBiquadFilter()
  padFilter.type = 'lowpass'
  padFilter.Q.value = 0.5
  // It opens as the lid does, breathes through the middle, and closes for the ending.
  padFilter.frequency.setValueAtTime(420, 0)
  padFilter.frequency.linearRampToValueAtTime(700, CUE.lidOpens)
  padFilter.frequency.linearRampToValueAtTime(1500, 5.5)
  padFilter.frequency.linearRampToValueAtTime(1150, 12.5)
  padFilter.frequency.linearRampToValueAtTime(2100, 14.2)
  padFilter.frequency.linearRampToValueAtTime(1400, 19)
  padFilter.frequency.linearRampToValueAtTime(1700, 24)
  padFilter.frequency.linearRampToValueAtTime(1000, 27)
  padFilter.frequency.linearRampToValueAtTime(620, DURATION)
  send(padFilter, 0.5, 0.42)

  CHORDS.forEach((chord, index) => {
    const start = chord.from, end = index + 1 < CHORDS.length ? CHORDS[index + 1].from : DURATION
    const attack = index === 0 ? 1.8 : 1.3, release = 1.9
    chord.notes.forEach((midi, voice) => {
      const level = quiet()
      const peak = 0.078 * (voice === chord.notes.length - 1 ? 0.6 : 1)
      level.gain.setValueAtTime(0, Math.max(0, start - 0.45))
      level.gain.linearRampToValueAtTime(peak, Math.max(0.01, start - 0.45) + attack)
      level.gain.setValueAtTime(peak, end - 0.3)
      level.gain.linearRampToValueAtTime(0, Math.min(DURATION, end - 0.3 + release))
      const side = panned(level, (voice % 2 ? 1 : -1) * 0.25 * (voice / chord.notes.length + 0.3))
      side.connect(padFilter)
      for (const [type, cents, gain] of [['triangle', -6, 0.55], ['triangle', 7, 0.55], ['sawtooth', 0, 0.16]]) {
        const osc = ctx.createOscillator()
        osc.type = type
        osc.frequency.value = hz(midi)
        osc.detune.value = cents
        const g = ctx.createGain()
        g.gain.value = gain
        osc.connect(g).connect(level)
        osc.start(Math.max(0, start - 0.5))
        osc.stop(Math.min(DURATION, end + release))
      }
    })
    // The bass: one soft sine under each chord, with a quieter octave above it so that it
    // is still there on small speakers.
    const level = quiet()
    const full = index === 0 ? 0.06 : 0.09
    level.gain.setValueAtTime(0, Math.max(0, start - 0.2))
    level.gain.linearRampToValueAtTime(full, Math.max(0.01, start - 0.2) + 0.9)
    level.gain.setValueAtTime(full, end - 0.25)
    level.gain.linearRampToValueAtTime(0, Math.min(DURATION, end + 0.7))
    send(level, 1, 0.05)
    for (const [octave, gain] of [[1, 1], [2, 0.42]]) {
      const bass = ctx.createOscillator()
      bass.type = 'sine'
      bass.frequency.value = hz(chord.bass) * octave
      const g = ctx.createGain()
      g.gain.value = gain
      bass.connect(g).connect(level)
      bass.start(Math.max(0, start - 0.25))
      bass.stop(Math.min(DURATION, end + 0.8))
    }
  })

  // --- The pulse -----------------------------------------------------------------------

  // From the moment the pointer is in use: eighth notes picked out of the chord, soft
  // enough to feel rather than follow. It thins out for the ending.
  const pluckBus = ctx.createBiquadFilter()
  pluckBus.type = 'lowpass'
  pluckBus.frequency.value = 2600
  const echo = ctx.createDelay(1)
  echo.delayTime.value = 0.375
  const again = ctx.createGain()
  again.gain.value = 0.3
  pluckBus.connect(echo).connect(again).connect(echo)
  send(pluckBus, 0.75, 0.3)
  send(echo, 0.4, 0.3)
  const pattern = [0, 2, 1, 3, 2, 4, 1, 3]
  for (let step = 0; ; step++) {
    const t = 5.5 + step * 0.25
    if (t >= 26.5) break
    const chord = [...CHORDS].reverse().find(c => t >= c.from)
    const midi = chord.notes[pattern[step % 8] % chord.notes.length] + 12
    const strength = (step % 2 === 0 ? 1 : 0.5) * (t < 6.5 ? (t - 5.5) : 1) * (t > 24.5 ? Math.max(0, (26.5 - t) / 2) : 1)
    if (strength <= 0.02) continue
    const osc = ctx.createOscillator()
    osc.type = 'triangle'
    osc.frequency.value = hz(midi)
    const level = quiet()
    level.gain.setValueAtTime(0, t)
    level.gain.linearRampToValueAtTime(0.046 * strength, t + 0.006)
    level.gain.exponentialRampToValueAtTime(0.0002, t + 0.34)
    osc.connect(level)
    panned(level, step % 2 ? 0.3 : -0.3).connect(pluckBus)
    osc.start(t)
    osc.stop(t + 0.36)
  }

  // --- Effects -------------------------------------------------------------------------

  /// Moving air: band-passed noise that swells and passes, its pitch and place sliding.
  function air(from, length, { low = 300, high = 1600, gain = 0.2, pan = [0, 0], peak = 0.5, q = 0.9 } = {}) {
    const src = ctx.createBufferSource()
    src.buffer = noise
    src.loop = true
    const band = ctx.createBiquadFilter()
    band.type = 'bandpass'
    band.Q.value = q
    band.frequency.setValueAtTime(low, from)
    band.frequency.exponentialRampToValueAtTime(high, from + length * peak)
    band.frequency.exponentialRampToValueAtTime(low * 0.8, from + length)
    const level = quiet()
    level.gain.setValueAtTime(0, from)
    level.gain.linearRampToValueAtTime(gain, from + length * peak)
    level.gain.linearRampToValueAtTime(0, from + length)
    const place = ctx.createStereoPanner()
    place.pan.setValueAtTime(pan[0], from)
    place.pan.linearRampToValueAtTime(pan[1], from + length)
    src.connect(band).connect(level).connect(place)
    send(place, 1, 0.35)
    src.start(from, random() * 2)
    src.stop(from + length + 0.05)
  }

  /// A short tone that falls or rises: used for thumps and blips.
  function tone(at, { from, to = from, length, gain, type = 'sine', attack = 0.004, dry = 1, space = 0.2, pan = 0 }) {
    const osc = ctx.createOscillator()
    osc.type = type
    osc.frequency.setValueAtTime(from, at)
    if (to !== from) osc.frequency.exponentialRampToValueAtTime(to, at + length)
    const level = quiet()
    level.gain.setValueAtTime(0, at)
    level.gain.linearRampToValueAtTime(gain, at + attack)
    level.gain.exponentialRampToValueAtTime(0.0002, at + length)
    osc.connect(level)
    send(panned(level, pan), dry, space)
    osc.start(at)
    osc.stop(at + length + 0.02)
  }

  /// A burst of filtered noise: the grain in a click or a knock.
  function grit(at, { centre, q = 1.2, length, gain, pan = 0, space = 0.15 }) {
    const src = ctx.createBufferSource()
    src.buffer = noise
    const band = ctx.createBiquadFilter()
    band.type = 'bandpass'
    band.frequency.value = centre
    band.Q.value = q
    const level = quiet()
    level.gain.setValueAtTime(0, at)
    level.gain.linearRampToValueAtTime(gain, at + 0.0015)
    level.gain.exponentialRampToValueAtTime(0.0002, at + length)
    src.connect(band).connect(level)
    send(panned(level, pan), 1, space)
    src.start(at, random() * 3)
    src.stop(at + length + 0.02)
  }

  /// A fingertip on the case: a soft knock on hollow plastic.
  function tap(at, second) {
    const pitch = second ? 1.06 : 1
    grit(at, { centre: 2600, q: 0.8, length: 0.018, gain: 0.26, pan: 0.2 })
    tone(at, { from: 470 * pitch, to: 400 * pitch, length: 0.085, gain: 0.3, pan: 0.2, space: 0.25 })
    tone(at, { from: 1180 * pitch, to: 1100 * pitch, length: 0.03, gain: 0.1, pan: 0.2, space: 0.2 })
    tone(at, { from: 190, to: 150, length: 0.06, gain: 0.16, pan: 0.2, space: 0.1 })
  }

  /// What the Mac makes of it: a small bright click.
  function click(at) {
    tone(at, { from: 1760, length: 0.05, gain: 0.12, space: 0.5, pan: -0.25 })
    tone(at + 0.004, { from: 2637, length: 0.03, gain: 0.06, space: 0.5, pan: -0.25 })
    grit(at, { centre: 5200, q: 1.5, length: 0.012, gain: 0.08, pan: -0.25 })
  }

  // The lid lifts: a small release, and the air it lets out.
  grit(CUE.lidOpens + 0.03, { centre: 3200, q: 1, length: 0.022, gain: 0.16 })
  tone(CUE.lidOpens + 0.03, { from: 180, to: 120, length: 0.09, gain: 0.2, space: 0.3 })
  air(CUE.lidOpens, 0.85, { low: 500, high: 3200, gain: 0.07, peak: 0.35 })
  // The light comes on.
  tone(CUE.lightOn, { from: 1318.5, length: 0.5, gain: 0.035, attack: 0.02, dry: 0.4, space: 1 })
  tone(CUE.lightOn + 0.09, { from: 1975.5, length: 0.6, gain: 0.025, attack: 0.02, dry: 0.4, space: 1 })
  // The screen wakes.
  tone(CUE.screenWakes, { from: 110, to: 164.8, length: 1.3, gain: 0.1, attack: 0.5, space: 0.4 })
  air(CUE.screenWakes, 1.5, { low: 700, high: 4200, gain: 0.05, peak: 0.6, pan: [-0.3, -0.1] })
  // The camera pulls back over the case.
  air(4.5, 1.4, { low: 260, high: 1100, gain: 0.11, peak: 0.45, pan: [0.3, -0.2] })
  // Round the case: one long pass of air, left to right and back.
  air(CUE.orbit[0] - 0.1, 1.5, { low: 240, high: 1900, gain: 0.2, peak: 0.6, pan: [-0.2, 0.75] })
  air(CUE.orbit[0] + 1.1, 1.6, { low: 300, high: 2100, gain: 0.2, peak: 0.45, pan: [0.75, -0.6] })
  tone(CUE.orbit[0] + 0.1, { from: 55, to: 82, length: 2.3, gain: 0.13, attack: 1.2, space: 0.2 })
  // The taps and the clicks they make.
  TAPS.forEach((at, i) => tap(at, i % 2 === 1))
  CLICKS.forEach(at => click(at + 0.012))
  // The panel slides in.
  air(CLICKS[0] + 0.03, 0.5, { low: 900, high: 3600, gain: 0.06, peak: 0.3, pan: [0.1, -0.4], q: 1.4 })
  // The slider knob runs to where it was clicked.
  tone(CLICKS[1] + 0.03, { from: 587.3, to: 880, length: 0.24, gain: 0.05, attack: 0.02, space: 0.6, pan: -0.25 })
  // In toward the screen, and away from it again.
  air(17.3, 2.3, { low: 220, high: 900, gain: 0.1, peak: 0.55, pan: [0.3, -0.3] })
  air(23.4, 1.9, { low: 240, high: 1300, gain: 0.13, peak: 0.5, pan: [-0.4, 0.2] })
  // The lid shuts: it lands 0.42 s after it starts to fall.
  const shut = CUE.lidShuts + 0.42
  air(CUE.lidShuts, 0.42, { low: 1800, high: 500, gain: 0.04, peak: 0.8 })
  grit(shut, { centre: 2200, q: 0.9, length: 0.03, gain: 0.3 })
  tone(shut, { from: 150, to: 82, length: 0.16, gain: 0.34, space: 0.35 })
  tone(shut + 0.002, { from: 620, to: 560, length: 0.05, gain: 0.1, space: 0.3 })
  // The name: four notes rising out of the last chord, left to ring.
  const chime = [65, 72, 77, 81]
  chime.forEach((midi, i) => {
    const at = CUE.endCard + i * 0.11
    tone(at, { from: hz(midi), length: 2.6, gain: 0.075, attack: 0.008, dry: 0.7, space: 1, pan: (i - 1.5) * 0.18 })
    tone(at, { from: hz(midi) * 2.003, length: 1.1, gain: 0.02, attack: 0.008, dry: 0.5, space: 1, pan: (i - 1.5) * 0.18 })
  })
  tone(CUE.endCard, { from: 43.65, to: 43.65, length: 2.6, gain: 0.2, attack: 0.35, space: 0.1 })

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
