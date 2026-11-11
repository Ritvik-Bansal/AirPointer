---
name: AirPointer
description: A native Mac pointer driven by the AirPods case, shown as a small room with a dot screen on the wall and the case on the floor.
colors:
  stage: "#F4F7FA"
  stage-floor: "#E4EBF2"
  panel: "#FFFFFF"
  ink: "#1F2A36"
  ink-soft: "#566575"
  hairline: "#D3DCE5"
  keyline: "#2FA8E6"
  action: "#0B74B4"
  on-action: "#FFFFFF"
  warn: "#A85A07"
  dot-off: "#CBD5DE"
  stage-dark: "#0E151D"
  stage-floor-dark: "#090E14"
  panel-dark: "#16202B"
  ink-dark: "#EAF2F8"
  ink-soft-dark: "#9FB2C4"
  hairline-dark: "#27343F"
  keyline-dark: "#48B9F5"
  action-dark: "#48B9F5"
  on-action-dark: "#06202F"
  warn-dark: "#F5B041"
  dot-off-dark: "#2B3947"
typography:
  display:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui, sans-serif"
    fontSize: "30px"
    fontWeight: 700
  title:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui, sans-serif"
    fontSize: "20px"
    fontWeight: 700
  pill:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 600
  pill-small:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 600
  heading:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "14px"
    fontWeight: 600
  body:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "14px"
    fontWeight: 400
  caption:
    fontFamily: "SF Pro, system-ui, sans-serif"
    fontSize: "12.5px"
    fontWeight: 400
  figure:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 500
    fontFeature: "tnum"
rounded:
  screen: "20px"
  panel: "22px"
  pill: "9999px"
spacing:
  hair: "4px"
  tight: "8px"
  gap: "12px"
  row: "15px"
  window-edge: "18px"
  panel-inset: "22px"
components:
  button-primary:
    backgroundColor: "{colors.action}"
    textColor: "{colors.on-action}"
    typography: "{typography.pill}"
    rounded: "{rounded.pill}"
    padding: "0 20px"
    height: "38px"
  button-secondary:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.action}"
    typography: "{typography.pill}"
    rounded: "{rounded.pill}"
    padding: "0 20px"
    height: "38px"
  button-quiet:
    textColor: "{colors.ink-soft}"
    typography: "{typography.pill}"
    rounded: "{rounded.pill}"
    padding: "0 20px"
    height: "38px"
  button-quiet-hover:
    textColor: "{colors.ink}"
  button-small:
    typography: "{typography.pill-small}"
    rounded: "{rounded.pill}"
    padding: "0 14px"
    height: "30px"
  button-large:
    typography: "{typography.pill}"
    rounded: "{rounded.pill}"
    padding: "0 28px"
    height: "48px"
  power-switch-on:
    backgroundColor: "{colors.action}"
    textColor: "{colors.on-action}"
    typography: "{typography.pill}"
    rounded: "{rounded.pill}"
    padding: "4px"
    height: "32px"
  power-switch-off:
    backgroundColor: "{colors.hairline}"
    textColor: "{colors.ink-soft}"
    typography: "{typography.pill}"
    rounded: "{rounded.pill}"
    padding: "4px"
    height: "32px"
  panel:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.ink}"
    rounded: "{rounded.panel}"
    padding: "22px"
    width: "448px"
  dot-screen:
    backgroundColor: "{colors.panel}"
    rounded: "{rounded.screen}"
    padding: "14px"
    width: "360px"
---

# Design System: AirPointer

Recorded from the built app (SwiftUI, AppKit, SceneKit; macOS 26 and later), not from a plan. The tokens live in `App/UI/Theme.swift` as `Theme` and `Typo`. There is no CSS: every length in this file is in points, and the `px` unit in the frontmatter stands for points only because the token schema has no point unit. Every colour is an appearance pair; the `-dark` keys are the same token in Dark Mode.

Reviewed in captures: the stage while pointing and while asleep, the Feel, Taps, Setup and Signal panels, the first step of first-run setup and the menu-bar panel, in a window that was not key. Recorded from source only, not seen in a capture: the Off, Paused and calibration states, controls in a key window (where the native slider and switch take the action blue instead of inactive grey), the click ring at the cursor, and all motion.

A second surface, the film, was built later in the same world. It is recorded under "The Film" at the end of this file, which says where it departs from the app. Two details of the shared 3D case changed with it and are corrected below under "The case".

## Overview

**Creative North Star: "The Living Room"**

The window is a small room. A dot-matrix screen hangs on a pale wall, the AirPods case stands on the floor beneath it, and the dot being aimed is lit on that screen. Everything is a mirror of the hand: the case on screen turns as the real one turns, the lit dot is the real cursor, and a tap answers twice at once, as a ring spreading from behind the case and a ring of dots on the screen. The app's settings are not a sidebar of grouped rows; they are four large pills along the bottom, each opening one white panel beside the stage.

The materials are few. The room is cool matte white by day and deep blue-black at night. One sky-blue keyline outlines what can be acted on and lights what is live. Forms are pebbles: capsules, a 22 pt continuous-corner panel, round dots. The only glossy object is the case, rendered in 3D with physically based white plastic; everything drawn in SwiftUI is flat and matte. Targets are large, because the pointer being configured is often the one doing the clicking, from arm's length.

It is a tool to be opened, tuned and closed. Text says what is happening and the physical thing to do about it, in a rounded display line and one plain line under it.

