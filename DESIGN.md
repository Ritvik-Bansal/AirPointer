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

