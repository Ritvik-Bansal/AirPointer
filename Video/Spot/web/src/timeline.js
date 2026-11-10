// The storyboard, as numbers.
//
// Thirty seconds, five shots, one camera that never cuts: each shot ends on the move that
// begins the next, so the film plays as a single take.
//
//   1  Reveal   0.0 -  5.5   The closed case, alone. The lid opens; behind it a screen wakes.
//   2  Aim      5.5 - 12.5   Over the case to the Mac. The case turns, the cursor goes with it.
//   3  Tap     12.5 - 19.0   The camera circles the case and lands beside it. Two taps: a click.
//   4  Tune    19.0 - 25.0   In close on the app. A click on Speed, and the curve answers.
//   5  Close   25.0 - 30.0   Back to the case. The lid shuts. The name.
//
// Everything that happens is a pure function of time, so any frame can be drawn on its own
// and the sound can be laid against the same cues.

import { CASE, SCREEN, UI, screenPoint } from './layout.js'

export const FPS = 30
export const DURATION = 30
export const FRAMES = FPS * DURATION

export const SHOTS = [
  { name: 'Reveal', from: 0.0, to: 5.5 },
  { name: 'Aim', from: 5.5, to: 12.5 },
  { name: 'Tap', from: 12.5, to: 19.0 },
  { name: 'Tune', from: 19.0, to: 25.0 },
  { name: 'Close', from: 25.0, to: 30.0 },
]

/// The moments everything else is hung on.
export const CUE = {
  lidOpens: 2.45,
  lightOn: 3.0,
  screenWakes: 4.1,
  orbit: [12.5, 15.0],
  /// The click that opens the Feel panel: two taps on the side of the case.
  click1: [15.45, 15.72],
  /// The click on the Speed slider.
  click2: [20.3, 20.57],
  lidShuts: 25.9,
  endCard: 26.7,
}
export const TAPS = [...CUE.click1, ...CUE.click2]
/// A click is what the Mac receives when the second tap of a pair lands.
export const CLICKS = [CUE.click1[1], CUE.click2[1]]

