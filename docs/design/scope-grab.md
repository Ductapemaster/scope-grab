# Scope Grab: design

A small native macOS app that captures the screen of the bench oscilloscope (Rigol DS2072A) in one keystroke, shows it, and saves it as a PNG on request, ready to copy or drag into other apps.

## Why

Dan is restoring an old analog receiver (the Sherwood S-7100A, notes in the vault at `1 Projects/2026 Sherwood 7100A Amp Repair/`). The workflow is: probe a test point, grab the scope screen, drop the image onto a whiteboard next to the open schematic, and move on to the next point. The whiteboard app isn't chosen yet and is out of scope here. What it needs from this tool is an image it can paste or drop in.

A capture already works from the terminal (`rigol_scpi.py --screenshot`). But typing a command and a filename at every test point is too much friction, and the script doesn't touch the clipboard.

Success: Dan presses Enter, and within about 2 s the preview shows the trace he's looking at. If it's the one he wants, ⌘S saves it into the project folder under a name carrying the label he typed; Copy or a drag puts it in another app.

## Goals

- One action (Enter or a click) captures the screen into the preview. One more (⌘S or Save) writes the file, so a wrong trace never lands in the folder.
- One more action gets the capture into another app: Copy (⇧⌘C), or dragging the preview.
- An optional label per capture, used only in the filename.
- A save folder chosen at the first save, changeable any time, and remembered between captures and launches.
- A preview of the last capture, plus the time it was captured.

## Non-goals

- LAN. This scope's network stack is faulty: it byte-reverses its own IP address (cabled straight to the Mac as `10.0.0.2`, it sends ARP as `2.0.0.10`) and answers nothing at the IP level, not even ARP for either address. Initializing the LAN settings and power cycling don't clear it.
- Any SCPI beyond the screen capture: no scope control, waveform data, or settings.
- Reading measurements over SCPI. Measurements switched on at the scope show in its measurement bar, so the screenshot records them. Reading them over SCPI was ruled out: querying an item adds it to that bar, no command lists the items already on it, and stable values need a STOP/RUN cycle around the capture.
- A capture history or gallery. The folder is the history.
- Burning a timestamp or label into the image.
- Picking or integrating with the whiteboard app.

## Anti-goals

- Anything that makes capturing and saving slower than Enter then ⌘S: confirmation dialogs, a save sheet per capture, required fields.
- A failed capture that looks like a success: a stale preview with no visible error.

## Constraints and facts

- Scope: Rigol DS2072A, firmware 00.03.06, on USB with Utility → IO Setting → USB Device set to Computer.
- Transport: USBTMC (USB Test & Measurement Class). The scope enumerates as vendor 0x1AB1, product 0x04B0, with interface 0 of class FE/03/01, bulk-out endpoint 0x02 and bulk-in endpoint 0x86. macOS has no driver for that interface, so the app opens it from user space through Apple's IOUSBHost framework, with no libusb. Each command goes out as a USBTMC message with a 12-byte header. Each reply is fetched with a request message, and a reply larger than one transfer arrives as one header followed by raw chunks.
- Protocol: SCPI, with commands terminated by `\n`. `:DISP:DATA?` returns an IEEE 488.2 definite-length block: `#`, one digit N, N digits giving the byte count, the data, then a trailing `\n`. The data is an 800 × 480 24-bit BMP, about 1.1 MB. One capture takes about 1.15 s over USB.
- Reference implementation: `open_scope()`, `screenshot()` and `read_ieee_block()` in `3 Reference/Workshop/Rigol DS2072A/rigol_scpi.py` in the vault.
- Platform: macOS 27, Apple Silicon, Swift 6.4 command-line toolchain. Personal use on one machine, not distributed.

## Decided with Dan

