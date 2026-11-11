# AirPointer

Turns an AirPods Pro case into a pointer for the Mac. Hold the case like a small remote, aim it, and the cursor follows. Tap the back of the case to click.

It is a menu-bar app. The window is for setting it up and tuning how it feels.

## Before it will work

Three things have to be true, and the app's Setup tab checks each one:

1. **Automatic Ear Detection is off** for the AirPods (System Settings → Bluetooth → ⓘ beside the AirPods). With it on, the AirPods stop sending motion as soon as they are out of your ears. The cost: sound no longer pauses by itself when you take an AirPod out.
2. **Both AirPods are in the case and the lid is open.** The lid is the switch. Closing it puts the pointer to sleep about five seconds later; opening it wakes it.
3. **Two permissions are granted:** Motion & Fitness (to read the AirPods) and Accessibility (to move the cursor and click).

## Using it

| Do this | Get this |
| --- | --- |
| Aim the case | The cursor moves |
| Tap the back twice | Click |
| Tap once | Right-click, after a short pause |
| Tap three times | Double-click (or press-and-hold for dragging, if you choose that in Taps) |
| Close the lid | Pointer sleeps |
| ⌃⌥⌘P | Turn the pointer on or off from anywhere |
| ⌃⌥⌘C | Teach it your grip again |

Tap the back or a side. Two taps on the *front* of an open case is Apple's pairing gesture.

The trackpad keeps working alongside it; whichever moved last carries on from where the cursor is.

## Build and install

Needs Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
scripts/install.sh    # build, copy to /Applications, open
scripts/build.sh      # build only; prints the app's path
scripts/test.sh       # engine tests, including replays of recorded sessions
```

Build products go to `~/Library/Caches/AirPointer`, not into this folder.

The app is signed with the local Apple Development certificate. macOS ties the two permissions to that signature, so they survive rebuilds.

## How it works

The AirPods send motion at 50 samples a second from one earbud. The case itself sends nothing; its sensors are not readable from a Mac.

```
AirPods ──▶ MotionSource ──▶ PointerEngine ──▶ CursorDriver ──▶ the real cursor
                              │
                              ├─ AxisMapper    which way is left/right and up/down for this grip
                              ├─ RateShaper    steadies small motion, speeds up flicks
                              ├─ TapDetector   finds finger taps as one-sample jolts
                              ├─ TapSequencer  turns taps into clicks
                              └─ Playout       turns bursty samples into smooth frames
```

- **Direction comes from gravity plus one calibration.** Turning about "up" is left/right. A single tilt-up gesture teaches which way the case points, which fixes up/down. No compass is involved, so nothing drifts.
- **Samples arrive in bursts** (two together, then a gap of up to 90 ms). The cursor follows a running target and is dead-reckoned through the gaps, so it stays smooth.
- **A tap knocks the case several degrees.** When one is found, the cursor is put back where it was aimed and held there until the hand recovers. The click lands where you were pointing, not where the tap threw it.
- **A knock is not a tap.** A jolt only starts a gesture if the hand had stopped first and the case is actually being held (a hand always trembles a little; a case on a table does not). Picking the case up, re-gripping it and putting it down all produce jolts, and they are refused. The Signal tab's chart shows every jolt either way.
- **The pointer waits about a second after the AirPods wake** before going live, long enough to notice if they are going into ears rather than sitting in the case. If they look worn, it pauses and says so.
- **The app opts out of App Nap while motion is arriving.** A menu-bar app with no window is otherwise throttled, and the cursor would stall.

`Packages/PointerKit` is the engine: no AppKit, no threads, no clock of its own, so a recording replays to the same result every time. `App/` is everything that touches the system.

## Tuning from a recording

The Signal tab records the raw stream to a text file. Replay it to see what the engine makes of it:

```sh
scripts/replay.sh "path/to/trace-….trace" --sensitivity 0.6
```

Add `--whole` to run the entire recording through one engine, the way the app does, and list every jolt with what was made of it.

The two recordings the defaults were tuned on are in `Packages/PointerKit/Tests/PointerKitTests/Fixtures`, and the tests assert the results on them. On the case recording, replayed end to end: all 10 single taps and all 6 double-taps click, nothing else does, and the dozen knocks from picking the case up and putting it away are refused.

## What is and is not verified

- Verified on recordings of real use: axis mapping, tap detection, click timing, cursor steadiness through taps, and that handling the case between taps does not click.
- Known trade-off: on the loose-AirPod recording, 4 of the 6 double-taps register. The other two came while the hand was still turning, and the rule that refuses handling knocks refuses them too. With the case, all of them register.
- Known limit: one knock on a case held perfectly still is, to the sensors, a tap. It becomes a right-click.
- Verified by running the app: the interface in light and dark, driven by a replayed recording.
- Used for real by its author, case in hand, moving the real cursor, with AirPods Pro 3 on macOS 27 (November 2026): reported to work well. That is first use by one person, not a long trial; the speed and steadiness defaults are still a starting point.
- A guess, not a measurement: which way the *left* AirPod sits when it is the one sending. Every recording so far came from the right one. If up/down feel wrong, teach the grip again.
- Unknown: how long docked AirPods keep streaming before they sleep on their own. The longest test was about three minutes.

## The films

`Video/` holds two, both made entirely by code.

- **The spot** (`Video/Spot`): 30 seconds, one unbroken take in a dark studio around the case and a Mac, with sound. A Three.js scene rendered frame by frame, with a 3D model of the AirPods Pro 3 case built from its published dimensions and from photographs. `Video/Spot/render.sh` renders it, `Video/Spot/preview.sh` opens it to scrub in the browser, and `Video/Spot/README.md` has the storyboard.
- **The explainer** (`Video`): 76 seconds on how the pointer works, flat and diagrammatic, drawn from the app's own case and from the recordings above replayed through the engine, with two slots for filmed clips. `Video/render.sh` renders it; `Video/README.md` says how, and how the clips go in.

## Launch arguments for development

```
-rehearse <trace>        play a recording in place of the AirPods; the real cursor is untouched
-appearance light|dark   force the look
-showWindow YES          open the main window at launch even after setup
-background YES          open windows without coming to the front
-popoverWindow YES       show the menu-bar panel in an ordinary window
```

Saved choices can be overridden the same way, for example `-hasFinishedSetup YES -openTab feel`.
