# Roadmap

1. **Measurements with each capture.** Freeze the scope (`:STOP`), capture the screen, query measurement values, then restore the run state, so the values match the picture. What's known so far: `docs/research/measurements.md`.
2. **Pick the whiteboard app** the captures get pasted into. Separate from this repo, but it may change what goes on the clipboard.
3. **USB connection**, if 1.6 s per shot over LAN proves too slow (USB is about 1.1 s, and needs libusb and USB Device set to Computer).
