# Optional panels: scope settings, measurements, SCPI console

A proposal for three optional interfaces around the capture window. None is built, and each needs Dan's decisions below before it is. The capture flow stays as it is: type a label, press Enter. Everything here is hidden until asked for, and none of it may add a step or a delay to a capture.

## Terms

- **Inspector:** a panel that slides in along the window's right edge and is toggled from a button at the end of the capture bar. It is the macOS counterpart of the scope's own softkey menu on the right of its screen.
- **Shared connection** (`ScopeLink`): one open USB session to the scope that every feature sends through in turn, in place of today's open-capture-close session per capture.
- **Measurement bar:** the row of up to five measurement readouts along the bottom of the scope's screen.
- **Console:** a window for typing SCPI commands at the scope and reading the replies.

## What exists today, and the gap

The app opens the scope's USBTMC interface for each capture and closes it again (`Scope.session` in `Sources/ScopeGrabCore/USBTMC.swift`). That is right for one action every few seconds. Three panels that each talk to the scope, one of them continuously while it is open, need a single owner of the interface: two features opening it at once would fight over the same bulk pipes. So every panel below depends on a shared connection, built first.

## Layout

```
┌───────────────────────────────────────────────────────────────┐
│ ● ● ●                    Scope Grab                           │
│ Save to      File name                                        │
│ [📁 Desktop] [2026-11-11 09-14-02 TP4 .png] ⚙ [Copy] [Capture] ▤│  ▤ toggles the inspector
├──────────────────────────────────────────┬────────────────────┤
│                                          │ Scope │ Measure    │
│                                          │────────────────────│
│         last capture (scope display)     │ CH1  ■ on  2 V/div │
│                                          │ CH2  □ off         │
│                                          │ Time 20 ms/div     │
│                                          │ Trig CH1 ↑ 0.00 V  │
│                                          │ [Run] [Stop] [Sgl] │
├──────────────────────────────────────────┴────────────────────┤
│ 2026-11-10 21-27-04 TP4.png                    ● DS2072A on USB│
└───────────────────────────────────────────────────────────────┘

Window ▸ SCPI Console (⌘K), a separate window:
┌──────────────────┬────────────────────────────────────────────┐
│ 🔍 meas          │ > :MEAS:VPP? CHAN1                          │
│ :MEASure         │ 4.080000e+00                                │
│   :VPP? <src>    │ > :TRIG:STAT?                               │
│   :FREQuency?    │ STOP                                        │
│   …              │ > :DISP:DATA?                               │
│ :TRIGger         │ ‹binary block, 1 152 054 bytes›             │
│   …              │                                             │
│                  │ [ :CHAN1:SCAL 0.5            ] Send ⏎       │
└──────────────────┴────────────────────────────────────────────┘
```

The inspector holds the scope settings and the measurements as two tabs, because both are about the trace on screen and sit naturally beside it. The console is its own window: it's used in bursts, wants width for replies, and shouldn't squeeze the preview.

## 1. Shared connection (prerequisite)

A `ScopeLink` actor in `ScopeGrabCore` owns one `Scope`, opens it on first use, and runs every command through a serial queue.

- On a USB error it closes the interface and reopens it on the next command, which keeps the property today's per-capture session gives (a stuck transfer can't poison the next action).
- It closes the interface when the scope detaches (`ScopeWatcher` already reports that) and when the app quits.
- Capture goes through it like everything else, so a capture never collides with a console command or a settings read.
- Live test: a capture and 20 console queries interleaved from two tasks all succeed.

## 2. SCPI console

The smallest panel and the most useful for exploring the scope, so it comes first.

