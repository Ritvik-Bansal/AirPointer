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

