# Roadmap

1. **The scope's LAN is faulty.** It byte-reverses its own IP address and answers nothing over the network, even cabled straight to the Mac. Initializing its LAN settings and power cycling don't clear it. Next: reflash the firmware (newest DS2000A build, or 00.03.06 again) from a USB stick. If that fails, it's a repair job. The app captures over USB meanwhile.
2. **Pick the whiteboard app** the captures get pasted into. Separate from this repo, but it may change what goes on the clipboard.
3. **Optional panels:** a shared USB connection, then an SCPI console with a command reference, a scope-settings inspector, and measurements recorded with each capture. Proposal and open decisions: `docs/research/optional-panels.md`.