- A command field with history (↑ and ↓, kept across launches) and a scrolling log of commands and replies.
- A command ending in `?` is sent as a query and its reply is read. Anything else is sent as a write, followed by `:SYST:ERR?`, so a rejected command shows its error, not silence.
- A reply that starts with an IEEE 488.2 block header shows as its size, not as raw bytes.
- A reference sidebar lists the DS2000A command set by subsystem (`:ACQuire`, `:CHANnel<n>`, `:MEASure`, `:TIMebase`, `:TRIGger`, …), searchable. Each entry has the syntax, the argument range and a one-line description. Clicking an entry puts it in the command field.
- The reference ships as a JSON file in the app bundle, built from the *MSO2000A/DS2000A Programming Guide* (PGA18106-1110, May 2019, software 00.03.04.SP2, the revision closest to the scope's 00.03.06). The descriptions are written fresh, not copied from the guide. Its sources and the guide's caveats are in `docs/research/ds2000a-measure-scpi.md`.

## 3. Scope settings (inspector, Scope tab)

The controls Dan reaches for between test points, mirroring the scope's own menus:

- Run, Stop, Single and Auto (`:RUN`, `:STOP`, `:SING`, `:AUToscale`), with the current state from `:TRIG:STAT?`.
- Per channel: on or off, V/div, offset, coupling, probe ratio (`:CHANnel<n>:DISPlay`, `:SCALe`, `:OFFSet`, `:COUPling`, `:PROBe`).
- Timebase: s/div and offset (`:TIMebase:MAIN:SCALe`, `:OFFSet`).
- Trigger: source, slope, level, sweep (`:TRIGger:EDGe:SOURce`, `:SLOPe`, `:LEVel`, `:TRIGger:SWEep`).

The panel reads these when it opens and after each change it makes. It doesn't poll: knobs turned on the scope show after the panel's Refresh button. Steppers move in the scope's own 1-2-5 sequence, so a click does what a knob detent does.

These commands change the bench state on purpose, at Dan's request. The repo guardrail about restoring state applies to the app's own side effects (section 4), not to settings Dan changes by hand.

## 4. Measurements (inspector, Measure tab)

Measurements were ruled out once (`docs/design/scope-grab.md`, Non-goals) for three reasons: a query adds its item to the measurement bar, no command lists the items already on it, and stable values need a STOP/RUN cycle. This proposal works with the first two instead of around them: **the app owns the measurement bar.**

- **Configure:** Dan picks up to five items in the panel (source and type, e.g. CH1 Vpp, CH1 Freq, CH2 Vrms). Applying them sends `:MEAS:CLE ALL`, then each item's set form in order, so the scope's bar shows exactly the app's list and the app always knows what's on it.
- **Capture:** with measurements on, a capture reads the trigger state, stops the scope, waits for `STOP`, grabs the screen, queries each configured item, then restores the prior state (run, stopped, or re-armed single). `docs/research/ds2000a-measure-scpi.md` section 4 gives the restore logic. The screenshot and the numbers come from the same frozen acquisition.
- **Record:** the values go into a CSV next to the captures (see the open decisions), one row per capture, with the filename as the key. Invalid results (≥ 9e37) are written empty.
- **Cost:** the STOP/RUN cycle and five queries add an estimated 0.3 to 0.6 s per capture. That's an estimate to measure on the bench; the panel's on/off switch keeps the plain capture at today's 1.15 s.

Bench checks before building, each one a question the guide leaves open:

- Does querying an item that is already on the bar leave the bar unchanged, or add a duplicate and push the oldest off?
- Do measurement queries return stable values while stopped?
- What does a query on a channel that is turned off return: 9.9e37, or an error in the queue?

## Order

1. Shared connection. Every panel needs it, and it changes how capture talks to the scope, so it lands alone with the live tests.
2. SCPI console. Small, and it doubles as the tool for the bench checks in section 4.
3. Scope settings.
4. Measurements, after the bench checks.

Each is its own branch and can stop there. The plan for any one is written when it's picked up.

## Open decisions for Dan

- **Measurement output:** one `measurements.csv` per save folder, appended per capture (a table of test-point readings in one file), or a sidecar `<capture name>.csv` per capture (travels with the image)? The first suits the Sherwood workflow of probing many points; the second keeps each capture self-contained.
- **Measurements in the filename or label:** off by default. Should a single headline value (e.g. Vpp) be appendable to the filename?
- **Console reference scope:** the whole command set, or the subsystems used on the bench (channel, timebase, trigger, measure, acquire, display) first?
- **Settings refresh:** Refresh button only, or a slow poll (every 2 s) while the inspector is open? Polling keeps the panel true to the knobs but keeps the USB link busy.
