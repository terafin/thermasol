#!/usr/bin/env python3
"""The speaker bus may not exist yet when the daemon starts, and may go away.

tt-can0 is late_start in the panel's init and this daemon starts at
sys.boot_completed, so the interface can legitimately be missing for the first
seconds. While it is missing, a dim or a restore cannot be delivered -- so on
every attach the daemon sends the frame matching the display state it is
actually in. One frame per attach, never periodic.

Asserts (no privileged interface creation needed):
  * with a bus that does not exist, the daemon still dims, stays alive, sends
    nothing on the bus and retries repeatedly
  * dim recovery: a panel left dimmed with no bus, restarted with the bus
    present, is muted once on attach
  * lit recovery: a lit panel attaches and is unmuted once
  * a bus present from the start still dims and mutes once after the reconcile

The "interface appears while the daemon is running" transition is the same
hv_can_open + epoll_ctl + hv_reconcile path as the startup attach, but creating
a vcan needs CAP_NET_ADMIN which this host does not grant, so it is not driven
as a mid-run event here.
Host only.
"""
import os, pty, socket, struct, subprocess, sys, tempfile, threading, time, tty

SRC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CC = "clang"
IFACE = sys.argv[1] if len(sys.argv) > 1 else "hvtest0"
MISSING = "hvdefinitelymissing0"
MAXB, RESTORE = 100, 71
MUTE = (0x131, "a5b57b0100000000")
UNMUTE = (0x131, "a5b57b0000000000")

fails = 0
def ok(c, w):
    global fails
    print(("ok   " if c else "FAIL ") + w)
    if not c: fails += 1


def boot_hash():
    """Mirror read_boot_id(): FNV-1a over the whole boot_id file contents."""
    b = open("/proc/sys/kernel/random/boot_id", "rb").read()
    h = 1469598103934665603
    for c in b:
        h ^= c
        h = (h * 1099511628211) & 0xFFFFFFFFFFFFFFFF
    return h & 0x7FFFFFFFFFFFFFFF


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


def workspace(lit):
    w = tempfile.mkdtemp(prefix="hva-run-")
    bright = os.path.join(w, "brightness")
    open(bright, "w").write(f"{RESTORE if lit else 0}\n")
    open(os.path.join(w, "max_brightness"), "w").write(f"{MAXB}\n")
    return w, bright, os.path.join(w, "st")


def pretend_owned_dim(status, bright):
    """Leave the prior-state file exactly as a daemon that dimmed and then died
    without restoring would: state=dim, same boot, panel still at the dim value."""
    with open(status, "w") as f:
        f.write("state=dim\nrestore_bright=%d\ndim_bright=0\nmax_bright=%d\n"
                "boot_id=%016x\nrunning_bright=0\n" % (RESTORE, MAXB, boot_hash()))


b = build()

print("-- bus absent at start --")
w, bright, status = workspace(lit=True)
p, m = run(b, bright, status, MISSING)
threading.Thread(target=keep_idle, args=(p,), daemon=True).start()
time.sleep(0.4)
rx = listen(IFACE)
frames = collect(rx, 4.0)
rx.close()
dimmed = open(bright).read().strip()
alive = (p.poll() is None)
p.kill(); log = p.communicate(timeout=5)[0]      # SIGKILL: leave it dimmed

ok(dimmed == "0", f"panel still dims with no bus (got {dimmed})")
ok(alive, "daemon stays alive with no bus")
ok(frames == [], f"nothing sent when the bus is absent: {frames}")
ok(log.count("unavailable") >= 2, f"the bus is retried repeatedly ({log.count('unavailable')} attempts)")
ok("B5 mute sent" not in log, "the dim was not believed to have been delivered")

print("-- dim recovery: bus returns while the panel is still dimmed --")
# The prior-state file written by the killed run says state=dim on this boot and
# the panel is still at the dim value, so the daemon restarts owning the dim.
p2, m2 = run(b, bright, status, IFACE)
threading.Thread(target=keep_idle, args=(p2,), daemon=True).start()
rx2 = listen(IFACE)
f2 = collect(rx2, 2.0)
rx2.close()
still_dim = open(bright).read().strip()
p2.terminate(); log2 = p2.communicate(timeout=5)[0]

ok(f2.count(MUTE) == 1, f"one reconcile mute on attach: {f2}")
ok(f2 == [MUTE], f"and nothing else: {f2}")
ok("reconciled to mute" in log2, "logged as a reconcile, not a transition")
ok(still_dim == "0", f"panel was still dimmed (got {still_dim})")

print("-- lit recovery: a lit panel is unmuted on attach --")
w2, bright2, status2 = workspace(lit=True)
p3, m3 = run(b, bright2, status2, IFACE)
threading.Thread(target=keep_idle, args=(p3,), daemon=True).start()
rx3 = listen(IFACE)
f3 = collect(rx3, 1.5)
p3.terminate(); log3 = p3.communicate(timeout=5)[0]
rx3.close()

ok(f3.count(UNMUTE) == 1, f"one reconcile unmute on attach: {f3}")
ok("reconciled to unmute" in log3, "logged as a reconcile")
ok(open(bright2).read().strip() == str(RESTORE), "panel still lit")

print("-- bus present from the start: reconcile, then dim and mute once --")
w3, bright3, status3 = workspace(lit=True)
p4, m4 = run(b, bright3, status3, IFACE)
threading.Thread(target=keep_idle, args=(p4,), daemon=True).start()
rx4 = listen(IFACE)
f4 = collect(rx4, 3.0)
p4.terminate(); log4 = p4.communicate(timeout=5)[0]
rx4.close()

ok(f4.count(UNMUTE) == 1 and f4.count(MUTE) == 1,
   f"one reconcile unmute then one dim mute: {f4}")

print("\n" + (f"FAILED ({fails})" if fails else "PASSED"))
sys.exit(1 if fails else 0)
