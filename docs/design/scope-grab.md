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

- USB. LAN only for now. USB needs libusb, the scope's USB Device = Computer setting, and a cable-order rule, all for a 0.5 s gain per shot.
- Any SCPI beyond the screen capture: no scope control, waveform data, or settings.
- A capture history or gallery. The folder is the history.
- Burning a timestamp or label into the image.
- Picking or integrating with the whiteboard app.

## Anti-goals

- Anything that makes a capture slower than typing a label and pressing Enter: confirmation dialogs, a save sheet per capture, required fields.
- A failed capture that looks like a success: a stale clipboard or preview with no visible error.

## Constraints and facts

- Scope: Rigol DS2072A, firmware 00.03.06, on the LAN at 192.168.0.114 (DHCP, with Auto IP off; see the vault note `3 Reference/Workshop/Rigol DS2072A/Rigol DS2072A.md`).
- Protocol: a raw SCPI socket on TCP 5555, with commands terminated by `\n`. `:DISP:DATA?` returns an IEEE 488.2 definite-length block: `#`, one digit N, N digits giving the byte count, the data, then a trailing `\n`. The data is an 800 × 480 24-bit BMP, about 1.1 MB. One capture takes about 1.6 s over this socket.
- Reference implementation: `open_scope()`, `screenshot()` and `read_ieee_block()` in `3 Reference/Workshop/Rigol DS2072A/rigol_scpi.py` in the vault.
- Platform: macOS 27, Apple Silicon, Swift 6.4 command-line toolchain. Personal use on one machine, not distributed.

## Decided with Dan

- **Toolkit:** a native Swift (SwiftUI) app, not Python. The clipboard image, BMP → PNG conversion, folder picker, remembered settings and Dock launching are all built into macOS.
- **Connection:** LAN only, with the scope IP in an editable field that defaults to 192.168.0.114.
- **Outputs:** every capture goes both to the clipboard and to a file.
- **Label:** typed before capturing, used in the filename only. The clipboard image is just the screen.
- **Save folder:** picked at first launch, shown in the window and changeable from there at any time, and sticky across captures and launches. Files go directly into the chosen folder. Dan makes subfolders himself when he wants them.
- **Preview:** the last capture is shown in the window.
- **Timestamp:** shown in the app window with the preview (Dan said "on the screen", read as the window, not drawn on the image).

## Window

A single small window, top to bottom:

1. **Scope:** the IP field.
2. **Save to:** the current folder's path, with a Change… button that opens a folder picker.
3. **Label:** a text field, plus a Capture button that is the default action, so Enter in the label field captures.
4. **Preview:** the last capture at half size (400 × 240), with an empty placeholder before the first one.
5. **Status line:** for example "Captured 14:32:05 · saved 2026-11-10 14-32-05 TP4 IF out.png". It shows "Capturing…" while a capture runs and the error in red when one fails.

## Capture behaviour

1. If no save folder is set yet, open the folder picker first. Cancelling it cancels the capture. (The picker also opens on launch while no folder is set.)
2. Disable the Capture button and show "Capturing…", keeping the UI responsive (the network read runs off the main thread).
3. Open a TCP connection to `<ip>:5555`, send `:DISP:DATA?\n`, read the block header, read exactly the stated number of bytes, then read the trailing `\n`, and close the connection.
4. Convert the BMP to PNG in memory.
5. Write `<YYYY-MM-DD HH-MM-SS> <label>.png` into the save folder, or `<YYYY-MM-DD HH-MM-SS>.png` when the label is blank. The timestamp is the capture time in local time.
6. Put the image on the general clipboard. This comes after the write, so a failed write leaves the clipboard untouched.
7. Update the preview and the status line.

On any failure (connection refused, timeout, a malformed block, or a write error) the clipboard, the preview and the files stay as they were, and the status line shows what failed in red.

## Builder's calls

These are the builder's choices and Dan hasn't reviewed them:

- **App name:** Scope Grab. The repo is `~/Workspaces/scope-grab`.
- **Build:** a Swift package (a `ScopeGrabCore` library for the protocol and filenames, a `ScopeGrab` executable for the UI) with no Xcode project. `build.sh` wraps the release binary and `Support/Info.plist` into `build/Scope Grab.app`, ad-hoc signs it, and with `install` copies it to `~/Applications`.
- **Local network permission:** macOS asks before an app connects to a LAN address, so the Info.plist carries `NSLocalNetworkUsageDescription`. The first capture triggers the system prompt once.
- **Timeouts:** 3 s to connect, 10 s for the whole read.
- **Label after capture:** the label stays in the field, selected, so typing the next label replaces it and Enter alone reuses it. A reused label gets a new timestamp, so files don't collide. If a file with the exact name already exists (two captures in the same second), append ` 2`, ` 3` and so on.
- **Filename safety:** `/` and `:` in the label become `-`. Surrounding whitespace is trimmed.
- **Settings:** the IP and the folder path are stored in UserDefaults. The app isn't sandboxed, so a plain path is enough.
- **Clipboard formats:** both PNG and TIFF go on the clipboard, so any whiteboard app can paste it.
- **No `*IDN?`:** the reference script sends `*IDN?` before capturing, but only to print it. The app sends `:DISP:DATA?` alone, and the real-scope test confirms that works.
- **Tests:** unit tests for the block parser, the filename builder and the connection failure paths. Live tests run only when `SCOPE_HOST` is set, against the real scope or `tools/fake_scope.py`, which serves a test-pattern BMP on 127.0.0.1:5555.
