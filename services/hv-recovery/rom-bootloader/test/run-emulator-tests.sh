#!/bin/bash
# Runs recover.sh against an AN3155 emulator of a bricked STM32G474 in four states.
# usage: run-emulator-tests.sh <image.bin> [case]   (image e.g. ThermaSol's latest.bin, not in this repo)
set -u; H=$(cd "$(dirname "$0")" && pwd); IMG=${1:?image}; LOG=$(mktemp -d); pass=0; fail=0
ONLY=${2:-}   # optional: run only the named case
check(){ [ -n "$ONLY" ] && [ "$1" != "$ONLY" ] && return; name=$1 optr=$2 rom=$3 port=$4 want_exit=$5 want_optr=$6 answer=${7:-YES} romver=${8:-0xD4} want_text=${9:-} postboot=${10:-} dropat=${11:-} wipe2=${12:-} imgbank=${13:-} fbmode=${14:-}
  FB_MODE=$fbmode IMG_BANK=$imgbank WIPE_BANK2=$wipe2 DROP_AT=$dropat POSTBOOT=$postboot ROMVER=$romver python3 -I "$H/stm32rom_emu.py" "$IMG" "$optr" "$rom" "$LOG/$name.log" "$port" 2>/dev/null & EP=$!
  for _ in $(seq 50); do python3 -I -c "import socket,sys;socket.create_connection((\"127.0.0.1\",int(sys.argv[1])),0.2).close()" "$port" 2>/dev/null && break; sleep 0.1; done
  sleep 0.3; kill -0 $EP 2>/dev/null || { echo "FAIL: emulator did not start (port in use by a leftover emulator?)"; exit 2; }
  ss -ltnp 2>/dev/null | grep ":$port " | grep -q "pid=$EP," || { echo "FAIL: port $port is not held by this emulator"; kill $EP; exit 2; }
  echo "$answer" | timeout 300 bash "$H/../recover.sh" 127.0.0.1 "$port" > "$LOG/$name.out" 2>&1; rc=$?
  got=$(cat "$LOG/$name.log.optr"); rest=$(cat "$LOG/$name.log.rest" 2>/dev/null); kill $EP 2>/dev/null; wait $EP 2>/dev/null
  want_rest=ffffffff000000000000ff00ffff00ffffff00ff0000ff00ffff00ff0000ff0000ff00ffff00ff00  # RM0440 factory PCROP1/WRP1A/WRP2A/SEC1
  txt_ok=yes; [ -n "$want_text" ] && ! grep -qF "$want_text" "$LOG/$name.out" && txt_ok=no
  if [ "$rc" = "$want_exit" ] && [ "$got" = "$want_optr" ] && [ "$rest" = "$want_rest" ] && [ $txt_ok = yes ]; then echo "PASS $name (exit $rc, OPTR $got)"; pass=$((pass+1))
  else echo "FAIL $name (exit $rc want $want_exit, OPTR $got want $want_optr, rest-of-OB intact: $([ "$rest" = "$want_rest" ] && echo yes || echo NO), text ok: $txt_ok)"; fail=$((fail+1)); fi; }
check bricked   0xFFFFF8AA new 16690 0 0xffeff8aa YES 0xD4 "bank-2 option bytes unchanged"
check romver   0xFFFFF8AA new 16695 0 0xffeff8aa YES 0xD4 "ROM build V13.4"
check rom133    0xFFFFF8AA new 16694 0 0xffeff8aa YES 0xD3 "ROM build V13.3 (byte 0xD3) (dual-bank boot erratum"
check oldrom    0xFFFFF8AA old 16691 5 0xfffff8aa no
check bfb2clear 0xFFEFF8AA new 16692 3 0xffeff8aa
check success   0xFFFFF8AA new 16696 0 0xffeff8aa YES 0xD4 "Disconnect the ESP32"
check leftrom   0xFFFFF8AA new 16697 0 0xffeff8aa YES 0xD4 "WRITE SENT, NOT READ BACK" v7
check drop      0xFFFFF8AA new 16698 0 0xffeff8aa YES 0xD4 "retrying" "" 0x08020000
check bank2     0xFFFFF8AA new 16699 9 0xffeff8aa YES 0xD4 "BANK-2 OPTION BYTES CHANGED" "" "" 1
check bank1blank 0xFFFFF8AA new 16700 10 0xfffff8aa YES 0xD4 "bank 1 has no bootable image" "" "" "" 2
check fbswap    0xFFFFF8AA new 16701 11 0xfffff8aa YES 0xD4 "FB_MODE=1" "" "" "" "" 1
check rom135    0xFFFFF8AA new 16702 12 0xfffff8aa YES 0xD5 "V13.5 or later, which accepts a CCM stack pointer"
check rdp1      0xFFFFF8BB new 16693 1 0xfffff8bb
echo "$pass passed, $fail failed"; [ $fail -eq 0 ]
