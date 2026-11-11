# Scope Grab

A small macOS app that captures the screen of the Rigol DS2072A bench scope over USB in one keystroke and shows it. Save it, and it lands as a PNG named `<YYYY-MM-DD HH-MM-SS> <label>.png` in a folder you choose.

## Use

1. Press Enter (or ⌘R) to capture the scope's screen into the window.
2. If it's the trace you want, type a label (optional) and press ⌘S (or **Save**). The **File name** field shows the exact name it gets, and the bar at the bottom says where it was saved (click it to show the file in Finder).
3. To use it elsewhere, press **Copy** (⇧⌘C) and paste, or drag the preview into a folder or app. Right-click the preview for Copy Image and Show in Finder.

The save folder is picked at the first save and remembered. **Save to** at the top left shows where captures go (`… › parent › folder`); click it to change the folder, or its chevron to see the full path. The file name pattern (`{date} {time} {label}` by default) is changed in Settings (⌘,), for example to `{label} {date} {time}` to sort by test point.

The scope connects over USB (the rear USB Device port to the Mac), with Utility → IO Setting → USB Device set to Computer. The app finds it on its own.

## Build

```bash
./build.sh install
```

This builds `build/Scope Grab.app` and copies it to `~/Applications`. It needs Xcode or the Swift toolchain (Swift 5.10+), macOS 14+.

## Test

```bash
swift test
```

```bash
SCOPE_USB=1 swift test
```

The first runs the unit tests. The second adds live capture tests against the scope on USB.

## Layout

- `Sources/ScopeGrabCore/`: the scope's USBTMC client (`USBTMC.swift`), the IEEE 488.2 block parser, and the file name pattern (`Filename.swift`), and the folder trail (`PathTrail.swift`).
- `Sources/ScopeGrab/`: the SwiftUI app. `CaptureModel.swift` holds the state and actions; `App.swift` (window, menus), `CaptureBar.swift` (file name, Copy, Save, Capture, and Settings), `FolderControl.swift` (Save to), `ScreenView.swift` (the preview) and `StatusBar.swift` lay them out.
- `Support/Info.plist`: the app bundle's plist, copied in by `build.sh`.
- `tools/make_icon.swift`: draws the app icon into `Support/AppIcon.icns`. Rerun it after changing the drawing.
- `docs/`: the design and the roadmap.

More on the scope: the vault note `3 Reference/Workshop/Rigol DS2072A/Rigol DS2072A.md`.

## License

MIT. See `LICENSE`.
