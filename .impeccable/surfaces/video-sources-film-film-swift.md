---
version: 1
slug: "video-sources-film-film-swift"
primary_target: "Video/Sources/film/Film.swift"
related_targets: ["Video/Sources/film/Stage.swift","Video/Sources/film/Diagrams.swift","Video/Sources/film/Footage.swift","Video/Sources/film/Look.swift","Video/Sources/film/Motion.swift"]
---

# The film

**Scope:** the 76-second film about AirPointer that goes at the top of the GitHub README and on the user's portfolio. It is drawn frame by frame by `Video/Sources/film` and written out by `Video/render.sh`. Two stretches of it are the user's own phone footage.

**Visitor mode:** Read. Someone who has never seen the pointer should come away knowing what it is, having seen it work, and understanding how it can work at all.

**Audience and job:** a visitor to the repository or the portfolio, most often watching without sound in an embedded player well under half the film's size, and often leaving in the first half minute. The first half therefore stands alone as a demonstration, and nothing is set smaller than 32 px.

**Task and important states:** see what it is (the title card, which is also the first frame and so the player's thumbnail); see it aimed and tapped, each followed by a filmed clip proving it; then how it works (the sensors are in the AirPods, gravity gives the axes, a tap is one reading out of line), that it was tested on a recorded session, and how to start. The last frame is the end card, held, because that is what a player is left showing.

**Constraints:** set by the user: professional, minimal, informative, not childish, not sloppy, and no gradients. Added by the build: no glows and no shadows, the only shading is the light on the 3D case; everything measured is shown on a dot-matrix display; all motion on screen that claims to be real is a recording replayed through the app's own engine.

**Chosen direction:** the app's own world, at night and flat: one room in two tones, white type, one sky-blue, the case as the only lit object. The case is on screen whenever the film is drawing and moves between its places rather than being cut or faded.

**Memorable moment:** the signal chapter. A small case in the corner replays a stretch of the recording while a dot-matrix display fills with what the engine read from it: two taps stand up as single columns and are counted; the knock from shifting the case is refused, with the band above it lit to show the hand was moving.

**Unresolved:** the order of the chapters (show, prove with a clip, twice, then explain) was chosen by the builder while the user was away; it is theirs to confirm or change. The two clips are placeholders until the user films them. There is no sound yet. The address on the end card is not confirmed until the repository exists.
