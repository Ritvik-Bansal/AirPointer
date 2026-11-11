# The AirPointer film

(This is the longer explainer. The 30-second spot is a separate film with its own page: `Spot/README.md`.)

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

## Putting your clips in

Everything the film takes from outside goes in `Video/footage` (not kept in git):

```
Video/footage/A.mov        clip A  (.mov, .mp4 or .m4v)
Video/footage/B.mov        clip B
Video/footage/music.m4a    optional music (.m4a, .mp3, .wav, .aiff or .flac)
Video/footage/cuts.json    optional, see below
```

Then run `Video/render.sh`. Each clip fills a 1620x912 frame for 6.5 seconds. It is cropped to fill, so film in landscape. Any size and frame rate will do; a clip filmed sideways is turned upright, and an HDR clip is converted to the ordinary range the way QuickTime shows it on an ordinary display.

`cuts.json` says where in each file to start, in seconds, and whether a clip keeps its own sound:

```json
{ "A": 3.0, "B": { "in": 7.5, "sound": true }, "music": { "in": 12 } }
```

Without it, each clip and the music start at their beginning and the clips are silent. If a clip is shorter than its slot, its last frame holds.

**Sound.** With no music file and no clip set to keep its sound, the film has no sound track at all, and is made to be understood that way: it is how GitHub and most portfolio pages play a video. With music, the mix is automatic: the music is brought to -16 LUFS, fades in over 1.2 s and out over the last 3 s, and steps back under any clip that keeps its sound.

## Filming the two clips

Both clips, before you start:

- **Landscape, and still.** Prop the phone on something or use a tripod. A locked-off shot is what makes it look edited rather than grabbed.
- **Turn off HDR video** on an iPhone: Settings → Camera → Record Video → HDR Video. HDR clips are converted, but that path has only been tested with a synthetic clip.
- **1080p or 4K, 60 fps if the phone offers it.** 30 fps is fine.
- **Lock exposure on the Mac's screen.** In the Camera app, touch and hold on the screen until AE/AF Lock appears, then drag the sun down a little. Otherwise the screen burns out white.
- **Light the hand.** A lamp on the hand's side and the Mac at about two thirds brightness lets the camera see both.
- **Make the cursor big.** System Settings → Accessibility → Display → Pointer size, about halfway. A normal cursor is nearly invisible on phone footage.
- **A plain, dark screen.** A solid dark wallpaper, Dock visible, nothing private open, and a Focus mode on so no notification arrives.
- **Tap the back of the case**, lid open, AirPods in.
- **Film far more than is needed**: 20 seconds or so per clip, repeating the action three or four times with a two-second pause between tries. The film uses the best 6.5 seconds.

**Clip A, "Over the shoulder".** It follows "Aim it." and proves the cursor follows the case.
Camera behind and a little above your shoulder, or beside you, so that your hand with the case sits in the lower part of the frame and the screen fills the rest. Focus on the screen.
Hold still for two seconds. Move the cursor slowly all the way left, then right. Pause. Up, then down. Pause. One slow circle. Rest. One direction at a time, a second or two each; do not click.

**Clip B, "A real click".** It follows "Tap it." and proves a tap clicks.
Closer on the screen, with your hand and the case in a lower corner so the tapping finger can be seen.
Pick something in the Dock whose window is large and comes up at once (open the app beforehand and close its window, so it does not have to launch). Start with the cursor a little way off. Bring it onto the icon, hold for a beat, tap twice, and keep still while the window opens. Repeat a few times, closing the window in between.
If the room is quiet, the two taps can be heard in the finished film: set `"sound": true` for B.

Optional: one unbroken take of 30 to 60 seconds of ordinary use (move, click, right-click, open something). It is not in this film, but it is what a longer cut for the portfolio would be made from.

## Finishing it

1. Film clips A and B, put them in `Video/footage`, and run `Video/render.sh`. Choose the best 6.5 seconds of each with `cuts.json`.
2. Confirm the order of the chapters, or change it. It was chosen while you were away: show it, prove it with a clip, twice, then explain. The order is the `At` enum at the top of `Sources/film/Film.swift`.
3. Decide on sound. The film works silent. For music, pick a track you are licensed to publish with, save it as `Video/footage/music.m4a`, and render again.
4. Create the repository. The end card says `github.com/Ritvik-Bansal/AirPointer`; if the repository is named anything else, change that one line in `Sources/film/main.swift` and render again.
5. Put `out/airpointer-web.mp4` at the top of the repository's README by dragging it into the README editor on github.com, which turns it into a player. Use `out/airpointer.mp4` and the poster on the portfolio.

## Changing it

| To change | Look in |
| --- | --- |
| The order and length of chapters | `enum At` in `Film.swift` |
| Any words on screen | `text(_:)` in `Film.swift`; the diagrams' labels in `Diagrams.swift` |
| Which stretch of the recording plays | the `Take.cut` lines in `Film.init`. After a render, `~/Library/Caches/AirPointer/Film/release/film probe <phase> <offset> <seconds>` lists what a stretch holds |
| Colours, type sizes, margin | `Look.swift` |
| How things move | `Motion.swift` |
| The case itself | `App/UI/CaseView.swift`, which the app shares |

The rules the film keeps (flat colour, no gradients, glows or shadows, nothing set under 32 px, the case never faded) are written down in `DESIGN.md` at the project root.
