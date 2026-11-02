#!/bin/sh
# Reboot the panel and wait for it to come back healthy.
#
# Refuses to reboot unless the shower controller reports connected and there is no
# pending deploy arm. Verifies the NEW boot id differs from the old one.
set -eu
ADB=${ADB:-adb}; PANEL=${PANEL:-<panel-ip>:5555}; PORT=${PORT:-5038}
V6=${V6:-'[fe80::def:7b18:fe:3b4b%ens160]:5555'}

conn() { "$ADB" -P "$PORT" connect "$1" >/dev/null 2>&1 || true; }
sh_() { "$ADB" -P "$PORT" -s "$1" shell "su 0 sh -c '$2'" 2>/dev/null; }

conn "$PANEL"
OLD=$(sh_ "$PANEL" 'cat /proc/sys/kernel/random/boot_id' | tr -d '\r')
[ -n "$OLD" ] || { echo "cannot read boot id; aborting" >&2; exit 1; }

CTRL=$(sh_ "$PANEL" 'cat /data/user/0/net.example.ttcontroller/files/controller-keeper-status.json' | command grep -c '"state": "connected"' || true)
[ "$CTRL" = "1" ] || { echo "controller not connected; NOT rebooting" >&2; exit 1; }

ARM=$(sh_ "$PANEL" 'test ! -e /metadata/tt/pending-deploy; echo $?' | tr -d '\r')
[ "$ARM" = "0" ] || { echo "pending deploy arm present; NOT rebooting" >&2; exit 1; }

echo "rebooting (old boot $OLD)"
"$ADB" -P "$PORT" -s "$PANEL" reboot || true

START=$(date +%s)
while [ $(( $(date +%s) - START )) -lt 300 ]; do
  sleep 5
  for T in "$PANEL" "$V6"; do
    conn "$T"
    S=$(sh_ "$T" 'getprop sys.boot_completed; cat /proc/sys/kernel/random/boot_id' | tr -d '\r')
    BC=$(echo "$S" | sed -n 1p); NEW=$(echo "$S" | sed -n 2p)
    [ "$BC" = "1" ] && [ -n "$NEW" ] && [ "$NEW" != "$OLD" ] || continue
    echo "back after $(( $(date +%s) - START ))s, new boot $NEW"
    sh_ "$T" 'getprop ro.boot.slot_suffix; getprop ro.boot.vbmeta.digest; getprop vendor.tt.touch_driver'
    exit 0
  done
done
echo "TIMEOUT waiting for panel" >&2; exit 1
