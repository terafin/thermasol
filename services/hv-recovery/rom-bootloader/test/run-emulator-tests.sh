#!/bin/bash
# Runs recover.sh against an AN3155 emulator of a bricked STM32G474 in four states.
# usage: run-emulator-tests.sh <image.bin>   (e.g. ThermaSol's latest.bin, not in this repo)
set -u; H=$(cd "$(dirname "$0")" && pwd); IMG=${1:?image}; LOG=$(mktemp -d); pass=0; fail=0
check(){ name=$1 optr=$2 rom=$3 port=$4 want_exit=$5 want_optr=$6 answer=${7:-YES}
  python3 -I "$H/stm32rom_emu.py" "$IMG" "$optr" "$rom" "$LOG/$name.log" "$port" 2>/dev/null & EP=$!; sleep 1
  echo "$answer" | timeout 300 bash "$H/../recover.sh" 127.0.0.1 "$port" > "$LOG/$name.out" 2>&1; rc=$?
  got=$(cat "$LOG/$name.log.optr"); kill $EP 2>/dev/null; wait $EP 2>/dev/null
  if [ "$rc" = "$want_exit" ] && [ "$got" = "$want_optr" ]; then echo "PASS $name (exit $rc, OPTR $got)"; pass=$((pass+1))
  else echo "FAIL $name (exit $rc want $want_exit, OPTR $got want $want_optr)"; fail=$((fail+1)); fi; }
check bricked   0xFFFFF8AA new 16690 0 0xffeff8aa
check oldrom    0xFFFFF8AA old 16691 5 0xfffff8aa no
check oldrom-factory 0xFFFFF8AA old 16694 0 0xffeff8aa FACTORY
check bfb2clear 0xFFEFF8AA new 16692 3 0xffeff8aa
check rdp1      0xFFFFF8BB new 16693 1 0xfffff8bb
echo "$pass passed, $fail failed"; [ $fail -eq 0 ]
