#!/bin/sh
# Read-only health snapshot of the ThermaTouch panel.
# Nothing here writes state; safe to run at any time.
set -eu
ADB=${ADB:-adb}
PANEL=${PANEL:-<panel-ip>:5555}   # set PANEL=<ip>:5555 or export it
PORT=${PORT:-5038}

r() { "$ADB" -P "$PORT" -s "$PANEL" shell "su 0 sh -c '$*'" 2>/dev/null || echo "(unavailable)"; }

"$ADB" -P "$PORT" connect "$PANEL" >/dev/null 2>&1 || true

echo "== identity =="
r "cat /proc/sys/kernel/random/boot_id; getprop ro.boot.slot_suffix; getprop ro.boot.vbmeta.digest; getprop sys.boot_completed"

echo "== shower controller =="
r "cat /data/user/0/net.siliconspirit.ttcontroller/files/controller-keeper-status.json" \
  | command grep -E '"state"|"binder_descriptor_verified"' || true
r "cat /sys/class/net/can0/statistics/tx_errors /sys/class/net/can0/statistics/rx_errors"

echo "== touch =="
r "getprop vendor.tt.touch_driver"

echo "== audio =="
r "tinymix -D 0 'Headphone Volume'"
r "cmd media_session volume --stream 3 --get"

echo "== network =="
r "cat /sys/class/net/eth0/carrier_changes"

echo "== idle =="
r "cat /data/local/tmp/tt-idle-dim.status" \
  | command grep -E 'state=|playback=|input_open=' || true

echo "== blueooth =="
r "dumpsys bluetooth_manager" | command grep -E 'state:|crashed' || true

echo "== crash log =="
r "logcat -b crash -d -v brief" | tail -20
