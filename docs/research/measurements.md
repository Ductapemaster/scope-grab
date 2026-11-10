# Rigol DS2000A: measurement queries around a frozen screenshot

Research notes for the "capture measurements with the screenshot" feature (DS2072A, firmware 00.03.06, raw SCPI on TCP 5555).

## Bench results on this scope

These were measured on 2026-11-10 with CH1 on (a 1.8 mVpp ripple at 10 ms/div), CH2 off, and AUTO sweep. `Scope.frozenCapture()` in `Sources/ScopeGrabCore/Measure.swift` implements the working sequence, and the live test `frozenCaptureReadsStableValuesAndRestoresRunState` checks it. `tools/probe_measure.py` reproduces the stopped-enable failure below.

Working sequence:

1. Read `:TRIG:STAT?` and `:TRIG:SWE?`, and `:CHAN<n>:DISP?` for each channel.
2. While the scope is still running, query each wanted item once on each channel that is on. This enables the items.
3. Send `:STOP` then `*OPC?`. `:TRIG:STAT?` reads `STOP` on the first poll, about 0.12 s after `:STOP`.
4. Capture the screen with `:DISP:DATA?`, in about 1.6 s.
5. Query the items again. Each read takes about 4 ms, and repeated reads return identical values, because they measure the frozen waveform.
6. Send `:RUN`, or `:SING` if the sweep was single.

The cycle adds about 0.3 s to a capture, plus about 0.1 s per item enabled in step 2.

Findings:

- **An item first enabled while stopped answers once, then 9.9e37.** With the measurement bar cleared (`:MEAS:CLE ALL`) and the scope stopped, the first read of each item was valid and took 25 to 75 ms to compute. Every later read returned `9.9e37`, 2 of 2 trials. Items enabled while running and then read while stopped stayed valid on every read, 3 of 3 trials, with settle times of 0, 0.3 and 1 s. That's why step 2 exists.
- **The stopped values match the screenshot.** The measurement bar in the screenshot read Vpp=1.840mV, Freq=57.14 Hz, Avg=646.7uV, Vrms=795.3uV. The stopped queries returned 1.840000e-03, 5.714286e+01, 6.467145e-04 and 7.952911e-04.
- **Enabling items puts them on screen.** Each enabled item appears in the measurement bar at the bottom of the screen, so step 2 makes the measurements visible in the screenshot. An item that can't be measured shows as `*****`.
- **An off channel returns 9.9e37** (`:MEAS:VPP? CHAN2` with CH2 off), with nothing in `:SYST:ERR?`.
- **One connection at a time.** Two SCPI socket connections open at once stalled the scope until both timed out.
- **The LAN link drops out.** During this session the scope stopped answering ping for 3 to 30 s at a time, every few seconds to a few minutes, with no SCPI traffic running. A capture during a dropout times out. The cause isn't established. The vault note links this kind of behaviour to Auto IP being on.

## Sources

- **[G2019]** RIGOL *MSO2000A/DS2000A Programming Guide*, May 2019, PGA18106-1110, written for software 00.03.04.SP2, the closest revision to 00.03.06. Copy: https://cdn-aorpci9.actonsoftware.com/acton/cdna/1579/f-0508/1/9/MSO2000A%26DS2000A_ProgrammingGuide.pdf (Rigol's Act-On CDN). The eu.rigol.com URL search engines list (`MSODS2000AProgrammingGuideEN_tcm30-2899.pdf`) now redirects to rigol.com/europe.
- **[G2013]** RIGOL *DS2000A Programming Guide*, Jul. 2013, PGA16101-1110, the original revision. Copy: https://www.batronix.com/pdf/Rigol/ProgrammingGuide/DS2000A_ProgrammingGuide_EN.pdf
- **[sigrok]** libsigrok `rigol-ds` driver, `protocol.c`: https://github.com/sigrokproject/libsigrok/blob/master/src/hardware/rigol-ds/protocol.c (PROTOCOL_V3 is the DS2000 path).
- **[kmutnb]** A Python DS2072A-over-LAN write-up: https://iot-kmutnb.github.io/blogs/electronics/rigol_scope_ds2000_lxi

