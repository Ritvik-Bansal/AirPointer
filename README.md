# AirPointer

Turns an AirPods Pro case into a pointer for the Mac. Hold the case like a small remote, aim it, and the cursor follows. Tap the back of the case to click.

## Launch arguments for development

```
-rehearse <trace>        play a recording in place of the AirPods; the real cursor is untouched
-appearance light|dark   force the look
-showWindow YES          open the main window at launch even after setup
-background YES          open windows without coming to the front
-popoverWindow YES       show the menu-bar panel in an ordinary window
```

Saved choices can be overridden the same way, for example `-hasFinishedSetup YES -openTab feel`.
