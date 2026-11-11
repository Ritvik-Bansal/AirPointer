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