Caution: the Act-On file `.../f-0386/.../DS2000A_ProgrammingGuide_EN.pdf` on beyondmeasure.rigoltech.com is mislabeled. It is the DS1000Z guide, the one with `:MEASure:ITEM?`.

Labels: **Documented** means stated in the cited guide. **Inferred** means reasoned from the docs or code, not stated. **Not found** means searched for and absent.

## 1. Command syntax and item names

**Documented [G2019 §:MEASure Commands, pp. 2-151 to 2-221]:** each measurement is its own header that takes the source as an argument. There is no `:MEASure:ITEM?` on this series. That form belongs to the DS1000Z.

```
:MEASure:VPP? CHANnel1          -> 4.080000e+00
:MEASure:FDELay? CHANnel1,CHANnel2
```

- Short form: `:MEAS:VPP? CHAN1`. Standard SCPI abbreviation applies throughout the guide (example `:MEAS:ADIS?`). Each header also has a set form (`:MEASure:VPP CHANnel1`) that only turns the item on.
- Source range for the voltage items is `{CHANnel1|CHANnel2|MATH}`. The time items also accept `D0` to `D15` (MSO only). G2013 listed only `{CHANnel1|CHANnel2}`, so MATH as a source arrived in a later firmware.
- Single-source items:
  - Voltage: `VMAX`, `VMIN`, `VPP`, `VTOP`, `VBASe`, `VAMP`, `VAVG`, `VRMS`, `PVRMs` (period RMS), `OVERshoot`, `PREShoot`.
  - Time: `PERiod`, `FREQuency`, `RTIMe`, `FTIMe`, `PWIDth`, `NWIDth`, `PDUTy`, `NDUTy`.
  - Area: `MARea` (area), `MPARea` (period area).
- Two-source items (`<chanA>,<chanB>`):
  - Delay: `RDELay`, `FDELay`, `R2FDelay`, `F2RDelay`.
  - Phase: `RPHase`, `FPHase`, `R2FPhase`, `F2RPhase`.
- Statistics variants: every item also has `:SMAXimum?`, `:SMINimum?`, `:SCURrent?`, `:SAVerage?`, `:SDEViation?` (for example `:MEASure:VPP:SAVerage? CHANnel1`). These also turn the statistics function on.
- Related settings: `:MEASure:AREA {SCReen|CREGion}` sets the measurement range. The default `SCReen` measures the waveform within the screen, so values match the screenshot. `:MEASure:SETup:MAX/MID/MIN` set the threshold percentages that rise time, delay and the others use.

## 2. Invalid result and number format

