#!/usr/bin/env python3
"""A stand-in for the scope's SCPI socket, for testing without the scope.

Answers `:DISP:DATA?` with an 800x480 24-bit BMP (a test pattern) in an
IEEE 488.2 block, and `*IDN?` with a fake ID. Listens on 127.0.0.1:5555.

  ./tools/fake_scope.py            # then point Scope Grab at 127.0.0.1
  ./tools/fake_scope.py --delay 2  # wait 2 s before each screen reply
"""
import argparse
import socketserver
import struct
import time

W, H = 800, 480


def test_bmp():
    row = bytearray()
    for x in range(W):
        row += bytes((x * 255 // W, 64, 255 - x * 255 // W))  # BGR gradient
    pixels = bytes(row) * H  # 800*3 is a multiple of 4, so no row padding
    header = struct.pack("<2sIHHI", b"BM", 54 + len(pixels), 0, 0, 54)
    info = struct.pack("<IiiHHIIiiII", 40, W, H, 1, 24, 0, len(pixels), 2835, 2835, 0, 0)
    return header + info + pixels


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        for line in self.rfile:
            cmd = line.strip().decode()
            if cmd == ":DISP:DATA?":
                time.sleep(self.server.delay)
                bmp = test_bmp()
                n = str(len(bmp)).encode()
                self.wfile.write(b"#" + str(len(n)).encode() + n + bmp + b"\n")
            elif cmd == "*IDN?":
                self.wfile.write(b"RIGOL TECHNOLOGIES,DS2072A,FAKE,00.03.06\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--delay", type=float, default=0.0)
    ap.add_argument("--port", type=int, default=5555)
    a = ap.parse_args()
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", a.port), Handler) as srv:
        srv.delay = a.delay
        print(f"fake scope on 127.0.0.1:{a.port}")
        srv.serve_forever()


if __name__ == "__main__":
    main()
