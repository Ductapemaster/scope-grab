# Scope Grab

A small macOS app that captures the screen of the Rigol DS2072A bench scope over USB in one keystroke. Each capture is copied to the clipboard as an image and saved as a PNG named `<YYYY-MM-DD HH-MM-SS> <label>.png` in a folder you choose. The window shows a preview of the last capture.

## Use

1. Type a label (optional), press Enter.
2. Paste wherever you need the image. The file is already saved.

The save folder is picked at first launch and changed with **Change…**. It's remembered.

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

- `Sources/ScopeGrabCore/`: the scope's USBTMC client (`USBTMC.swift`), the IEEE 488.2 block parser, and the filename builder.
- `Sources/ScopeGrab/App.swift`: the SwiftUI window.
- `Support/Info.plist`: the app bundle's plist, copied in by `build.sh`.
- `tools/make_icon.swift`: draws the app icon into `Support/AppIcon.icns`. Rerun it after changing the drawing.
- `docs/`: the design and the roadmap.

More on the scope: the vault note `3 Reference/Workshop/Rigol DS2072A/Rigol DS2072A.md`.