- **Documented [G2019, each query's Return Format]:** "When the measurement result is invalid, the query returns 9.9e37." This sentence appears 60 times in G2019, once per query. G2013 does not state it.
- **Documented:** valid results come back in scientific notation, for example `4.080000e+00`, in the source channel's units (`:CHANnel<n>:UNITs`). Frequency is in Hz, time items in s.
- **Inferred:** parse the reply as a float and treat anything at or above about 9e37 as "no value". Don't test for exact equality with 9.9e37. Agilent's sample code uses the same threshold convention.

## 3. Query for the measurements currently on screen

**Not found.** No command in G2019 returns which items are displayed. What does exist:

- `:MEASure:CLEar {ITEM1..ITEM5|ALL}` and `:MEASure:RECover {ITEM1..ITEM5|ALL}` are set-only, with no query form. ITEM1 to ITEM5 are "the last five measurement items that are enabled", in enable order, and the last one enabled is ITEM5.
- `:MEASure:ADISplay?` reports only whether the all-measurement view is on (1 or 0).
- `:MEASure:STATistic:DISPlay?` reports only whether statistics are on.
- `:MEASure:SOURce?` returns the current measurement source (CHAN1, CHAN2, MATH, D0 to D15).
- `:MEASure:ITEM?` and `:MEASure:STATistic:ITEM?` exist only on the DS1000Z.

**Documented gotcha [G2019 per item, G2013 p. 2-247]:** a query such as `:MEASure:VPP? <chan>` is described as "Enable the ... measurement function of the specified channel and return the measurement result". G2013 adds: "the command will enable the corresponding measurement item automatically." So every query adds that item to the on-screen measurement bar and pushes out the oldest of the five.

- **Inferred:** the planned order (`:DISP:DATA?` before the measurement queries) keeps the screenshot clean. The queries still change the user's measurement bar afterwards.
- **Inferred:** the app cannot read and later restore the user's own item set. The only option is `:MEAS:CLEar`, which is blunt.
- **Inferred alternative:** the app can't know which values appear in the screenshot, so it needs a fixed item list of its own, or OCR of the BMP.

## 4. Run state

**Documented [G2019 pp. 2-2, 2-3, 2-288]:**

- `:RUN` and `:STOP` act the same as the front-panel RUN/STOP key. They are "invalid when waveform recording or waveform playback is turned on."
- `:SINGle` sets single-trigger mode, which triggers once and then stops. `:TFORce` forces a trigger.
- `:TRIGger:STATus?` returns `TD`, `WAIT`, `RUN`, `AUTO`, or `STOP`. The sigrok source comment says it can also return `T'D`, so match on the first character.
- `:TRIGger:SWEep?` returns the trigger mode, `AUTO`, `NORMal` or `SINGle`.
- The `:SINGle` entry says ":RUN and :STOP" set the scope "to Auto trigger mode and STOP state respectively".

**Not found:** a dedicated run/stop state query. `:TRIGger:STATus?` serves as one. `STOP` means stopped, and any other value means acquiring. Both [kmutnb] (`is_stopped()` checks `TRIG:STAT? == 'STOP'`) and [sigrok] (`rigol_ds_stop_wait()` waits for 'S') use it this way.

**Inferred restore logic:**

- Read `:TRIG:STAT?` and `:TRIG:SWE?` before `:STOP`.
- If the status was `STOP`, leave the scope stopped.
- If the sweep was `SING` and the status was `WAIT`, re-arm with `:SING`. A plain `:RUN` would leave single mode, going by the `:SINGle` explanation above.
- Otherwise send `:RUN`.

## 5. Measuring while stopped, and timing

- **Not found:** an explicit statement in G2019 that measurement queries work while stopped.
- **Bench:** they do, provided the item was enabled before `:STOP` (Bench results above).
- **Documented [G2019, IEEE488.2 common commands, *OPC]:** `*OPC?` returns 1 when the current operation is finished.
- **Documented [sigrok `rigol_ds_config_set()`]:** for non-DS1000 protocols the driver uses `*OPC?` after commands. Its 100 ms fixed delay ("*OPC? doesn't work") applies only to the DS1000 path, so on DS2000 `*OPC?` is the working sync.
- **Bench:** `:STOP`, then `*OPC?`, then poll `:TRIG:STAT?` until it reads `STOP` (first poll, with a 3 s timeout like sigrok's), then `:DISP:DATA?`, then the measurements.
- **Not found** in the guide: what a query on a channel that is turned off returns. On the bench it returns 9.9e37 with no error queued.
- **Documented [sigrok `rigol_ds_check_stop()`]:** on DS2000, an "Execution error" after `:SING` means the scope went from Single to Stop without triggering. This only matters if the app uses `:SING`.

## 6. `:DISP:DATA?` parameters

**Documented [G2019 p. 2-109, G2013 p. 2-178]:** syntax is `:DISPlay:DATA?` with no parameters.

- The reply is a TMC block header `#9001152054` followed by a 24-bit 800x480 BMP (1,152,054 bytes, including the 54-byte BMP header).
- The guide says to strip the header and the trailing `\n` (0x0A), and to set a long enough timeout for data over 1 MB.
- **Not found:** any format or colour argument of the kind later Rigol series take (`:DISP:DATA? ON,OFF,PNG`). Don't send one to this scope.
