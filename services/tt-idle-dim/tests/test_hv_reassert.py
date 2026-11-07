#!/usr/bin/env python3
"""The app must not be able to leave the unit unmuted while the panel is dimmed.

The panel is dimmed by this daemon; the ThermaSol app does not know that, and
one of its paths unmutes without touching the backlight: an MQTT "user one" /
"user two" voice command writes externalLogin, which MainControlRequestMonitor
turns into loadUserSettings() -> toggleMusicAndSource() -> B5 00 + B6.

The daemon re-asserts the mute. Firmware semantics (read from latest.bin):
  B5  ldrb data[3]; 0x1714 -> 0 = unmute, anything else = mute
  B6  ldrsb data[3]; signed >= 0 -> master block SKIPPED (no mute, no unmute)
      signed < 0 -> v = data[3] & 0x7f; v == 0 -> mute; v > 0 -> unmute + gain
      data[4..6] are tone fields, each gated on its own bit 7, never the mute cell

The requirement is the FINAL dispatched command while the panel is still dim is
a mute. How many re-mutes it takes is a timing property and is reported, not
asserted.

Asserts:
  * captured pair (B5 00, then B6 8F 11 ms later): last audio frame is a mute
    and the panel is still dimmed afterwards
  * a second unmute shortly after a re-mute is NOT discarded
  * B6 80 (index 0) mutes, so it needs no re-mute
  * B6 0F (bit 7 clear) does not touch master volume, so no re-mute
  * B5 01 needs no re-mute
  * a frame shorter than 4 bytes is ignored
  * an app burst racing a touch: no mute is emitted after the panel is lit;
    any transient mute before that instant is reported
Host only; throwaway vcan; must be the only listener on it.
"""
import os, pty, socket, struct, subprocess, sys, tempfile, threading, time, tty

SRC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CC = "clang"
IFACE = sys.argv[1] if len(sys.argv) > 1 else "hvtest0"
MAXB, RESTORE = 100, 71
MUTE = (0x131, "a5b57b0100000000")
UNMUTE = (0x131, "a5b57b0000000000")
B6_IDX15 = (0x131, "a5b67b8f00000000")      # 0x8F -> signed <0, index 15 -> UNMUTE
B6_IDX0 = (0x131, "a5b67b8000000000")       # 0x80 -> signed <0, index 0  -> MUTE
B6_NO_MASTER = (0x131, "a5b67b0f00000000")  # 0x0F -> bit7 clear -> master skipped

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
    return b


