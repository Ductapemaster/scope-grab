# Roadmap

1. **Measurements with each capture.** The scope side is proven and implemented: `Scope.frozenCapture()` enables the items, stops, captures, reads the frozen values and restores the run state (`docs/research/measurements.md`). Still to decide before the UI:
   - which items to read, and on which channels;
   - where the values go: a text file next to the PNG, the filename, or the clipboard alongside the image;
   - whether a capture without measurements stays available, since enabling items adds them to the scope's on-screen measurement bar and so to the screenshot.
2. **The scope's LAN dropouts.** It drops off the network for seconds at a time. Check its Auto IP setting, then the cable and switch port.
3. **Pick the whiteboard app** the captures get pasted into. Separate from this repo, but it may change what goes on the clipboard.
4. **USB connection**, if 1.6 s per shot over LAN proves too slow (USB is about 1.1 s, and needs libusb and USB Device set to Computer).
