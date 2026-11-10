#!/bin/bash
# Builds "Scope Grab.app" into build/. With `install`, also copies it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --product ScopeGrab
bin="$(swift build -c release --show-bin-path)/ScopeGrab"

app="build/Scope Grab.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin" "$app/Contents/MacOS/ScopeGrab"
cp Support/Info.plist "$app/Contents/Info.plist"
# Ad-hoc signature: enough for a local app, and it gives macOS a stable identity
# for the Local Network permission.
codesign --force --sign - "$app"
echo "built $app"

if [[ "${1:-}" == "install" ]]; then
    rm -rf ~/Applications/"Scope Grab.app"
    mkdir -p ~/Applications
    cp -R "$app" ~/Applications/
    echo "installed ~/Applications/Scope Grab.app"
fi
