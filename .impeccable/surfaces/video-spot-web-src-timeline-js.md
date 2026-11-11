---
version: 1
slug: "video-spot-web-src-timeline-js"
primary_target: "Video/Spot/web/src/timeline.js"
related_targets: ["Video/Spot/web/src/film.js","Video/Spot/web/src/studio.js","Video/Spot/web/src/set.js","Video/Spot/web/src/screen.js","Video/Spot/web/src/titles.js","Video/Spot/web/src/sound.js","Video/Spot/web/src/renderer.js","Video/Spot/web/src/model/airpods.js"]
---

# The spot

**Scope:** a 30-second product film for AirPointer, with sound, for the top of the GitHub README and the user's portfolio. It is a Three.js scene drawn frame by frame in headless Chrome by `Video/Spot/render.sh`. It sits beside the longer, flat explainer film (`Video/Sources/film`) and is deliberately its opposite.

**Visitor mode:** Persuade. Someone who has never heard of the pointer should, in half a minute, want it: see that it is their AirPods case, that aiming it moves the cursor, that tapping it clicks, and that the app behind it is well made.

**Audience and job:** a visitor to the repository or the portfolio, on an embedded player, often muted. Every shot therefore says its one thing in the picture and in at most two lines of type; the sound adds to it but nothing depends on it. The first frame and the last are what the player shows when it is not playing.

**Task and important states:** five shots, one camera, no cuts. Reveal (the closed case; the lid opens), Aim (the cursor goes where the case points), Tap (two taps, and the click they make, in one frame), Tune (the app's own window: a click on Speed and the curve answers), Close (the lid shuts; the name). The storyboard, with every time, is `timeline.js`.

**Constraints:** set by the user's brief: an ultra-premium tech commercial, deep cinematic tones with vivid light, sharp depth of field, smooth continuous transitions, a strict five-shot storyboard with seamless hand-overs, one grade throughout, synthesised sound tied to the picture, a more accurate 3D model of the AirPods, and a pure Three.js build that compiles to a video file. Carried over from the user's earlier word on the explainer film: nothing childish, nothing sloppy, and no gradients, kept here as far as lit photography allows (no gradient fills, tints or titles; tone comes only from light, focus and the lens). Added by the build: the app's window on the Mac shows only what the app really does.

**Chosen direction:** a black studio and one white glossy object. Blue, amber and the screen's own glow, with blue leading. Real depth of field and motion blur from averaging many renders per frame. Type in the app's own rounded face, one block at the bottom-left margin.

**Memorable moment:** the landing of the third shot. The camera comes off its turn round the case and holds the case and the Mac together, both in focus: two rings of light come round the case, and in the same frame the Feel pill takes the click and the panel slides in.

**Unresolved:** the address on the end card is not confirmed until the repository exists (`render.sh --address`). The sound was built and checked by measurement, not by ear, and should be listened to by the user. There is no voice.
