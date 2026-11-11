# Scope Grab: design

A small native macOS app that captures the screen of the bench oscilloscope (Rigol DS2072A) in one click, copies it to the clipboard, and saves it as a PNG.

## Why

Dan is restoring an old analog receiver (the Sherwood S-7100A, notes in the vault at `1 Projects/2026 Sherwood 7100A Amp Repair/`). The workflow is: probe a test point, grab the scope screen, drop the image onto a whiteboard next to the open schematic, and move on to the next point. The whiteboard app isn't chosen yet and is out of scope here. What it needs from this tool is an image on the clipboard to paste.

A capture already works from the terminal (`rigol_scpi.py --screenshot`). But typing a command and a filename at every test point is too much friction, and the script doesn't touch the clipboard.

Success: Dan types a label, presses Enter, and within about 2 s the image is on the clipboard and saved in the project folder, with a preview in the window confirming the right trace was caught.

## Goals

- One action (Enter or a click) captures, copies to the clipboard, and saves the file.
- An optional label per capture, used only in the filename.
- A save folder chosen at first launch, changeable any time, and remembered between captures and launches.
- A preview of the last capture, plus the time it was captured.

## Non-goals

- LAN. This scope's network stack is faulty: it byte-reverses its own IP address (cabled straight to the Mac as `10.0.0.2`, it sends ARP as `2.0.0.10`) and answers nothing at the IP level, not even ARP for either address. Initializing the LAN settings and power cycling don't clear it.
- Any SCPI beyond the screen capture: no scope control, waveform data, or settings.
- Reading measurements over SCPI. Measurements switched on at the scope show in its measurement bar, so the screenshot records them. Reading them over SCPI was ruled out: querying an item adds it to that bar, no command lists the items already on it, and stable values need a STOP/RUN cycle around the capture.
- A capture history or gallery. The folder is the history.
- Burning a timestamp or label into the image.
- Picking or integrating with the whiteboard app.

## Anti-goals

- Anything that makes a capture slower than typing a label and pressing Enter: confirmation dialogs, a save sheet per capture, required fields.
- A failed capture that looks like a success: a stale clipboard or preview with no visible error.

## Constraints and facts

- Scope: Rigol DS2072A, firmware 00.03.06, on USB with Utility → IO Setting → USB Device set to Computer.
- Transport: USBTMC (USB Test & Measurement Class). The scope enumerates as vendor 0x1AB1, product 0x04B0, with interface 0 of class FE/03/01, bulk-out endpoint 0x02 and bulk-in endpoint 0x86. macOS has no driver for that interface, so the app opens it from user space through Apple's IOUSBHost framework, with no libusb. Each command goes out as a USBTMC message with a 12-byte header. Each reply is fetched with a request message, and a reply larger than one transfer arrives as one header followed by raw chunks.
- Protocol: SCPI, with commands terminated by `\n`. `:DISP:DATA?` returns an IEEE 488.2 definite-length block: `#`, one digit N, N digits giving the byte count, the data, then a trailing `\n`. The data is an 800 × 480 24-bit BMP, about 1.1 MB. One capture takes about 1.15 s over USB.
- Reference implementation: `open_scope()`, `screenshot()` and `read_ieee_block()` in `3 Reference/Workshop/Rigol DS2072A/rigol_scpi.py` in the vault.
- Platform: macOS 27, Apple Silicon, Swift 6.4 command-line toolchain. Personal use on one machine, not distributed.

## Decided with Dan

- **Toolkit:** a native Swift (SwiftUI) app, not Python. The clipboard image, BMP → PNG conversion, folder picker, remembered settings and Dock launching are all built into macOS.
- **Connection:** USB, chosen once the scope's LAN proved faulty. The app finds the scope on its own, so the window has no connection setting.
- **Outputs:** every capture goes both to the clipboard and to a file.
- **Label:** typed before capturing, used in the filename only. The clipboard image is just the screen.
- **Save folder:** picked at first launch, shown in the window and changeable from there at any time, and sticky across captures and launches. Files go directly into the chosen folder. Dan makes subfolders himself when he wants them.
- **Preview:** the last capture is shown in the window.
- **Timestamp:** shown in the app window with the preview (Dan said "on the screen", read as the window, not drawn on the image).

## Window

A single small window, top to bottom:

1. **Save to:** the current folder's path, with a Change… button that opens a folder picker.
2. **Label:** a text field, plus a Capture button that is the default action, so Enter in the label field captures.
3. **Preview:** the last capture at half size (400 × 240), with an empty placeholder before the first one.
4. **Status line:** for example "Captured 14:32:05 · saved 2026-11-10 14-32-05 TP4 IF out.png". It shows "Capturing…" while a capture runs and the error in red when one fails.

## Capture behaviour

1. If no save folder is set yet, open the folder picker first. Cancelling it cancels the capture. (The picker also opens on launch while no folder is set.)
2. Disable the Capture button and show "Capturing…", keeping the UI responsive (the USB transfers run off the main thread).
3. Open the scope's USBTMC interface, send `:DISP:DATA?`, read the whole reply, strip the block header to get the BMP, and close the interface.
4. Convert the BMP to PNG in memory.
5. Write `<YYYY-MM-DD HH-MM-SS> <label>.png` into the save folder, or `<YYYY-MM-DD HH-MM-SS>.png` when the label is blank. The timestamp is the capture time in local time.
6. Put the image on the general clipboard. This comes after the write, so a failed write leaves the clipboard untouched.
7. Update the preview and the status line.

On any failure (scope not found on USB, a USB timeout, a malformed reply, or a write error) the clipboard, the preview and the files stay as they were, and the status line shows what failed in red.

## Builder's calls

These are the builder's choices and Dan hasn't reviewed them:

- **App name:** Scope Grab. The repo is `~/Workspaces/scope-grab`.
- **Build:** a Swift package (a `ScopeGrabCore` library for the protocol and filenames, a `ScopeGrab` executable for the UI) with no Xcode project. `build.sh` wraps the release binary and `Support/Info.plist` into `build/Scope Grab.app`, ad-hoc signs it, and with `install` copies it to `~/Applications`.
- **Timeouts:** 5 s per USB transfer.
- **One session per capture:** each capture opens the USB interface and closes it again, so a stuck transfer can't poison the next capture.
- **Label after capture:** the label stays in the field, selected, so typing the next label replaces it and Enter alone reuses it. A reused label gets a new timestamp, so files don't collide. If a file with the exact name already exists (two captures in the same second), append ` 2`, ` 3` and so on.
- **Filename safety:** `/` and `:` in the label become `-`. Surrounding whitespace is trimmed.
- **Settings:** the folder path is stored in UserDefaults. The app isn't sandboxed, so a plain path is enough.
- **Clipboard formats:** both PNG and TIFF go on the clipboard, so any whiteboard app can paste it.
- **No `*IDN?`:** the reference script sends `*IDN?` before capturing, but only to print it. The app sends `:DISP:DATA?` alone, and the real-scope test confirms that works.
- **Tests:** unit tests for the block parser, the filename builder and the USBTMC headers. Live tests run only when `SCOPE_USB` is set, against the scope on USB.
