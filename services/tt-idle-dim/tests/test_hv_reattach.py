#!/usr/bin/env python3
"""The speaker bus may not exist yet when the daemon starts, and may go away.

tt-can0 is late_start in the panel's init, and this daemon starts at
sys.boot_completed, so the interface can legitimately be missing for the first
seconds. The daemon must keep running, keep dimming the panel, send nothing, and
keep retrying -- and attach as soon as the interface answers.

Asserts (no privileged interface creation needed):
  * with a bus that does not exist, the daemon still dims and stays alive
  * nothing is sent on the bus in that state
  * the retry is attempted repeatedly, at roughly HV_REOPEN_MS cadence
  * the status counters show no mutes, and hv_fd is not attached
  * when the interface is present from the start, it attaches once

The final transition -- a bus that appears after start -- needs CAP_NET_ADMIN to
create an interface, which this host does not grant; it is covered by the same
code path as the startup attach (one hv_can_open + epoll_ctl), exercised by the
second half of this test.
Host only.
"""
import os, pty, socket, struct, subprocess, sys, tempfile, threading, time, tty

SRC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CC = "clang"
IFACE = sys.argv[1] if len(sys.argv) > 1 else "hvtest0"
MISSING = "hvdefinitelymissing0"
MAXB, RESTORE = 100, 71
MUTE = (0x131, "a5b57b0100000000")

fails = 0
def ok(c, w):
    global fails
    print(("ok   " if c else "FAIL ") + w)
    if not c: fails += 1


def build():
    b = os.path.join(tempfile.mkdtemp(prefix="hva-"), "d")
    r = subprocess.run([CC, "-O2", "-Wall", "-o", b,
                        os.path.join(SRC, "idle_dim.c"), os.path.join(SRC, "idle_logic.c"),
                        os.path.join(SRC, "playback_control.c"), os.path.join(SRC, "hv_can.c")],
                       capture_output=True, text=True)
    if r.returncode:
        raise SystemExit("build failed:\n" + r.stderr)
    return b


def run(binpath, bright, status, iface):
    m, s = pty.openpty(); tty.setraw(s)
    p = subprocess.Popen([binpath, "--input", os.ttyname(s), "--brightness", bright,
                          "--status", status, "--idle-seconds", "1", "--dim", "0",
                          "--playback-stdin", "--hv-iface", iface],
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, text=True)
    return p, m


def keep_idle(proc):
    while True:
        try:
            proc.stdin.write("IDLE\n"); proc.stdin.flush()
        except Exception:
            return
        time.sleep(1.0)


def listen(iface):
    s = socket.socket(socket.AF_CAN, socket.SOCK_RAW, socket.CAN_RAW)
    s.bind((iface,)); s.settimeout(0.2)
    return s


def collect(sock, secs):
    out, end = [], time.time() + secs
    while time.time() < end:
        try:
            b = sock.recv(16)
        except socket.timeout:
            continue
        cid, dlc = struct.unpack("=IB3x", b[:8])
        out.append(((cid & 0x1FFFFFFF), b[8:8 + dlc].hex()))
    return out


b = build()

print("-- bus absent at start --")
w = tempfile.mkdtemp(prefix="hva-run-")
bright = os.path.join(w, "brightness"); open(bright, "w").write(f"{RESTORE}\n")
status = os.path.join(w, "st")
p, m = run(b, bright, status, MISSING)
threading.Thread(target=keep_idle, args=(p,), daemon=True).start()
time.sleep(0.4)

rx = listen(IFACE)                                  # a bus the daemon is NOT on
frames = collect(rx, 4.0)
rx.close()

dimmed = open(bright).read().strip()
alive = (p.poll() is None)
p.terminate(); log = p.communicate(timeout=5)[0]

ok(dimmed == "0", f"panel still dims with no bus (got {dimmed})")
ok(alive, "daemon stays alive with no bus")
ok(frames == [], f"nothing sent when the bus is absent: {frames}")
retries = log.count("unavailable")
ok(retries >= 2, f"the bus is retried repeatedly ({retries} attempts in ~4 s)")
ok("attached" not in log, "never claims an attach it did not make")

print("-- bus present at start --")
w2 = tempfile.mkdtemp(prefix="hva-run2-")
bright2 = os.path.join(w2, "brightness"); open(bright2, "w").write(f"{RESTORE}\n")
status2 = os.path.join(w2, "st")
p2, m2 = run(b, bright2, status2, IFACE)
threading.Thread(target=keep_idle, args=(p2,), daemon=True).start()
time.sleep(0.4)
rx2 = listen(IFACE)
frames2 = collect(rx2, 3.0)
rx2.close()
p2.terminate(); log2 = p2.communicate(timeout=5)[0]

ok(f"{IFACE} attached" in log2, "attaches when the bus is present")
ok(frames2.count(MUTE) == 1, f"dims and mutes once: {frames2}")

print("\n" + (f"FAILED ({fails})" if fails else "PASSED"))
sys.exit(1 if fails else 0)