**Key Characteristics:**
- A stage (screen over case over status line) that is the whole idea in one picture; panels open beside it, never over it.
- One accent in two strengths: `keyline` for outlines and lit things, `action` for fills and accent text.
- Capsule pills at three heights (30, 38, 48 pt), outlined in the keyline.
- A dot-matrix miniature of the real display, 40 by 26 dots, showing the real cursor.
- One glossy object, the case, white in both appearances.
- Native Mac controls (slider, switch, segmented picker) tinted with `action`, not redrawn.
- Motion only as an answer to state: a tap, a lid, a panel, a switch.

## Colors

Cool blue-tinted neutrals with a single sky-blue accent and one amber for trouble; every token has a light and a dark value and follows the window's appearance.

### Primary
- **Sky Keyline** (`keyline`): the one colour. Pill and panel outlines (1.5 pt on pills, 1 pt at 70% on the panel), lit dots, tap-count dots, setup progress dots, the response curve and the left-right trace, the case's status light and tap ring, the click ring at the cursor. Never used for text in light mode.
- **Deep Sky Action** (`action`): filled controls and accent text: the primary pill, the power switch when on, secondary pill labels, value readouts, the done checkmark, the scroll chevron, the tint of native sliders and switches, and the asset-catalog accent colour. Deeper than the keyline by day so white labels and small text clear 4.5:1 (per the source); at night it is the same value as the keyline.
- **On-Action** (`on-action`): text on an `action` fill: white by day, near-black blue at night.

### Secondary
- **Amber Warn** (`warn`): a requirement only the user can meet: the exclamation mark on an unmet Setup row and the 9 pt badge on the Setup pill. Nothing else.

### Neutral
- **Cool Matte White / Blue-Black** (`stage`): the wall, and the flat ground of the menu-bar panel and the Signal chart well.
- **Floor Shade** (`stage-floor`): the floor, a shade deeper than the wall so it recedes.
- **Panel White** (`panel`): raised surfaces: pills, the panel, the dot screen's face.
- **Slate Ink** (`ink`): headlines, control titles, figures, the up-down trace, the tap meter's threshold line.
- **Soft Slate** (`ink-soft`): secondary text, tinted toward the stage rather than neutral grey; also the waiting symbol, tap spikes, and the idle cursor marker on the screen.
- **Hairline** (`hairline`): 1 pt rules under group headings and between figures, the skirting line, the unlit screen's outline, chart axes, the off switch's track, the tap meter's track.
- **Unlit Dot** (`dot-off`): an unlit dot, on the screen, in tap counts and in setup progress.

Literal white is used in three places that are objects rather than surfaces: the power switch's thumb, the halo under the click ring, and the case.

### Named Rules
**The One Colour Rule.** There is one accent hue. `keyline` draws lines and lit things; `action` fills controls and colours text. A second hue is never added for emphasis, category or decoration.

**The Only-You-Can-Fix-It Rule.** `warn` marks a thing only the user can fix (a permission, Automatic Ear Detection). It is never decorative, never a generic "notice", and never used for a state that fixes itself, which is shown in `ink-soft` as waiting.

**The Outline-Not-Text Rule.** By day the keyline is too light for text. Anything that must be read in the accent uses `action`.

## Typography

**Display Font:** SF Pro Rounded (the system font, `design: .rounded`)
**Body Font:** SF Pro (the system font, default design)
**Figure Font:** SF Pro Rounded with monospaced digits

**Character:** Rounded for what the window says about itself, plain for what the user reads and adjusts. On a native Mac app the system face is the platform's own material, and its rounded cut matches the pebble forms. Sizes are fixed points; no line-height or tracking overrides are set, except +2 pt line spacing on the status detail.

### Hierarchy
- **Display** (bold rounded, 30 pt): the status headline under the case ("Pointing", "Asleep") and the title of each first-run step. One per view.
- **Title** (bold rounded, 20 pt): the sentence at the top of a panel, group headings inside a panel, the headline of the menu-bar panel.
- **Pill** (semibold rounded, 15 pt; 13 pt in the small pill): every pill label and the power switch's "On" / "Off".
- **Heading** (semibold, 14 pt): the title of a control row.
- **Body** (regular, 14 pt): the status detail (max 380 pt wide, centred), gesture descriptions, figure labels.
- **Caption** (regular, 12.5 pt, `ink-soft`): the one line under a control saying what it changes, slider end labels, chart axis labels and legends.
- **Figure** (medium rounded, 13 pt, tabular digits): any number that changes: slider readouts in `action`, signal figures in `ink`, battery, recorded shortcuts.

### Named Rules
**The Changing-Number Rule.** A number that can change on screen is set in `figure`, so its digits do not shift as it changes.

**The Panel-Says-What-It-Is-For Rule.** A panel opens with a plain sentence in `title` ("How the cursor answers your hand"), not a label and not the tab's name again.

## Layout

One fixed window, not resizable content: the SwiftUI frame is 880 by 640, running up under the title bar so the top bar shares its row with the window buttons (the window as captured is 880 by 672). There are no breakpoints.

