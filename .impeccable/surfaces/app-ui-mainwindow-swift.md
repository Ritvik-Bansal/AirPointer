---
version: 1
slug: "app-ui-mainwindow-swift"
primary_target: "App/UI/MainWindow.swift"
related_targets: ["App/UI/PopoverView.swift","App/UI/Onboarding.swift"]
---

# Main window, menu-bar panel and first-run setup

**Scope:** every surface the app draws: the main window (stage plus the Feel, Taps, Setup and Signal panels), the menu-bar panel, first-run setup, and the click ring at the cursor. One world across all of them.

**Visitor mode:** Operate.

**Audience and job:** one person with the case in one hand, often at arm's length from the screen, sometimes clicking these very controls with the case. They open the window to set the pointer up, to tune how it feels, or to find out why it is not responding, then closes it.

**Task and important states:** see that the hand and the screen agree; change speed, flick boost, steadiness and tap behaviour; clear whatever is blocking (a permission, Automatic Ear Detection, a shut lid). States that must read at a glance: pointing, asleep, off, paused because the AirPods look worn, teaching the grip, missing permission.

**Constraints:** native Mac structure and controls; follows the system's light and dark appearance; large targets, because the pointer being configured is the one doing the clicking; nothing that needs a hover to be understood.

**Chosen direction:** Point at the Screen, from mid-2000s motion-controller setup screens, picked by the user. Its mini screen is a dot-matrix display, which the user asked to keep from the Pocket Radio direction.

**Memorable moment:** tap the case and two things answer at once: a ring spreads out from behind the case on screen, and a ring of dots lights around the cursor on the miniature display.

**Unresolved:** the case is shown as a mirror would show it (facing you, lid open, both AirPods docked) rather than from behind the hand, because from behind the open lid hides the AirPods. Whether that reads as "my hand" to the person holding it waits on them trying it. Whether twist-to-scroll should be on by default also waits on real use.
