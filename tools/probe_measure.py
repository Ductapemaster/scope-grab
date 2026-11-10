#!/usr/bin/env python3
"""Bench probe for the measurements feature: stop, capture, measure, restore.

Answers, on the real scope:
- how long :STOP takes to settle, and how long the whole cycle adds;
- whether measurement queries work while stopped and are stable (two reads match);
- what an off channel returns;
- whether querying a measurement changes the screen (compares screenshots);
- whether the run state is restored.

  ./tools/probe_measure.py 192.168.0.114 OUTDIR

Querying a measurement adds it to the scope's measurement bar (programming
guide), so this changes what's on screen. Items probed: CH1 VPP, FREQ, VAVG,
VRMS; CH2 VPP. The run state is restored even if the link drops mid-probe.
"""
import socket
import sys
import time
from pathlib import Path

HOST = sys.argv[1] if len(sys.argv) > 1 else "192.168.0.114"
OUT = Path(sys.argv[2] if len(sys.argv) > 2 else ".")
OUT.mkdir(parents=True, exist_ok=True)


class Conn:
    def __init__(self):
        self.s = socket.create_connection((HOST, 5555), timeout=10)
        self.f = self.s.makefile("rb")

    def send(self, cmd):
        self.s.sendall(cmd.encode() + b"\n")

    def q(self, cmd):
        self.send(cmd)
        return self.f.readline().decode().strip()

    def screen(self, name):
        t = time.time()
        self.send(":DISP:DATA?")
        assert self.f.read(1) == b"#"
        n = int(self.f.read(int(self.f.read(1))))
        data = self.f.read(n)
        self.f.read(1)
        (OUT / f"{name}.bmp").write_bytes(data)
        return data, time.time() - t


def log(*a):
    print(*a, flush=True)


def restore(c, state0, sweep0):
    """Puts the run state back, reconnecting if the link dropped."""
    if state0 == "STOP":
        log("restore: scope was stopped before, leaving it stopped")
        return
    cmd = ":SING" if sweep0.startswith("SING") else ":RUN"
    for attempt in range(10):
        try:
            c.send(cmd)
            c.q("*OPC?")
            time.sleep(0.3)
            log(f"restore ({cmd}): status now {c.q(':TRIG:STAT?')} sweep {c.q(':TRIG:SWE?')}")
            return
        except OSError as e:
            log(f"restore attempt {attempt + 1} failed: {e!r}; reconnecting")
            time.sleep(2)
            try:
                c = Conn()
            except OSError:
                pass
    log("RESTORE FAILED: the scope may be left stopped")


def probe(c, t0):
    c.send(":STOP")
    opc = c.q("*OPC?")
    polls = 0
    while (st := c.q(":TRIG:STAT?")) != "STOP" and time.time() - t0 < 3:
        polls += 1
    log(f":STOP settled: status={st} *OPC?={opc} polls={polls} in {time.time() - t0:.3f} s")

    stopped, dt = c.screen("2-stopped-before-measure")
    log(f"screen while stopped: {dt:.2f} s")

    items = ["VPP", "FREQuency", "VAVG", "VRMS"]
    for rnd in (1, 2):
        t = time.time()
        vals = {i: c.q(f":MEAS:{i}? CHAN1") for i in items}
        log(f"CH1 round {rnd} ({time.time() - t:.3f} s): {vals}")
    log("CH1 err queue:", c.q(":SYST:ERR?"))

    log("CH2 display:", c.q(":CHAN2:DISP?"))
    log("CH2 VPP:", c.q(":MEAS:VPP? CHAN2"), "| err:", c.q(":SYST:ERR?"))

    after, _ = c.screen("3-stopped-after-measure")
    diff = sum(a != b for a, b in zip(stopped, after))
    log(f"bytes differing between stopped screenshots before/after queries: {diff}")
    log(f"stop→measure cycle: {time.time() - t0:.2f} s")


def main():
    c = Conn()
    log("IDN:", c.q("*IDN?"))
    state0, sweep0 = c.q(":TRIG:STAT?"), c.q(":TRIG:SWE?")
    log(f"initial trigger status={state0} sweep={sweep0}")
    _, dt = c.screen("1-running")
    log(f"screen while running: {dt:.2f} s")

    t0 = time.time()
    try:
        probe(c, t0)
    except OSError as e:
        log(f"probe interrupted: {e!r}")
    finally:
        restore(c, state0, sweep0)
        log(f"whole cycle: {time.time() - t0:.2f} s")


if __name__ == "__main__":
    main()
