# Scope Grab

A small macOS app that captures the screen of the Rigol DS2072A bench scope over the LAN in one keystroke. Each capture is copied to the clipboard as an image and saved as a PNG named `<YYYY-MM-DD HH-MM-SS> <label>.png` in a folder you choose. The window shows a preview of the last capture.

## Use

1. Type a label (optional), press Enter.
2. Paste wherever you need the image. The file is already saved.

The save folder is picked at first launch and changed with **Change…**. It's remembered, and so is the scope IP (default 192.168.0.114). The first capture triggers macOS's Local Network permission prompt once.

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
SCOPE_HOST=192.168.0.114 swift test
```

The first runs the unit tests. The second adds live capture tests against the scope. Without the scope, run `tools/fake_scope.py` and use `SCOPE_HOST=127.0.0.1`.

## Layout

- `Sources/ScopeGrabCore/`: the scope's SCPI socket client (`Scope.swift`), the IEEE 488.2 block parser, and the filename builder.
- `Sources/ScopeGrab/App.swift`: the SwiftUI window.
- `Support/Info.plist`: the app bundle's plist, copied in by `build.sh`.
- `tools/fake_scope.py`: a stand-in scope for testing.
- `docs/`: the design and the roadmap.

Scope connection setup (Auto IP off, the SCPI socket on TCP 5555): the vault note `3 Reference/Workshop/Rigol DS2072A/Rigol DS2072A.md`.
