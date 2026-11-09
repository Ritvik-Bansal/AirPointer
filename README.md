# AirPointer

Turns an AirPods Pro case into a pointer for the Mac. Hold the case like a small remote, aim it, and the cursor follows. Tap the back of the case to click.

It is a menu-bar app. The window is for setting it up and tuning how it feels.

## Before it will work

Three things have to be true, and the app's Setup tab checks each one:

1. **Automatic Ear Detection is off** for the AirPods (System Settings → Bluetooth → ⓘ beside the AirPods). With it on, the AirPods stop sending motion as soon as they are out of your ears. The cost: sound no longer pauses by itself when you take an AirPod out.
2. **Both AirPods are in the case and the lid is open.** The lid is the switch. Closing it puts the pointer to sleep about five seconds later; opening it wakes it.
3. **Two permissions are granted:** Motion & Fitness (to read the AirPods) and Accessibility (to move the cursor and click).

## Using it

| Do this | Get this |
| --- | --- |
| Aim the case | The cursor moves |
| Tap the back twice | Click |
| Tap once | Right-click, after a short pause |
| Tap three times | Double-click (or press-and-hold for dragging, if you choose that in Taps) |
| Close the lid | Pointer sleeps |
| ⌃⌥⌘P | Turn the pointer on or off from anywhere |
| ⌃⌥⌘C | Teach it your grip again |

Tap the back or a side. Two taps on the *front* of an open case is Apple's pairing gesture.

The trackpad keeps working alongside it; whichever moved last carries on from where the cursor is.

## Build and install

Needs Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
scripts/install.sh    # build, copy to /Applications, open
scripts/build.sh      # build only; prints the app's path
scripts/test.sh       # engine tests, including replays of recorded sessions
```

Build products go to `~/Library/Caches/AirPointer`, not into this folder.

The app is signed with the local Apple Development certificate. macOS ties the two permissions to that signature, so they survive rebuilds.

## Launch arguments for development

```
-rehearse <trace>        play a recording in place of the AirPods; the real cursor is untouched
-appearance light|dark   force the look
-showWindow YES          open the main window at launch even after setup
-background YES          open windows without coming to the front
-popoverWindow YES       show the menu-bar panel in an ordinary window
```

Saved choices can be overridden the same way, for example `-hasFinishedSetup YES -openTab feel`.