- **Top bar** (52 pt high, 18 pt side padding): 62 pt reserved for the window buttons, the app name, and the power switch at the right.
- **Stage** (fills the remaining width): a top-aligned column of the dot screen (360 pt wide, height from the real display's aspect ratio), the case (drawn 300 by 231 in a 236 by 196 slot, so the tap ring can spread past it), and the status line (94 pt slot). Spare height falls under the status line.
- **Panel** (448 pt wide, 22 pt inset, 18 pt from the window's right edge, 8 pt above the tab bar): present only when a tab is open or during first-run setup. With no panel the stage stands centred; opening one slides the stage left.
- **Tab bar**: four large pills, 12 pt apart, 8 pt above and 14 pt below. Clicking the selected pill closes its panel. Hidden during first-run setup.
- **The room**: the wall meets the floor at 62.8% of the window's height, behind the case. The wall lightens slightly toward the top; the floor is lightest at the skirting line, which is a 1 pt hairline fading out toward both sides.
- **Menu-bar panel**: 340 pt wide, 16 pt padding, 14 pt between blocks, flat `stage` ground, a smaller dot screen (34 columns) and no case.

Rhythm inside a panel: 14 to 16 pt between control rows, 4 to 5 pt inside a row (title, control, caption), 8 pt between a group heading and its rule, 12 pt between sibling pills. Groups are separated by a title and a hairline, never by boxing them.

### Named Rules
**The Stage-Stays Rule.** The case and the screen stay in view whatever else is open. Controls go in the panel beside the stage; nothing covers it and nothing replaces it, including first-run setup.

**The Fit-First Rule.** A panel is composed to fit its height without scrolling. Where it cannot (Setup), the bottom edge fades to `panel` over 56 pt and a `chevron.compact.down` in `action` says there is more; both disappear at the end of the scroll.

**The Arm's-Length Rule.** Anything clicked often is large: tab pills are 48 pt high with a 92 pt minimum label, native sliders and segmented pickers use the large control size, and nothing needs a hover to be understood.

## Elevation & Depth

Depth is the room, not a stack of cards. The wall-and-floor ground gives the scene a horizon; the case stands on the floor with a soft contact shadow; the screen and the panel sit slightly off the wall with one soft ambient shadow each. Pills carry a small shadow that deepens on hover. All shadows are low, soft and straight down.

Every shadow colour comes from `Theme.shadow(strength)`: the ink hue at the given alpha by day, and near-black at 4.5 times the strength at night, where a pale shadow would read as a glow.

### Shadow Vocabulary
SwiftUI terms: `.shadow(color: Theme.shadow(s), radius:, y:)`.
- **Panel** (`s 0.10, radius 16, y 8`): the settings panel.
- **Screen** (`s 0.10, radius 12, y 6`): the dot screen.
- **Screen glow** (`Theme.keyline` at 32%, `radius 14`, no offset): around the dot screen, only while the pointer is live.
- **Secondary pill** (`s 0.06, radius 2, y 1`; hover `s 0.12, radius 6, y 3`).
- **Primary pill** (`s 0.16, radius 4, y 2`; hover `radius 7, y 3`).
- **Switch thumb** (`s 0.2, radius 1.5, y 1`).
- **Contact shadow** (a 166 by 19 pt ellipse filled with `Theme.shadow(0.22)`, blurred 10 pt): under the case, on the floor.

### Named Rules
**The Dark-Shadow Rule.** A shadow is never the `ink` token, which turns pale at night. Use `Theme.shadow(strength)`, which is dark in both appearances.

**The One-Glow Rule.** The only glow around a surface is the dot screen's: keyline-coloured, and present only while the pointer is live. Lit dots, the case's status light and the tap rings are lit marks, not glows; no other surface gets a coloured halo.

**The One-Glossy-Object Rule.** Nothing drawn by the app is glossy except the case. No sheen, glass or specular highlight on pills, panels or the screen. Native controls keep whatever material the system gives them.

## Shapes

Rounded pebble forms throughout. Buttons and the power switch are capsules. The panel is a continuous-corner rectangle at 22 pt; the dot screen is the same form at 20 pt. Dots are circles: 1.5 pt radius unlit on the screen, swelling to 3.5 pt at full brightness, 9 pt across in tap counts, 7 and 10 pt in setup progress. Meter tracks and legend swatches are capsules. There are no square corners and no boxes inside the panel.

Outlines are thin and in the keyline: 1.5 pt on a secondary pill (2.5 pt on hover), 1 pt at 70% on the panel, 1.5 pt on the live screen (1 pt `hairline` when not live). Stroked chart lines have round caps and joins.

## Components

### Buttons
The world's button is a pill: generous, outlined, labelled with a verb.
- **Shape:** capsule. Three sizes: small (30 pt high, 14 pt side padding, 13 pt label), regular (38, 20, 15 pt), large (48, 28, 15 pt).
- **Primary:** `action` fill, `on-action` label. The one thing to do next in its group, and the selected tab.
- **Secondary:** `panel` fill, 1.5 pt keyline outline, `action` label. Everything else that acts.
- **Quiet:** label only, in `ink-soft`. The least important action in a group ("Cancel", "Skip setup", "Quit").
- **Hover:** primary brightens 7% and its shadow deepens; secondary gains a 16% keyline wash and a 2.5 pt outline; quiet turns `ink` on a 60% hairline capsule. A large pill also grows to 103.5%, except under Reduce Motion.
- **Pressed:** scales to 97%; primary darkens 6%; secondary's wash rises to 24%.
- **Disabled:** 45% opacity.
- All state changes ease out over 0.18 s.

### Power switch
A wide capsule (32 pt high) that says which way it is set: "On" in `on-action` on an `action` fill with the white 24 pt thumb at the right, or the thumb at the left and "Off" in `ink-soft` on a `hairline` track with a faint outline. It is exposed to assistive technology as a toggle. The Off appearance is from source; it was not captured.

### Navigation (tab bar)
Four large pills: Feel, Taps, Setup, Signal. Unselected is secondary, selected is primary; selecting the open one closes it. The Setup pill carries a 9 pt `warn` dot at its top-right corner while something only the user can fix is in the way.

### Panel
The one container. `panel` fill, 22 pt continuous corners, 1 pt keyline outline at 70%, the Panel shadow, 22 pt inset, 448 pt wide. It slides in from the right with the settle curve. Content is a single left-aligned column that opens with a `title` sentence; an optional footer sits under the scroll area (first-run setup's "Skip setup").

### Control rows
- **Slider row:** heading at the left, readout in `figure` and `action` at the right; a native large slider tinted `action` with 46 pt end labels in caption ("Slow", "Fast"); one caption line saying what it changes.
- **Switch row:** heading and optional caption at the left, a native switch tinted `action` at the right.
- **Choice:** a native large segmented picker.
- **Group heading:** a `title` line with a 1 pt hairline 8 pt beneath, 10 pt of extra space above.
- **Checklist row (Setup):** a 19 pt SF Symbol at the left (filled checkmark in `action` when done, dashed circle in `ink-soft` when waiting, filled exclamation mark in `warn` when the user must act), the heading with its one small pill on the same line, and the explanation in caption beneath at full width.
- **Shortcut field:** heading at the left, a small secondary pill showing the shortcut in `figure`; it turns primary and reads "Press keys…" while recording.
- **Figure row (Signal):** label in body and `ink-soft`, value in `figure` and `ink`, a hairline between rows.

### Tap dots
One, two or three 9 pt keyline dots, 5 pt apart: the picture of a tap count, used wherever a gesture is named. The same dot vocabulary marks first-run progress (7 pt, the current step 10 pt, lit up to the current step).

### Dot screen (signature)
A miniature of the Mac's main display in its real aspect ratio: 40 by 26 dots on a `panel` face with 14 pt padding and 20 pt corners. The dot under the real cursor is lit in the keyline with a soft falloff to its neighbours; it leaves a trail that fades over 0.42 s; each tap sends out a ring of lit dots that spreads and thins over 0.6 s. While the pointer is live the screen has a 1.5 pt keyline outline and the Screen glow. When it is not, the outline is a hairline, the glow is gone and the cursor is marked only by the nearest dots, enlarged, in `ink-soft`.

### The case (signature)
The AirPods case in SceneKit, generated rather than modelled, shown as a mirror would show it: facing the viewer, lid open behind the two docked AirPods, turning as the real one turns (yaw within 55 degrees, roll within 75, easing back to centre). The AirPods are plain white heads with nothing drawn on them: they no longer carry dark vents, because a dark vent on each read, at any size, as a pair of eyes. White physically based plastic (the shell at roughness 0.3) under a soft studio environment, one directional light and a cool ambient fill; in Dark Mode the environment dims and the lights are raised so the case stays white. Asleep is a shut lid and an unlit status light; awake, the lid stands open at 105 degrees and the light is the keyline. A tap sends a thin keyline ring out from behind the case, wider than tall (its height is 0.76 of its width). The ring does not turn with the case. It sits 3.4 model units behind it, far enough back to stay behind the lid however the case is tilted, and is lowered by 0.75 and widened to match, so that from the camera it is where and as large as it would be just behind the case.

### Status line
The display headline, one body line of what to do, and at most one small pill, centred under the case. It reports only what is happening on the stage; during first-run setup, permissions are the panel's subject.

### Charts
Drawn in a canvas with the same few colours: keyline for the primary trace or curve (2 to 2.5 pt, round joins, a 10% keyline fill under the response curve), `ink` at 75% for the second trace, `ink-soft` for tap spikes and thresholds (dashed 3-3), hairline for axes. The live point on the response curve is a 10 pt `action` dot on an 18 pt keyline disc at 20%. The tap meter is a 10 pt capsule track in hairline whose bar turns keyline once it crosses the `ink` threshold line.

### Click ring
At the cursor on every click, in a click-through panel above everything: a 2.5 pt keyline ring over a 5 pt white halo so it reads on any background. One ring for a click, two for a double-click, a dashed ring for a right-click, a ring closing inward for a drag hold. From source; it was not captured or reviewed.

### Motion
Two curves. `quick` (ease-out, 0.18 s) for state changes on a control or a line of text. `settle` (timing curve 0.16, 1, 0.3, 1 over 0.42 s, no bounce) for layout moves: the panel sliding in, the stage moving aside, the tab bar arriving. The lid opens in 0.42 s and shuts in 0.3 s. With Reduce Motion on, slides become fades on the quick curve, the lid snaps, and every ring holds one size and only fades. Motion was not reviewed.

## Do's and Don'ts

### Do:
- **Do** take every colour from `Theme` and every text style from `Typo`; both appearances come with the token.
- **Do** use `keyline` for outlines and lit things and `action` for fills and accent text.
- **Do** make the next step a primary pill, other actions secondary pills, and the least important one quiet; one primary per group.
- **Do** put new controls in a panel beside the stage, opening with a `title` sentence and separated into groups by a title and a hairline.
- **Do** use native sliders, switches and segmented pickers at the large size, tinted `action`.
- **Do** set every changing number in `figure`.
- **Do** cast shadows with `Theme.shadow(strength)`, soft and straight down.
- **Do** show the case asleep by a shut lid and an unlit status light, and keep it white in both appearances.
- **Do** tie every animation to a change of state, on `quick` or `settle`, with a fade in its place under Reduce Motion.
- **Do** say what is wrong and the physical fix, in the status line or the row's caption.

### Don't:
- **Don't** build a Settings sidebar of grouped rows, or box groups inside the panel.
- **Don't** add a second accent hue, or use `warn` for anything the user cannot fix themselves.
- **Don't** use the `ink` token as a shadow colour.
- **Don't** add a glow to anything but the live dot screen.
- **Don't** make anything glossy except the case: no sheen, glass or highlight on pills, panels or the screen.
- **Don't** dim or tint the case to show a state.
- **Don't** set text in `keyline` by day.
- **Don't** let a panel scroll when it could be made to fit; where it must, keep the fade and the chevron.
- **Don't** add idle or decorative motion, or bounce.
- **Don't** cover the stage or make anything depend on hover to be understood.

## The Film

A second surface in the same world: a film about AirPointer, 75.9 seconds at 60 frames a second, drawn frame by frame in SwiftUI by `Video/Sources/film` and written out by `Video/render.sh`. It is meant for the top of the README and the user's portfolio, where it is most often watched without sound in a player well under half its size. This section is recorded from that source and from sixteen stills of the rendered film (`.impeccable/review/film/`), not from a plan. The film's tokens live in `Video/Sources/film/Look.swift` as `Look`; the timeline is `enum At` in `Film.swift`. Every length in this section is a real pixel in a 1920 by 1080 frame (`render.sh --4k` scales the same layout to 3840 by 2160).

Three things are not finished, and one is not confirmed:
- **The two clips are placeholders.** `Video/footage` is empty, so both footage slots show a card saying what belongs there until the user films them.
- **There is no sound.** The renderer can lay a music file under the film and keep a clip's own sound, but neither exists yet; the rendered files have a picture track only.
- **The chapter order was the builder's choice.** Show, prove with a clip, twice, then explain: it was chosen while the user was away and awaits their confirmation. It is one enum (`At`).
- The address on the end card (`github.com/Ritvik-Bansal/AirPointer`, passed in from `main.swift`) is not confirmed until the repository exists.

Seen in the stills: every chapter, including the title card with the lid shut and open, the first clip's card opening and fully open, a tap ring on the case and on the screen, both halves of the gravity diagram, the signal display early and full, the results, the steps and the end card. Also checked in two frames taken from the rendered film: the second clip's card and the last frame. From source only: the timing of all motion and the case's moves between placements.

### The room, flat

The film is the app's room at night with everything but the case made flat. The wall and the floor are two solid tones meeting at a hard edge 742 px down the frame; there is no skirting line and neither tone is graded. The case is the app's own `CaseScene`, rendered in its Dark Mode lighting by `CaseRender.swift`, and it is the only thing in the frame with any shading.

That is why three things the app's sections describe are absent here. The dot screen has no ambient shadow and no Screen glow: live, it is marked by its outline turning from hairline to keyline and nothing else. The case has no contact shadow, and so it does not stand on the floor: it hangs in the room, straddling the horizon at its large placement, and is free to travel to any part of the frame. Nothing else carries a shadow either.

There is one room and one object. Whenever the film is drawing, the case is in the frame, and whatever is said about it is said beside it. It gives way only to the two clips, which open over it.

### Palette

Fixed sRGB values, not appearance pairs: the film has no light version. All but two are the app's Dark Mode tokens.

| `Look` | Hex | Used for |
| --- | --- | --- |
| `wall` | `#0E151D` | The wall (the app's `stage-dark`); the fill of the tag capsule and of the callout's open ring. |
| `floor` | `#090E14` | The floor, below 742 px (`stage-floor-dark`). |
| `panel` | `#16202B` | The face of the dot screen, the signal display and the clip card (`panel-dark`). |
| `ink` | `#EAF2F8` | Headlines, labels joined to the case, the large figures, the steps, a refused verdict, the hand-turning band where it is over its limit (`ink-dark`). |
| `soft` | `#9FB2C4` | Sentences, notes, the "/ 10" beside a figure, callout lines and rings, the gravity line and its label, band labels, quiet lit dots on the signal display (`ink-soft-dark`). |
| `key` | `#48B9F5` | Lit dots, the live outline of a display, the tag's outline, the two arcs of the gravity diagram, counted taps, an accepted verdict, step numerals, the address on the end card (`keyline-dark`, which at night is also `action-dark`, so it may be read as text here). |
| `hairline` | `#2A3947` | A display's outline before it is live, and the clip frame's 2 px border. Not the app's `hairline-dark` (`#27343F`); the film sets its own value. |
| `dotOff` | `#2B3947` | An unlit dot (`dot-off-dark`). |
| `dotLine` | `#566A7D` | An unlit dot that is part of a threshold line drawn across the signal display. Film only. |

`warn` is not used. Opacity is used on `key` and `ink` only in the gravity diagram (an arc at 30% until its rotation is being shown, its label at 40%) and on lit dots by brightness. The case's status light and tap ring take the app's `Theme.keyline` inside the 3D scene; in the rendered film the ring measures close to `key` (`#46B4EE`) and the status light is `key` exactly (`#48B9F5`).

### Type

The same two faces as the app: SF Pro Rounded for headlines, labels and figures, plain SF Pro for sentences.

- **Title** (bold rounded, 104 px, tracking -1.2% of the size): "AirPointer" on the title card and the end card.
- **Chapter headline** (bold rounded, 72 px, tracking -1.2%): one or two lines, each its own line of text with no extra leading. "Aim it." "Tap it." "The sensors are / in the AirPods." "Gravity says / which way is up." "A tap is one reading / out of line." "Tuned on recordings / of a real hand." "To start".
- **Figure** (bold rounded, tabular digits): 168 px in `ink` for a result, 64 px in `soft` for "/ 10" beside it, 46 px in `key` for a step numeral.
- **Step** (medium, 46 px, `ink`): the three steps.
- **Address** (medium, 42 px, `key`): the repository on the end card.
- **Sentence** (`Look.sub`, regular, 37 px, `soft`, 9 px line spacing): the one or two sentences 26 px under a headline, in a block 800 px wide (700 and 900 where a line break needed it), and the label under each result.
- **Label** (`Look.label`, semibold rounded, 32 px): anything attached to a drawing: callouts, "gravity", "left and right", "up and down", "hand turning", "jolts", the verdicts under the signal display, the word in the tag on the screen.
- **Small** (`Look.small`, regular, 32 px, `soft`): the note along the bottom saying how something was made, and "Tested with AirPods Pro 3 on macOS 27." on the end card.

### Frame and layout

- **Frame:** 1920 by 1080. The wall meets the floor at 742 px (68.7% of the height; the app's window puts it at 62.8%).
- **Margin:** 150 px. Every text block starts at the left margin, and the clip frame and the signal display run from margin to margin (1620 px).
- **Text, top-left:** the headline's top is 142 px down. Sentences follow 26 px under it. The results start 420 px down, the steps 330 px, the end card's address 296 px. A note sits at the left margin 84 px above the bottom edge.
- **The case, right:** four placements, by centre and scale of a 1000 by 780 px render. *Hero* (1335, 630) at 1.0: the title, the sensors and gravity chapters, the steps, the end. *Under* (1390, 839) at 0.55: beneath the dot screen while it is aimed and tapped. *Aside* (1545, 322) at 0.5: top right, above the signal it is producing. *Beside* (1520, 600) at 0.5: to the right of the results.
- **Dot screen:** 740 by 470 px, centred at (1390, 335), above the case's *under* placement.
- **Signal display:** left edge at the margin, top at 556 px, 1620 px wide including the band labels to its left; the verdicts are written in the 62 px beneath it.
- **Clip frame:** x 150, y 84, 1620 by 912 px: between the margins, 84 px clear top and bottom, and large enough to cover everything on the stage behind it.

The left half is for reading and the right half is for the case; the two full-width pieces (the signal display, a clip) take the lower part of the frame or all of it.

### Timeline

| Starts (s) | Chapter | What is on screen |
| --- | --- | --- |
| 0.0 | Open | Title card. The case shut, at hero; the lid lifts from 0.6 s. |
| 4.4 | Aim | The case moves under the dot screen, which draws on. A recorded turn left and right, then a tilt up and down, moves the lit dot. |
| 11.8 | Clip A | "Over the shoulder", 6.5 s. Placeholder card. |
| 18.3 | Tap | Two recorded double-taps, then a single tap: rings on the case and the screen, and a tag naming the result. |
| 25.9 | Clip B | "A real click", 6.5 s. Placeholder card. |
| 32.4 | Sensors | The case at hero, with two callouts. |
| 39.2 | Gravity | The gravity line and two arcs drawn round the case as it is turned, then tilted. |
| 47.6 | Jolt | The case aside, replaying a recorded stretch while the signal display fills. |
| 57.2 | Proof | Three results with counted dots; the case beside them. The lid shuts at the end. |
| 63.2 | Setup | Three numbered steps; the lid opens on the second and the case points on the third. |
| 69.7 | End | End card, held to 75.9. |

### Motion

Two curves, in `Motion.swift`, applied to a linear 0 to 1 span of time. `settle` (exponential ease-out, `1 - 2^(-10x)`) is for things arriving. `glide` (cubic ease in and out) is for things travelling and for lines drawing on. Neither overshoots. These are the film's own; they are not the app's `quick` and `settle`.

- **Headlines rise from behind their baseline.** Each line is masked by its own frame and slides up into it from 105% of its height below, over 0.7 s on `settle`; a second line follows 0.09 s later. Nothing is seen below the line it will sit on.
- **Sentences lift.** Sentences, labels, notes, steps and dots rise 16 px over 0.6 s on `settle` while fading in over 0.35 s. The sentence under a headline starts 0.22 s after the last headline line.
- **Text leaves by fading** over the last 0.28 s of its cue, which ends 0.15 s before the next chapter (0.3 s on the title card).
- **The case travels.** It moves between placements over 1.0 s on `glide`, changing place and scale together, starting 0.1 s before the chapter it is moving for (0.3 s before Aim). It is never faded and never cut. The one move nobody sees (from under the screen back to hero) happens behind the second clip, where the dot screen is taken down as well. A change of pose is blended on `glide` in the same way, and the lid shuts while the case is in place, not while it is travelling.
- **Lines draw on.** A display's outline is traced round its edge and its face and dots then come up; a callout's line is drawn from the case outward over 0.55 s; the gravity line and each arc are drawn over 0.7 s, with arrowheads appearing as the line arrives.
- **Drawings leave by fading** (the gravity diagram and the signal display, over 0.3 s). Only the case and the clip frame are barred from fading.
- **The clip frame opens from a line.** It grows from a line across the middle of the frame to full height over 0.5 s on `glide` and closes back to it over the last 0.45 s of its slot. It is opaque from its first moment, so what is behind it is covered and never seen through it; the corner radius is 30 px, less while the frame is under 60 px tall.
- **The first and last frames are complete cards.** A player shows the first frame before anyone presses play and is left showing the last. So the title and its sentence are already in place at 0.0 s and nothing arrives; the first thing to move is the lid. The end card's text arrives once and holds to the last frame, while the case turns a few degrees behind it. `render.sh` takes its poster from 3.2 s, the title card with the lid open.

### Dot-matrix displays (signature)

Anything measured is shown as lit dots. Three things in the film are of this one kind, and they share a face: a `panel` rectangle with 30 px continuous corners and 30 px of padding, a 3 px outline that is `hairline` until the display is live and `key` after, and unlit dots 5.8 px across in `dotOff`.

- **The screen.** A miniature of the Mac's display, 44 by 27 dots. The dot under the cursor is lit in `key` and swells to 13 px across, with a falloff over its neighbours. While the case is being aimed the cursor leaves a trail 22 frames long. Each tap sends a ring of lit dots out from the cursor over 0.6 s. When the engine decides what the taps were, a tag lifts off the cursor for 1.2 s: the word ("click", "double-click", "right-click") in Label on a `wall` capsule with a 2.5 px `key` outline, above the cursor or below it when there is no room above.
- **The signal display.** 87 columns at the screen's own dot spacing, each a sliver of time, filling from the left as a recorded stretch is replayed. The lower band of nine rows is the jolt score; the upper band of eight is how fast the hand had been turning (one dot for 4 degrees a second). A row of `dotLine` dots across each band marks the line that matters there: a jolt has to reach its line, and the hand has to be under its own (16 degrees a second, the engine's limit). Lit dots are 8.8 px across and carry meaning by colour: `soft` for an ordinary reading, `key` for a jolt that was counted as a tap, `ink` for the hand over its limit. What the engine decided is written under the column it happened in: "two taps: click" in `key`, "a knock: refused" in `ink`.
- **The counted dots.** Under each result, one dot for each thing counted: 12 px in `dotOff`, 15 px in `key` once counted, lighting in turn 0.07 s apart. Double-taps are drawn as pairs. The twelve knocks stay unlit, because none was let through.

The figures above the counted dots (10 / 10 single taps found, 6 / 6 double-taps found, 0 / 12 knocks let through) are written into `Figures` in `Diagrams.swift` as constants. They are not computed when the film is rendered. The engine's own tests assert the same counts on the same recording (`wholeSession` in `RecordingTests.swift`), so if the engine or the recording changes them a test fails first; change the film's figures to match before rendering again.

### Drawings on the case

- **Callout:** a 2 px `soft` line from a point on the case, through one elbow, to a label in Label and `ink`. The point is marked by a 16 px open ring (`wall` fill, 3 px `soft` border), open so that it cannot be taken for the status light. The points are fixed places on the 3D model, projected into the frame.
- **Gravity diagram:** a dashed 2 px `soft` line straight down through the case with an arrowhead and the label "gravity", and two 3.5 px `key` arcs with arrowheads at both ends: one round the front of the case for turning ("left and right"), one up its side for tilting ("up and down"). An arc and its label are full strength only while the case is making that rotation.
- **Steps:** a numeral in `key` and the step in `ink`, 30 px apart, arriving 1.2 s apart.

### Recorded motion

Motion that the film presents as real is real. The aiming, the taps and the stretch behind the signal display are cut from one recording of a hand holding the case (`Packages/PointerKit/Tests/PointerKitTests/Fixtures/case-grip.trace`) and played through the app's own engine (`Take.swift`): the pose of the case, the path of the cursor, each tap, each click and each refused knock are what the engine produced from that recording. The hand-turning band of the signal display is worked out in `Take.swift` by the same measure the engine's knock gate uses (mean turning speed over the half second before). The film says so on screen, in Small along the bottom: "Real motion, replayed through the app's own engine." and "One recorded session, replayed end to end."

The pointer speed is turned down to 0.3 for the two aiming takes, because they were recorded with nothing on screen to aim at and sweep wide. Motion that explains instead of demonstrating is posed by hand and carries no such note: the opening turn, the held pose under the callouts, the turn and tilt of the gravity chapter, the point on the third step.

### Footage slots

Two stretches are given over to clips the user films: slot A at 11.8 s and slot B at 25.9 s, 6.5 s each. A clip is a file named `A` or `B` (`.mov`, `.mp4` or `.m4v`) in `Video/footage`. It is turned upright, scaled to fill the 1620 by 912 frame with the overflow cropped, converted to ordinary colour range and kept in step with the film's clock; if it runs short, its last picture holds. `cuts.json` in the same folder can say where each clip starts and whether it keeps its sound, and a file named `music` there is laid under the whole film.

While a slot has no clip, its frame shows a card on `panel`, centred: the slot's name in Label and `key`, its title in bold rounded 60 px, one sentence saying what to film, and "Footage to come, 6.5 seconds". The card says outright that it is standing in for something, so a first cut is not mistaken for the finished film. It is a production note, not part of the film's design: it disappears when the clips arrive and nothing else should be built on it.

### Named Rules

**The Only-The-Case-Is-Lit Rule.** No gradients, no glows, no shadows. Every surface the film draws is a flat fill or a stroke. The only shading in the frame is light on the 3D case (and whatever is in a filmed clip). Lit dots are marks, not glows.

**The Case-Hangs Rule.** With no contact shadow the case is not standing on anything, and it is not drawn as if it were. It is placed by where the chapter needs it, and it may cross the horizon.

**The Case-Travels Rule.** The case is in the frame whenever the film is drawing. It moves between placements on `glide`; it is never faded, cut to, or cut away from. A move that cannot be shown happens behind a clip.

**The Complete-Card Rule.** The first frame and the last frame are complete, legible cards, because they are what a player shows when the film is not playing.

**The 32 Rule.** Nothing is set smaller than 32 px. Embedded in a web page the film is shown at under half its size, and 32 is the least that still reads there.

**The Measured-On-Dots Rule.** Anything measured (the cursor, the signal, a count) is shown on a dot-matrix display of the one kind, not on a line chart or a bar.

**The Replayed-Not-Animated Rule.** Motion presented as real is a recording replayed through the app's engine. Hand-posed motion is used only to explain, and is never captioned as real.

**The Opaque-Clip Rule.** A clip's frame opens from a line and closes to one, between the margins, and is opaque throughout. The stage is never seen through it or dissolved into it.

### Do:
- **Do** take every colour and text style from `Look`, and every time from `At`.
- **Do** start every text block at the 150 px margin and keep the case to the right of it.
- **Do** bring a headline in with `reveal` and everything else that is text with `lift`.
- **Do** move the case with a new placement and a `glide`, starting just before the chapter that needs it.
- **Do** show a new measurement on a dot display with the shared face, the screen's dot spacing, and `key` for what was counted.
- **Do** cut real motion from the recording with `Take.cut`, and say on screen that it is a recording.
- **Do** re-read the first and last frames after any change to the opening or the end.
- **Do** keep each chapter to one headline and at most two sentences.

### Don't:
- **Don't** add a gradient, a glow, a shadow or a blur to anything the film draws, including the dot screen's glow and the contact shadow from the app.
- **Don't** stand the case on the floor or give it a ground to sit on.
- **Don't** fade the case in or out, or cut between two views of it.
- **Don't** set anything smaller than 32 px, or shrink a label to make it fit.
- **Don't** let anything show through the clip frame, or cross-dissolve into a clip.
- **Don't** animate by hand something the film presents as the engine's output: a cursor path, a tap, a verdict.
- **Don't** add a second accent, or use `key` for decoration; it marks what is lit, live or counted.
- **Don't** treat the placeholder card as a component, or describe the clips, the sound or the chapter order as settled until the user has supplied or confirmed them.

## The Spot

A third surface, and a deliberate opposite of the film above: a 30-second product spot, 1920 by 1080 at 30 frames a second, with sound. It is a Three.js scene (`Video/Spot/web/src`) rendered frame by frame in headless Chrome by `Video/Spot/render.sh`. The brief for it asked for an ultra-premium tech commercial: cinematic tones, vivid light, depth of field, continuous transitions. Where the film is flat, diagrammatic and explains, the spot is lit, photographic and shows. The two do not share a look and are not meant to be cut together.

This section is recorded from the source and from frames of the rendered spot. The storyboard, with every time, is `web/src/timeline.js`; `Video/Spot/README.md` sets it out as a table.

Not confirmed, or not what it may seem:
- **The address on the end card** (`github.com/Ritvik-Bansal/AirPointer`) is not confirmed until the repository exists. It is one flag: `render.sh --address`.
- **The sound has not been heard by its maker.** It was built and checked by measurement (levels, spectrogram, cue times), not by ear.
- **The window on the Mac is a redraw of the app**, from the app's source, not a capture of it, and the case inside that window is the spot's new model, which the app itself does not yet use.
- **The pointer is simplified**: the cursor is drawn exactly where the case is aimed. The app works from how fast the case turns.

### The studio

Black, and nothing else behind the subject: ground `#020305`, a dark desk that runs off into fog rather than to a horizon and takes a soft pool of light, and the case's shadow, under the case. In it, one white glossy object (the case), and a Mac whose screen is its own light.

Light has three colours and no others. The app's keyline blue comes from the right, the side the camera mostly looks toward: a tall strip the case mirrors along one edge, and a soft blue across the desk behind the subject. Amber (`#FF7A2E`) comes from the left, much smaller and dimmer: it is the blue's opposite, there so that white plastic has two edges, and it is never the larger of the two. Between them the screen glows the cool blue of the app's Dark Mode. White light is a soft key from the front and above, a kicker from behind, and two tall narrow panels the case's flat face mirrors as a hard-edged band: one for the opening, where the band crosses the face before the lid lifts, and one set low for the end card, where the camera looks down.

Every change of tone in the frame is one of three things: light falling on a surface, focus, or the lens (a slight fall-off into the corners, bloom on what is brighter than white, fine grain). Nothing is filled, tinted or titled with a gradient.

### The case

The case and AirPods are a new model, built for this surface: `web/src/model/airpods.js`, in millimetres, from Apple's published sizes and from photographs of a real AirPods Pro 3 case. It carries what the app's simpler case leaves out: the hinge plate and the print under it, the lanyard plate, the port and its holes, the thumb scoop, the hidden status light, the sculpted lid, and AirPods that sit as they really do, tips turned in. The plastic is white with a clear gloss coat; the ear tips are matte; the metal is satin.

The status light is green, as on the real case, and goes out a few seconds after the lid opens, as the real one does. (The app's own case has a keyline-blue light; the spot does not follow it.)

A tap is drawn as a fine ring of keyline blue travelling over the plastic from where the finger landed, low on the back, so that from in front it is seen coming round the side and crossing the face; with it, a small knock of the whole case. It is the one thing in the picture that is drawn rather than lit: a real case shows nothing when tapped. No hand is shown.

### Camera

One camera, no cuts. Each of the five shots ends on the move that begins the next: a pull of focus, an orbit, a push, a pull back. The lens is real: a frame is the average of 96 renders or more with the camera moved across its aperture and the clock across a half-open shutter, so what is off the plane of focus blurs into discs and what moves fast smears. Focus is on the thing the shot is about: the case, or the screen. The one exception is the third shot's landing, where the subject is a tap and the click it makes: there the lens is stopped down and focused between the two, so both hold for the second it takes.