- **Toolkit:** a native Swift (SwiftUI) app, not Python. The clipboard image, BMP → PNG conversion, folder picker, remembered settings and Dock launching are all built into macOS.
- **Connection:** USB, chosen once the scope's LAN proved faulty. The app finds the scope on its own, so the window has no connection setting.
- **Outputs:** a capture is held in the window until Dan saves it, so only the traces he keeps reach the folder. The clipboard is touched only on request: capturing never overwrites what Dan has copied.
- **Label:** typed before capturing, used in the filename only. A copied image is just the screen.
- **Color:** Capture and the save folder are the two colored controls, since a capture depends on both: Capture filled as the main action, the folder tinted.
- **Save folder:** picked at the first save, shown in the capture bar and changeable from there at any time, and sticky across captures and launches. Files go directly into the chosen folder. Dan makes subfolders himself when he wants them.
- **Preview:** the last capture is shown in the window.
- **Timestamp:** shown in the app window with the preview (Dan said "on the screen", read as the window, not drawn on the image).

## Window

A single window, top to bottom:

1. **Capture bar:** a row that reads left to right as save here, under this name, then the actions: Save goes with the folder and name it uses.
   - **Save to:** the save folder as a short trail, `… › parent › folder`, in an accent-tinted control. The folder's own name always shows; the outer parts give way first (`… › folder`, then the name alone, cut in the middle only past about 240 pt). The home folder reads `~`. Clicking the trail opens the folder picker. The chevron beside it opens the full path, one folder per line, each opening in Finder, plus Copy Path and Change Save Folder…. The tooltip gives the full path too.
   - **File name:** the name Save will give the capture, with the label typed in place: for example `2026-11-10 14-32-05` in grey, then the label, then `.png` in grey. The date and time are the capture's, frozen while it's unsaved; before a capture and after a save they tick with the clock. The label can be typed before or after capturing. A sliders button beside it opens Settings, where the pattern is changed.
   - **Save** (⌘S) beside the file name it uses, then **Copy** (⇧⌘C), both plain bordered buttons, then **Capture** at the far right, filled in the accent color as the main action. Capture is the default action, so Enter captures from anywhere in the window. Save is enabled while the capture is unsaved.
