# The AirPointer spot

A 30-second product film: one unbroken take around an AirPods Pro case and a Mac. It is a Three.js scene, drawn frame by frame in headless Chrome and encoded with ffmpeg. The sound is synthesised from the same timeline.

```sh
Video/Spot/render.sh          # the film, into Video/out
Video/Spot/preview.sh         # watch and scrub it in the browser, without rendering
```

`render.sh` writes three files to `Video/out`:

| File | What it is |
| --- | --- |
| `airpointer-spot.mp4` | The film: 1920x1080, 30 fps, H.264, stereo sound. |
| `airpointer-spot-web.mp4` | The same under 10 MB, the most GitHub accepts as an attachment on a free account. |
| `airpointer-spot-poster.png` | The end card, for a thumbnail. |

Options: `--4k` for 3840x2160, `--draft` for a quick half-size look, `--samples 192` for more renders averaged into each frame, `--address "github.com/you/AirPointer"` for the line on the end card (`--address ""` leaves it off).

Needs Node 20 or later, Google Chrome and ffmpeg (`brew install node ffmpeg`), on a Mac: the type is the system's own SF faces, read from `/System/Library/Fonts`. A render takes about eight minutes on an M-series Mac with memory to spare, and a good deal longer on one that is short of it (many apps open, deep in swap). Frames are drawn to disk before they are encoded, so a render that is stopped, or that fails part-way, can simply be started again and carries on from where it was. The first run downloads Three.js and a browser driver into `~/Library/Caches/AirPointer/Spot`; nothing heavy is written into this folder.

## The storyboard

Five shots, one camera, no cuts. Each shot ends on the move that begins the next.

| Shot | Time | What happens | How it hands over |
| --- | --- | --- | --- |
| 1 Reveal | 0:00 to 0:05.5 | The closed case, alone in the dark, the first words already beside it. A band of light crosses its face. The lid opens, the status light comes on. *Your AirPods case is a pointer.* | The Mac's screen wakes behind the case; the camera rises and the focus pulls from the case to the screen. |
| 2 Aim | 0:05.5 to 0:12.5 | Over the case to the Mac. The case turns and tilts; the cursor goes where it is aimed, and the dot on the app's small screen follows. *Aim it.* | The cursor comes to rest on the Feel pill. The focus returns to the case and the camera starts round it. |
| 3 Tap | 0:12.5 to 0:19.0 | The camera circles the case once: past the lanyard plate, low behind the hinge, and round to the front. Two taps land on the back; from each, a ring of light comes round the side and across the front. On the Mac, in the same frame and in focus, the click: the Feel pill takes it and the panel slides in. *Tap it.* | The focus goes to the screen, and the camera goes after it. |
| 4 Tune | 0:19.0 to 0:25.0 | The app's whole window. The cursor reaches the Speed slider; two taps (each rings on the app's dot screen and behind its little case), and the knob runs to the click: 1.0× becomes 2.0×, and the response curve lifts. *Tune it.* | The camera backs out the way it came, and the case comes back into the picture. |
| 5 Close | 0:25.0 to 0:30.0 | The camera rises over the case. The lid shuts. The name, what it is, where it lives. | The last frame is the end card, held. |

The storyboard is `web/src/timeline.js`: every time above, the camera's path, the cursor's path and the words are there as plain numbers, and everything else is drawn from them.

## How it is made

- **The model** (`web/src/model`). The case and the AirPods are written as solids (distance fields) in millimetres and meshed by `tools/bake.mjs`. The overall sizes are Apple's published ones: the case 62.2 x 47.2 x 21.8 mm, an AirPod 30.9 x 19.2 x 27.0 mm. The rest was measured off photographs of a real AirPods Pro 3 case and scaled by those: the lid line, the rounder bottom corners, the hinge plate and the print under it, the lanyard plate, the port and the holes either side of it, the thumb scoop, the hidden light, the shape of the wells and how the AirPods sit in them. Measured off photographs means close, not exact. The app's window shows this model too: `tools/export-swift.mjs` meshes it for SceneKit and writes it into the app's source as `App/UI/CaseModelData.swift`.
- **The picture** (`web/src/renderer.js`). Each frame is the average of 96 renders, and up to twice that where the camera is moving fast. Between them the camera is moved across the opening of its lens, the clock across the time the shutter is open, and the key light across its own width. That is what gives real depth of field, motion blur and soft shadows, rather than a blur laid on afterward.
- **The screen** (`web/src/screen.js`). The AirPointer window is redrawn from the app's own source so that it can be driven frame by frame: the same sizes, colours, type and wording as the SwiftUI views, the dot screen from the same formula as `DotScreen.swift`, the response curve from the same maths as PointerKit's `RateShaper`, the click ring from `ClickHUD.swift`. The small case in the window is the same 3D model, drawn live. The desktop around the window is generic.
- **The sound** (`web/src/sound.js`). A pad, a quiet pulse, and one effect per event in the picture, each placed on the cue the picture is drawn from. Nothing is recorded or sampled.

## What is staged

It is a commercial, not a recording, and a few things are simplified:

- The case hangs in the air. No hand is shown.
- A tap is drawn as a ring of light crossing the plastic, with a small knock of the case. A real case shows nothing when it is tapped; the ring is the film's way of making a tap visible, the same way the app's own window marks one. The taps land on the back, where the app asks for them; the camera is in front, so what is seen is the ring coming round.
- The cursor is drawn exactly where the case is aimed. The app itself works from how fast the case is turning (like a mouse), with a response curve, so in real use the two are related but not locked.
- The cursor on the Mac is drawn two and a half times its normal size, so that it can be seen at the size a film is watched.
- The window on the Mac is a redraw of the app, as above, not a capture of it.
- There is no voice. The only voices installed on this Mac are the compact system ones, which sound synthetic, and the words are on screen.

## Changing it

| To change | Look in |
| --- | --- |
| Timing, the camera, the cursor's path, the words | `web/src/timeline.js` |
| How the words are set | `web/src/titles.js` |
| The line on the end card | `--address`, or the default in `web/src/boot.js` |
| The lights | `web/src/studio.js` (the studio), `web/src/set.js` (the desk and the Mac) |
| The grade, grain and bloom | the finishing pass at the foot of `web/src/renderer.js` |
| The case and the AirPods | `web/src/model/airpods.js`; `render.sh` re-bakes when it changes, and `node tools/export-swift.mjs` gives the app the same change |
| The sound | `web/src/sound.js` |
