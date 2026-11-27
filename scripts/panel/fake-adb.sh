#!/bin/bash
# Fake adb for test_install.sh: a "panel" whose block devices are files under $FAKE. Supports only what
# the pipeline uses: connect, root, -s X shell <cmd>, push, reboot, exec-out. A reboot boots the slot
# the A/B record selects, exactly as U-Boot's priority rule does.
FAKE=${FAKE:?}
args=("$@"); [ "${args[0]}" = -s ] && args=("${args[@]:2}")
cmd=${args[0]:-}; shift_args=("${args[@]:1}")
case $cmd in
  connect|root|wait-for-device) exit 0 ;;
  reboot)
    python3 -I - "$FAKE" <<'PY'
import sys,os
F=sys.argv[1]; b=open(f"{F}/dev/misc","rb").read()[2048:2080]
pa,pb=b[8],b[12]
s="_a" if pa>pb else "_b"
open(f"{F}/slot","w").write(s); open(f"{F}/boot_id","w").write(os.urandom(8).hex())
PY
    exit 0 ;;
  push) cp "${shift_args[0]}" "$FAKE/data/$(basename "${shift_args[1]}")"; exit 0 ;;
  exec-out|shell)
    c="${shift_args[*]}"
    c=${c//\/dev\/block\/by-name\//$FAKE\/dev\/}; c=${c//\/data\/local\/tmp\//$FAKE\/data\/}
    c=${c//echo 3 > \/proc\/sys\/vm\/drop_caches/true}; c=$(sed -E "s/blockdev --flushbufs [^;]*/true/g" <<<"$c")
    case $c in
      "getprop ro.boot.slot_suffix") cat "$FAKE/slot" ;;
      "getprop sys.boot_completed") echo 1 ;;
      "getprop ro.product.device") echo "${FAKE_DEVICE:-dart_mx8mm}" ;;
      "getprop ro.hardware") echo freescale ;;
      "getprop ro.build.version.release") echo "${FAKE_ANDROID:-15}" ;;
      "getprop ro.boot.vbmeta.digest") cat "$FAKE/digest$(cat "$FAKE/slot")" 2>/dev/null ;;
      getenforce) echo Enforcing ;;
      "id -u") echo 0 ;;
      "cat /proc/sys/kernel/random/boot_id") cat "$FAKE/boot_id" ;;
      blockdev\ --getsize64\ *) stat -c %s "${c#blockdev --getsize64 }" ;;
      *) sh -c "$c" ;;
    esac ;;
  *) echo "fake adb: unsupported: $*" >&2; exit 1 ;;
esac