2. **Preview:** the last capture, framed like the scope's own display and scaled to fill the window at the screen's 5:3 shape. The window's height follows its width, so the frame has the same 20 pt margin on all four sides; after a resize the height settles to match (it waits for the drag to end rather than fighting it). Before the first capture it shows the DS2000A's empty 14 × 8 graticule with a sine trace and "Press Return to capture the scope's screen", or an unplugged-cable icon and "Connect the scope over USB" while no scope is attached. A new capture flashes the frame briefly, unless Reduce Motion is on. Dragging the preview drags the image: dropping it on a folder makes a PNG under the name in the File name field (or the saved file's name), and dropping it on an app inserts the image. Right-click offers Copy Image, Save and Show in Finder.
3. **Status bar:** the last action taken, and nothing before the first: "Capturing…", "Captured 8:19:19 AM", "Saved to `~/Bench/Captures/2026-11-10 14-32-05 TP4 IF out.png`" (the folder dimmed and cut in the middle when long, the filename in full; clicking it shows the file in Finder), or "Copied … to the clipboard". A failure shows in red. The right end always shows whether the scope is on USB ("DS2072A on USB" or "No scope on USB"), updated live from macOS's attach and detach notifications.

**Settings** (⌘,) holds the file name pattern, with an example rendered from it and a Restore Default button.

The menu bar carries the same actions:

- File: Capture Screen (⌘R), Save Capture (⌘S), Change Save Folder… (⇧⌘O), Open Save Folder.
- Edit: Copy Capture (⇧⌘C), Show Capture in Finder (⇧⌘R).

## Capture and save

Capture:

1. Disable the Capture button and show "Capturing…", keeping the UI responsive (the USB transfers run off the main thread).
2. Open the scope's USBTMC interface, send `:DISP:DATA?`, read the whole reply, strip the block header to get the BMP, and close the interface.
3. Convert the BMP to PNG in memory, and show it in the preview. The capture time is kept for the filename. Nothing is written.

A new capture replaces an unsaved one without asking.

Save:

1. If no save folder is set yet, open the folder picker first. Cancelling it cancels the save.
2. Write the PNG into the save folder, named by the file name pattern (default `{date} {time} {label}`, giving `2026-11-10 14-32-05 TP4 IF out.png`), with the capture's date and time in local time and the label as it is when saving.
3. Disable Save until the next capture.

On any failure (scope not found on USB, a USB timeout, a malformed reply, or a write error) the preview and the files stay as they were, and the status bar shows what failed in red.

## Builder's calls

These are the builder's choices and Dan hasn't reviewed them:

- **App name:** Scope Grab. The repo is `~/Workspaces/scope-grab`.
- **Build:** a Swift package (a `ScopeGrabCore` library for the protocol and filenames, a `ScopeGrab` executable for the UI) with no Xcode project. `build.sh` wraps the release binary and `Support/Info.plist` into `build/Scope Grab.app`, ad-hoc signs it, and with `install` copies it to `~/Applications`.
- **Timeouts:** 5 s per USB transfer.
- **One session per capture:** each capture opens the USB interface and closes it again, so a stuck transfer can't poison the next capture.
- **Label after capture and save:** the label stays in the field, selected, so typing the next label replaces it and Enter alone reuses it. A reused label gets a new timestamp, so files don't collide. If a file with the exact name already exists (two saves of captures from the same second), append ` 2`, ` 3` and so on.
- **File name pattern:** `{date}` (`2026-11-10`), `{time}` (`14-32-05`) and `{label}`, in any order with any separators, set in Settings and stored in UserDefaults (`filenameTemplate`). A pattern without `{label}` gets ` {label}` appended, so a typed label is never dropped. With a blank label, separators left at either end are trimmed (`{date}_{label}` gives `2026-11-10.png`); a pattern that renders empty falls back to `{date} {time}`.
- **Filename safety:** `/` and `:` in the label or pattern become `-`. Surrounding whitespace is trimmed.
- **Settings:** the folder path and the file name pattern are stored in UserDefaults. The app isn't sandboxed, so a plain path is enough.
- **Copy:** a button beside Capture and the Edit menu's Copy Capture (⇧⌘C) rather than plain ⌘C, which the label field keeps for copying text. Copy works before saving: it puts the capture's PNG and a TIFF on the clipboard, so any whiteboard app can paste it.
- **Drag:** a saved capture drags its file; an unsaved one drags the image with the pending file name as its suggested name, so a drop into Finder never gets "PNG image.png".
- **Save shortcut:** ⌘S, the macOS convention. Return stays on Capture, so the bench rhythm is Enter to look, ⌘S to keep.
- **No unsaved-capture prompt:** a new capture or quitting drops an unsaved capture silently, since the scope still shows the trace and re-capturing takes a second.
- **No `*IDN?`:** the reference script sends `*IDN?` before capturing, but only to print it. The app sends `:DISP:DATA?` alone, and the real-scope test confirms that works.
- **Look:** native macOS controls in a capture bar, a status bar on the window's bottom edge, and menu-bar commands, around one distinctive element: the preview framed as the scope's display. The empty graticule and its sine trace echo the app icon. The controls sit in a row of their own rather than the title-bar toolbar, because macOS drew the toolbar's Capture button uncolored and left it short of the window's trailing edge.
- **Capture shortcut:** ⌘R in the menu, alongside Return in the window.
- **State:** one `CaptureModel` (`Sources/ScopeGrab/CaptureModel.swift`) holds the window's state and actions, so the capture bar, the status bar and the menu bar share them.
- **Layout checks:** a debug build started with `SCOPEGRAB_PREVIEW=<png>` shows that file as the last capture, to check the layout without the scope. Release builds ignore it.
- **Tests:** unit tests for the block parser, the filename builder and the USBTMC headers. Live tests run only when `SCOPE_USB` is set, against the scope on USB.
