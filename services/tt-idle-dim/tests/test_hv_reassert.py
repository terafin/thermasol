#!/usr/bin/env python3
"""The app must not be able to leave the unit unmuted while the panel is dimmed.

The panel is dimmed by this daemon; the ThermaSol app does not know that, and
one of its paths unmutes without touching the backlight: an MQTT "user one" /
"user two" voice command writes externalLogin, which MainControlRequestMonitor
turns into loadUserSettings() -> toggleMusicAndSource() -> B5 00 + B6.

So the daemon re-asserts the mute when it hears the panel's own command id lift
it while it owns the dim. It never hears itself (CAN_RAW_RECV_OWN_MSGS is off),
so the re-mute cannot loop.

Asserts:
  * app B5 00 while dimmed  -> exactly one re-mute
  * app B6 while dimmed     -> exactly one re-mute (firmware unmutes before gain)
  * app B5 01 while dimmed  -> no re-mute (already muted)
  * two unmutes inside the rate window -> one re-mute
  * app B5 00 while ACTIVE  -> no re-mute (normal audio controls are untouched)
  * the re-mute does not repeat (no self-triggered loop)
  * status reports hv_reasserts
Host only; throwaway vcan.
"""
import os, pty, socket, struct, subprocess, sys, tempfile, threading, time, tty

SRC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CC = "clang"
IFACE = sys.argv[1] if len(sys.argv) > 1 else "hvtest0"
MAXB, RESTORE = 100, 71
MUTE = (0x131, "a5b57b0100000000")
UNMUTE = (0x131, "a5b57b0000000000")
VOL15 = (0x131, "a5b67b8f00000000")

fails = 0
def ok(c, w):
    global fails
    print(("ok   " if c else "FAIL ") + w)
    if not c: fails += 1


def build():
    b = os.path.join(tempfile.mkdtemp(prefix="hvr-"), "d")
    r = subprocess.run([CC, "-O2", "-Wall", "-o", b,
                        os.path.join(SRC, "idle_dim.c"), os.path.join(SRC, "idle_logic.c"),
                        os.path.join(SRC, "playback_control.c"), os.path.join(SRC, "hv_can.c")],
                       capture_output=True, text=True)
    if r.returncode:
        raise SystemExit("build failed:\n" + r.stderr)
    if r.stderr.strip():
        print("build warnings:\n" + r.stderr)
    return b


def run(binpath, bright, status):
    m, s = pty.openpty(); tty.setraw(s)
    p = subprocess.Popen([binpath, "--input", os.ttyname(s), "--brightness", bright,
                          "--status", status, "--idle-seconds", "1", "--dim", "0",
                          "--playback-stdin", "--hv-iface", IFACE],
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, text=True)
    return p, m


def app_socket():
    """A second socket on the bus: what the ThermaSol app looks like to the daemon."""
    s = socket.socket(socket.AF_CAN, socket.SOCK_RAW, socket.CAN_RAW)
    s.bind((IFACE,)); s.settimeout(0.2)
    return s


def send(sock, frame):
    cid, payload = frame
    data = bytes.fromhex(payload)
    sock.send(struct.pack("=IB3x", cid, len(data)) + data.ljust(8, b"\0"))


def collect(sock, secs):
    out, end = [], time.time() + secs
    while time.time() < end:
        try:
            b = sock.recv(16)
        except socket.timeout:
            continue
        cid, dlc = struct.unpack("=IB3x", b[:8])
        out.append((cid & 0x1FFFFFFF, b[8:8 + dlc].hex()))
    return out


b = build()
w = tempfile.mkdtemp(prefix="hvr-run-")
bright = os.path.join(w, "brightness"); open(bright, "w").write(f"{RESTORE}\n")
status = os.path.join(w, "st")

def keep_idle(proc):
    """The lease drops to UNKNOWN 5 s after the last word, and UNKNOWN inhibits
    dimming -- without a refresh the daemon restores the panel mid-test and the
    restore unmute looks like a stray frame. The supervisor refreshes; so do we."""
    while True:
        try:
            proc.stdin.write("IDLE\n"); proc.stdin.flush()
        except Exception:
            return
        time.sleep(1.0)

rx = app_socket()
p, m = run(b, bright, status)
threading.Thread(target=keep_idle, args=(p,), daemon=True).start()

# --- reach the dimmed state -------------------------------------------------
deadline = time.time() + 5
while time.time() < deadline and open(bright).read().strip() != "0":
    time.sleep(0.05)
ok(open(bright).read().strip() == "0", "panel dimmed")
collect(rx, 0.4)                                   # discard the initial mute

print("-- app lifts the mute while dimmed --")
send(rx, UNMUTE)
f = collect(rx, 0.6)
ok(f.count(MUTE) == 1, f"exactly one re-mute after B5 00: {f}")
ok(f.count(MUTE) == 1 and len(f) == 1, f"nothing else, and the re-mute does not loop: {f}")

time.sleep(1.1)                                    # clear the rate window

print("-- app sends its own mute while dimmed --")
send(rx, MUTE)
f = collect(rx, 0.6)
ok(f == [], f"no re-mute for a mute: {f}")

print("-- app sends a volume frame while dimmed --")
send(rx, VOL15)
f = collect(rx, 0.6)
ok(f.count(MUTE) == 1, f"B6 force-unmutes, so it is re-muted: {f}")

time.sleep(1.1)

print("-- a burst collapses into one re-mute --")
send(rx, UNMUTE); send(rx, UNMUTE); send(rx, VOL15)
f = collect(rx, 0.6)
ok(f.count(MUTE) == 1, f"three app frames, one re-mute: {f}")

# --- restore, then confirm normal app controls are untouched ----------------
print("-- while the panel is lit the app is not policed --")
os.write(m, struct.pack("=qqHHi", 0, 0, 1, 330, 1))        # EV_KEY BTN_TOUCH
deadline = time.time() + 3
while time.time() < deadline and open(bright).read().strip() != str(RESTORE):
    time.sleep(0.05)
ok(open(bright).read().strip() == str(RESTORE), "panel restored")
collect(rx, 0.3)                                            # discard the restore unmute
# --idle-seconds is 1 here, so the window in which the panel is genuinely lit
# is about one second: check inside it, and confirm it was still lit after.
ok(open(bright).read().strip() == str(RESTORE), "still lit before the app call")
send(rx, UNMUTE)
f = collect(rx, 0.4)
ok(f == [], f"no re-mute while lit: {f}")

p.terminate(); log = p.communicate(timeout=5)[0]
rx.close()

st = open(status).read()
ok("hv_reasserts=" in st, "status reports hv_reasserts")
try:
    n = int([l for l in st.splitlines() if l.startswith("hv_reasserts=")][0].split("=")[1])
    ok(n == 3, f"hv_reasserts counts the three re-mutes (got {n})")
except Exception as e:
    ok(False, f"could not read hv_reasserts: {e}")

ok("app lifted the mute while dim -> B5 mute re-sent" in log,
   "the re-mute is logged")

print("\n" + (f"FAILED ({fails})" if fails else "PASSED"))
sys.exit(1 if fails else 0)
