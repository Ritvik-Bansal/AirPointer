# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack

Native macOS app (the platform field above has no macOS value; `ios` is the nearest, for Apple-platform conventions). Swift 6 toolchain, SwiftUI with AppKit where SwiftUI stops, CoreMotion for the sensor stream, Quartz events for the cursor. Delegated: the request was "a nice app that runs natively on the MacBook"; the stack was left to the builder. Targets macOS 26 and later.

## Users

One person: Ritvik, on their own MacBook, with their own AirPods Pro 3. They hold the AirPods case in one hand and use it to steer the Mac's cursor, sitting at the laptop or leaning back from it. Built as a personal tool and as a test of what the builder can do, in engineering and in interface design. Whether it is ever shared with anyone else is undecided.

## Product Purpose

AirPointer turns the AirPods Pro case into a wireless pointer for the Mac. Aim the case and the cursor follows; tap the back of the case to click. It succeeds when moving the cursor this way feels natural rather than like a trick: steady when the hand is still, quick in a flick, and accurate on a click.

## Positioning

Nothing extra to buy or charge. The pointer is an object already in the pocket, and it works with the AirPods still docked inside it.

## Operating Context

- Both AirPods sit docked in the case with the **lid open**. Closing the lid puts them to sleep about five seconds later; opening it wakes them. The lid is the on/off switch.
- **Automatic Ear Detection must be off** for the AirPods. With it on, a docked or uncovered AirPod stops sending motion. Side effect the user accepts: audio no longer pauses when an AirPod leaves the ear.
- The case is held like a small remote, aimed at the screen, and tapped on its **back**. A double-tap on the front of an open case is Apple's pairing gesture and must be avoided.
- The app lives in the menu bar and mostly stays out of the way. The window is opened to set it up, tune the feel, or see why something is off.
- The trackpad and keyboard keep working alongside it.

## Capabilities and Constraints

Measured on this Mac with these AirPods, not assumed:

- Motion arrives at a fixed 50 Hz from one earbud at a time (the right one in every recording so far), delivered over Bluetooth in bursts with up to about 90 ms of jitter.
- The sensors are in the earbuds. The case itself reports nothing, and its capacitive tap sensor cannot be read by the Mac. Taps are found instead as jolts in the earbuds' accelerometer and gyroscope.
- A single earbud held loose in the fingers also works, with the same setting off.
- Two system permissions are required: Motion & Fitness (to read the AirPods) and Accessibility (to move the cursor and click).
- Clicking: two taps is a click, one tap on its own is a right-click, a third quick tap makes a double-click. This is the user's own proposal.
- Terminology: "the case" is the thing in the hand; "tap" is a finger on the case; "click" is what the Mac receives; "calibrate" teaches the app which way the case points.
- Undecided: whether twisting the case should scroll by default (built, off until tried); whether the app is ever distributed.

