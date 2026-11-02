#!/bin/sh
# Sends a frame that CHANGES LIVE HARDWARE. Guessed frames have killed working
# speaker audio. Capture the vendor app's own frames with can-capture.sh first,
# then mirror them exactly.
#
# Set TT_ALLOW_CAN=1 to enable. Without it this script refuses and exits 2.
# Send ONE explicit CAN frame to the shower peripherals.
#
#   panel-send-can.sh <opcode-hex> <payload-hex...>
#   panel-send-can.sh 5f ff          # standby   -> A5 5F 7B FF
#   panel-send-can.sh b6 8a          # speaker volume 138
#   panel-send-can.sh b2 00          # ceiling light
#
# Frames are always:  id 0x131, data A5 <opcode> 7B <payload...>
#
# DANGER: this drives real hardware. Before using it, read docs/06-procedures.md §H:
# capture what the vendor app sends and mirror it. Do not guess.
set -eu
[ "${TT_ALLOW_CAN:-0}" = "1" ] || {
  echo "refusing: this sends a CAN frame to live hardware." >&2
  echo "set TT_ALLOW_CAN=1 to confirm you captured this frame from the vendor app." >&2
  exit 2
}
[ $# -ge 1 ] || { echo "usage: $0 <opcode-hex> [payload-hex...]" >&2; exit 2; }

ADB=${ADB:-adb}; PANEL=${PANEL:-<panel-ip>:5555}; PORT=${PORT:-5038}
OP=$1; shift

# Build the frame bytes on the host so the device side stays trivial.
FRAME="0xa5 0x$OP 0x7b"
for b in "$@"; do FRAME="$FRAME 0x$b"; done
N=$(( $(echo "$FRAME" | wc -w) ))
[ "$N" -le 8 ] || { echo "payload too long (max 8 data bytes total)" >&2; exit 2; }

echo "frame: 131 [$N] $FRAME"
"$ADB" -P "$PORT" connect "$PANEL" >/dev/null 2>&1 || true

"$ADB" -P "$PORT" -s "$PANEL" shell "su 0 sh -c '
  command -v python3 >/dev/null 2>&1 || { echo python3-missing; exit 3; }
  python3 - <<PY
import socket,struct,time
data=[$FRAME]
can_id=0x131
frame=struct.pack(\"=IB3x8s\",can_id,len(data),bytes(data))
s=socket.socket(socket.AF_CAN,socket.SOCK_RAW,socket.CAN_RAW)
s.bind((\"can0\",))
s.send(frame)
print(\"sent\", frame.hex())
PY
'"
