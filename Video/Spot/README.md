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

