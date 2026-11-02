#!/bin/sh
# Passive capture of everything on can0 for N seconds. Read-only.
#   can-capture.sh [seconds]
set -eu
SECS=${1:-10}
ADB=${ADB:-adb}; PANEL=${PANEL:-<panel-ip>:5555}; PORT=${PORT:-5038}
"$ADB" -P "$PORT" connect "$PANEL" >/dev/null 2>&1 || true
"$ADB" -P "$PORT" -s "$PANEL" shell "su 0 sh -c '
  python3 - <<PY
import socket,struct,time
s=socket.socket(socket.AF_CAN,socket.SOCK_RAW,socket.CAN_RAW)
s.bind((\"can0\",))
s.settimeout(1.0)
end=time.time()+$SECS
while time.time()<end:
    try: f=s.recv(16)
    except socket.timeout: continue
    cid,dlc=struct.unpack(\"=IB\",f[:5])
    print(\"%03X [%d] %s\" % (cid & 0x1FFFFFFF, dlc, \" \".join(\"%02X\"%b for b in f[8:8+dlc])))
PY
'"
