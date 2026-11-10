# The AirPointer film

A 76-second film about AirPointer, for the top of the GitHub README and for the portfolio. It is drawn frame by frame by the Swift program in `Sources/film`, from the app's own 3D case and from recordings of a real hand replayed through the app's own engine, and written out with ffmpeg.

```sh
Video/render.sh          # builds the tool and renders the film into Video/out
Video/render.sh --4k     # the same at 3840x2160
```

It writes three files:

| File | What it is |
| --- | --- |
| `out/airpointer.mp4` | The film: 1920x1080, 60 fps, H.264. |
| `out/airpointer-web.mp4` | The same film under 10 MB, the most GitHub accepts as an attachment on a free account. |
| `out/airpointer-poster.png` | The title card with the lid open, for a thumbnail. |

While a filmed clip is missing, its place shows a card saying what belongs there, and the three files are named `airpointer-base…` instead, so a cut with placeholders cannot be mistaken for the finished one.

Needs Xcode's command-line tools and ffmpeg (`brew install ffmpeg`). A render takes under a minute.

## What is in it

| From | Chapter | On screen |
| --- | --- | --- |
| 0:00 | Title | AirPointer. Your AirPods case, as a pointer for the Mac. The lid opens. |
| 0:04 | Aim it. | The case is turned and tilted; the cursor follows on a dot-matrix screen. Real recorded motion. |
| 0:12 | **Clip A** | Your footage: steering the cursor. |
| 0:18 | Tap it. | Two taps click, one tap right-clicks. Real recorded taps. |
| 0:26 | **Clip B** | Your footage: a real click. |
| 0:32 | The sensors are in the AirPods. | Two callouts on the case. |
| 0:39 | Gravity says which way is up. | The two rotations the pointer reads, demonstrated. |
| 0:48 | A tap is one reading out of line. | The real signal on a dot-matrix display: two taps counted, a knock refused. |
| 0:57 | Tuned on recordings of a real hand. | 10 / 10, 6 / 6, 0 / 12. |
| 1:03 | To start | Three steps. |
| 1:10 | End card | The name, the repository, what it was tested with. Held to the last frame. |

The first frame is the complete title card and the last is the end card, because those are what a player shows before and after it plays.

