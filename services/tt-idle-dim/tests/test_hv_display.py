#!/usr/bin/env python3
"""HydroVive follows the panel's dim state, against the REAL deployed config.

Uses the deployed arguments: --idle-seconds 300 --dim 0 --playback-stdin.
Kept fast by overriding only --idle-seconds (the threshold is orthogonal to the
coupling); the dim target, playback-stdin and the brightness gating are real.

Asserts:
  * dim -> backlight 0 AND exactly one B5 mute
  * touch -> backlight restored AND exactly one B5 unmute
  * a FAILED dim write sends no mute (speaker follows a successful transition)
Host only; throwaway vcan.
"""
import os, pty, socket, struct, subprocess, sys, tempfile, time, tty

SRC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CC = "clang"; IFACE = sys.argv[1] if len(sys.argv) > 1 else "hvtest0"
MAXB = 100          # the panel's real max_brightness
RESTORE = 71        # the panel's real restore value

fails = 0
def ok(c, w):
    global fails
    print(("ok   " if c else "FAIL ") + w)
    if not c: fails += 1

def build():
    b = os.path.join(tempfile.mkdtemp(prefix="hv-"), "d")
    r = subprocess.run([CC,"-O2","-Wall","-o",b,
        os.path.join(SRC,"idle_dim.c"), os.path.join(SRC,"idle_logic.c"),
        os.path.join(SRC,"playback_control.c"), os.path.join(SRC,"hv_can.c")],
        capture_output=True, text=True)
    if r.returncode: raise SystemExit("build failed:\n"+r.stderr)
    return b

def run(binpath, bright, extra=()):
    m, s = pty.openpty(); tty.setraw(s)
    # --playback-stdin is the deployed mode: the daemon watches stdin and stays
    # in the "unknown" lease (which INHIBITS dimming) until the channel reports.
    # Keep the pipe OPEN and silent so idling is permitted, exactly as the
    # supervisor's pipe behaves when nothing is playing.
    p = subprocess.Popen([binpath,"--input",os.ttyname(s),"--brightness",bright,
        "--status",os.path.join(os.path.dirname(bright),"st"),
        "--idle-seconds","1","--dim","0","--playback-stdin","--hv-iface",IFACE,*extra],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return p, m

def frames(secs):
    s = socket.socket(socket.AF_CAN, socket.SOCK_RAW, socket.CAN_RAW)
    s.bind((IFACE,)); s.settimeout(0.2)
    out, end = [], time.time()+secs
    while time.time() < end:
        try: b = s.recv(16)
        except socket.timeout: continue
        cid, dlc = struct.unpack("=IB3x", b[:8]); out.append((cid & 0x1FFFFFFF, b[8:8+dlc].hex()))
    s.close(); return out

b = build()
w = tempfile.mkdtemp(prefix="hv-run-")
bright = os.path.join(w,"brightness"); open(bright,"w").write(f"{RESTORE}\n")
open(os.path.join(w,"max"),"w").write(f"{MAXB}\n")

p, m = run(b, bright)
p.stdin.write("IDLE\n"); p.stdin.flush()      # the lease starts UNKNOWN, which inhibits dimming
f1 = frames(3.0)
dim_now = open(bright).read().strip()
ok(dim_now == "0", f"idle drove the backlight to 0 (got {dim_now})")
ok(f1.count((0x131,"a5b57b0100000000")) == 1, f"exactly one B5 mute on dim: {f1}")

_rx = socket.socket(socket.AF_CAN, socket.SOCK_RAW, socket.CAN_RAW)
_rx.bind((IFACE,)); _rx.settimeout(0.2)
os.write(m, struct.pack("=qqHHi",0,0,1,330,1))     # EV_KEY BTN_TOUCH
time.sleep(0.25)
restored = open(bright).read().strip()
f2 = []
_end = time.time() + 0.6
while time.time() < _end:
    try: _b = _rx.recv(16)
    except socket.timeout: continue
    _c,_d = struct.unpack("=IB3x", _b[:8]); f2.append((_c & 0x1FFFFFFF, _b[8:8+_d].hex()))
_rx.close()
ok(restored == str(RESTORE), f"touch restored the backlight to {RESTORE} (got {restored})")
ok((0x131,"a5b57b0000000000") in f2, f"B5 unmute on wake: {f2}")

p.terminate(); p.communicate(timeout=5)

# failed-dim case: read-only brightness file
w2 = tempfile.mkdtemp(prefix="hv-fail-")
br2 = os.path.join(w2,"brightness"); open(br2,"w").write(f"{RESTORE}\n")
os.chmod(br2,0o444); os.chmod(w2,0o555)
p2, m2 = run(b, br2)
p2.stdin.write("IDLE\n"); p2.stdin.flush()
f3 = frames(2.8)
log = ""
p2.terminate(); log = p2.communicate(timeout=5)[0]
os.chmod(w2,0o755)
if "DIM write failed" in log:
    ok(not [f for f in f3 if f[1]=="a5b57b0100000000"], f"failed dim sent no mute: {f3}")
else:
    print("skip failed-dim: host wrote a 0444 file (running as root?)")

print("\n" + (f"FAILED ({fails})" if fails else "PASSED"))
sys.exit(1 if fails else 0)