def run(binpath, bright, status):
    m, s = pty.openpty(); tty.setraw(s)
    p = subprocess.Popen([binpath, "--input", os.ttyname(s), "--brightness", bright,
                          "--status", status, "--idle-seconds", "1", "--dim", "0",
                          "--playback-stdin", "--hv-iface", IFACE],
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


def app_socket():
    """Exactly what the app uses: socket() + bind(), no setsockopt. Its native
    library imports no setsockopt at all, so CAN_RAW_LOOPBACK stays at the
    default (on) and these frames reach the daemon's socket."""
    s = socket.socket(socket.AF_CAN, socket.SOCK_RAW, socket.CAN_RAW)
    s.bind((IFACE,)); s.settimeout(0.2)
    return s


def send(sock, frame, dlc=None):
    cid, payload = frame
    data = bytes.fromhex(payload)
    n = len(data) if dlc is None else dlc
    sock.send(struct.pack("=IB3x", cid, n) + data.ljust(8, b"\0"))


def collect(sock, secs):
    out, end = [], time.time() + secs
    while time.time() < end:
        try:
            b = sock.recv(16)
        except socket.timeout:
            continue
        cid, dlc = struct.unpack("=IB3x", b[:8])
        out.append((time.time(), (cid & 0x1FFFFFFF), b[8:8 + dlc].hex()))
    return out


b = build()
w = tempfile.mkdtemp(prefix="hvr-run-")
bright = os.path.join(w, "brightness"); open(bright, "w").write(f"{RESTORE}\n")
status = os.path.join(w, "st")

rx = app_socket()
p, m = run(b, bright, status)
threading.Thread(target=keep_idle, args=(p,), daemon=True).start()


def wait_dim():
    deadline = time.time() + 5
    while time.time() < deadline and open(bright).read().strip() != "0":
        time.sleep(0.05)
    return open(bright).read().strip() == "0"


def counters():
    out = {}
    for line in open(status).read().splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            if k.startswith("hv_"): out[k] = v
    return out


def audio(frames):
    return [f for f in frames if f[2].startswith("a5b5") or f[2].startswith("a5b6")]


def last_audio(frames):
    a = audio(frames)
    return (a[-1][1], a[-1][2]) if a else None


def fmt(frames):
    t0 = frames[0][0] if frames else 0
    return [f"{f[0]-t0:+.3f}s {f[2]}" for f in frames]


ok(wait_dim(), "panel dimmed")
collect(rx, 0.4)                                   # discard the dim mute / reconcile
seen = []

def take(secs):
    f = collect(rx, secs)
    seen.extend(f)
    return f


print("-- the captured pair: B5 00, then B6 8F eleven milliseconds later --")
send(rx, UNMUTE)
time.sleep(0.011)
send(rx, B6_IDX15)
f = take(0.7)
ok(last_audio(f) == MUTE, f"last audio frame dispatched is a mute: {fmt(f)}")
ok(all(x[2] == MUTE[1] for x in f), f"nothing but mutes reached the bus: {fmt(f)}")
ok(open(bright).read().strip() == "0", "panel still dimmed afterwards")
print(f"     note: this timing produced {len(f)} re-mute(s)")

print("-- a second unmute after a re-mute must not be discarded --")
collect(rx, 0.3)
send(rx, UNMUTE)
time.sleep(0.20)                                   # well inside a 1 s window
send(rx, UNMUTE)
f = take(0.7)
mutes = [x for x in f if x[2] == MUTE[1]]
ok(len(mutes) == 2, f"two lifts, two re-mutes (none dropped): {fmt(f)}")
ok(last_audio(f) == MUTE, f"final state is mute: {fmt(f)}")

print("-- B6 index 0 mutes: it needs no re-mute --")
collect(rx, 0.3)
send(rx, B6_IDX0)
f = take(0.6)
ok(f == [], f"no re-mute for a B6 that mutes: {fmt(f)}")

print("-- B6 with bit 7 clear never touches master volume --")
send(rx, B6_NO_MASTER)
f = take(0.6)
ok(f == [], f"no re-mute for a B6 that skips the master block: {fmt(f)}")

print("-- B5 mute needs no re-mute --")
send(rx, MUTE)
f = take(0.6)
ok(f == [], f"no re-mute for a mute: {fmt(f)}")

print("-- a frame shorter than four bytes is ignored --")
send(rx, (0x131, "a5b67b"), dlc=3)
f = take(0.6)
ok(f == [], f"no crash, no re-mute for a 3-byte frame: {fmt(f)}")

print("-- an app burst racing a touch --")
collect(rx, 0.3)
t_touch = time.time()
send(rx, UNMUTE)
os.write(m, struct.pack("=qqHHi", 0, 0, 1, 330, 1))     # EV_KEY BTN_TOUCH

f, t_lit = [], None
end = time.time() + 0.7          # under the 1 s idle, so it stays lit
while time.time() < end:
    if t_lit is None and open(bright).read().strip() == str(RESTORE):
        t_lit = time.time()
    try:
        raw = rx.recv(16)
    except socket.timeout:
        continue
    cid, dlc = struct.unpack("=IB3x", raw[:8])
    f.append((time.time(), (cid & 0x1FFFFFFF), raw[8:8 + dlc].hex()))
seen.extend(f)

ok(t_lit is not None, "panel became lit")
still_lit = open(bright).read().strip() == str(RESTORE)
ok(still_lit, "panel still lit when the window closed")
after_lit = [x for x in f if t_lit is not None and x[0] > t_lit]
transient = [x for x in f if x[2] == MUTE[1] and (t_lit is None or x[0] <= t_lit)]
ok(not [x for x in after_lit if x[2] == MUTE[1]],
   f"no mute emitted while the panel was lit: {[x[2] for x in after_lit]}")
ok(last_audio(f) == UNMUTE, f"final audio frame while lit is an unmute: {fmt(f)}")
if transient:
    print(f"     note: {len(transient)} transient mute(s) before the panel lit "
          f"(final state unaffected): {[f'{x[0]-t_touch:+.3f}s' for x in transient]}")

p.terminate(); log = p.communicate(timeout=5)[0]
rx.close()

c = counters()
mutes_on_bus = len([x for x in seen if x[2] == MUTE[1]])
ok(int(c.get("hv_reasserts", "0")) >= 4,
   f"hv_reasserts counted the forced re-mutes: {c.get('hv_reasserts')} "
   f"(mutes seen on the bus: {mutes_on_bus}; dim transitions are counted separately)")
ok("app lifted the mute while dim -> B5 mute re-sent" in log, "the re-mute is logged")

print("\n" + (f"FAILED ({fails})" if fails else "PASSED"))
sys.exit(1 if fails else 0)
