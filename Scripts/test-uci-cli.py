#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Exercise the real stdin/stdout executable, including quit with stdin open."""
import os
import selectors
import subprocess
import sys
import time

binary, model = sys.argv[1:]
for args in [[], ["--unknown"], ["--model"], ["--model", model, "extra"]]:
    assert subprocess.run([binary, *args], capture_output=True).returncode != 0, args
process = subprocess.Popen([binary, "--model", model], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
selector = selectors.DefaultSelector()
selector.register(process.stdout, selectors.EVENT_READ)
buffer = b""
lines = []

def send(command):
    process.stdin.write((command + "\n").encode())
    process.stdin.flush()

def until(predicate, timeout=15):
    global buffer
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate(lines):
            return
        for key, _ in selector.select(0.1):
            data = os.read(key.fileobj.fileno(), 65536)
            assert data, "Engine closed output prematurely"
            buffer += data
            while b"\n" in buffer:
                line, buffer = buffer.split(b"\n", 1)
                lines.append(line.decode())
    raise AssertionError("UCI timeout: " + repr(lines[-10:]))

try:
    send("uci"); until(lambda output: "uciok" in output)
    send("isready"); until(lambda output: "readyok" in output)
    lines.clear()
    send("position startpos"); send("go searchmoves e2e4")
    until(lambda output: "bestmove e2e4" in output)
    assert sum(line.startswith("bestmove ") for line in lines) == 1
    lines.clear()
    send("go infinite searchmoves d2d4")
    until(lambda output: any(line.startswith("info multipv") for line in output))
    assert not any(line.startswith("bestmove ") for line in lines)
    send("stop"); until(lambda output: "bestmove d2d4" in output)
    send("quit")
    # Do not close stdin: a GUI expects quit itself to terminate the process.
    assert process.wait(timeout=5) == 0
    print("maia-uci stdin/stdout handshake, readiness, legal search, infinite stop and quit passed.")
finally:
    if process.poll() is None:
        process.kill(); process.wait()
    selector.close()
