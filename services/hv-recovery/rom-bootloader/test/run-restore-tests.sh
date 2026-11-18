#!/bin/bash
# Tests restore-bank1.sh (and recover.sh after it) against the AN3155 emulator.
# usage: run-restore-tests.sh <image.bin> [case]
set -u; H=$(cd "$(dirname "$0")" && pwd); IMG=${1:?image}; ONLY=${2:-}; LOG=$(mktemp -d); pass=0; fail=0
emu(){ IMG_BANK=$1 python3 -I "$H/stm32rom_emu.py" "$IMG" 0xFFFFF8AA new "$LOG/$2.log" "$3" 2>/dev/null & EP=$!
  for _ in $(seq 50); do python3 -I -c "import socket,sys;socket.create_connection(('127.0.0.1',int(sys.argv[1])),0.2).close()" "$3" 2>/dev/null && break; sleep 0.1; done
  sleep 0.3; kill -0 $EP 2>/dev/null || { echo "FAIL: emulator did not start (port in use by a leftover emulator?)"; exit 2; }
  ss -ltnp 2>/dev/null | grep ":$3 " | grep -q "pid=$EP," || { echo "FAIL: port $3 is not held by this emulator"; kill $EP; exit 2; }; }
bank1_is(){ python3 -I -c "import sys;f=open(sys.argv[1],'rb').read();i=open(sys.argv[2],'rb').read();sys.exit(0 if f[:len(i)]==i and set(f[len(i):0x40000])<={0xff} else 1)" "$LOG/$1.log.flash" "$2"; }
res(){ if [ "$2" = ok ]; then echo "PASS $1"; pass=$((pass+1)); else echo "FAIL $1 ($3)"; fail=$((fail+1)); fi; }
case_on(){ [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }

if case_on fromslot2; then emu 2 fromslot2 16801
  echo YES | timeout 400 bash "$H/../restore-bank1.sh" 127.0.0.1 16801 slot2 > "$LOG/fromslot2.out" 2>&1; rc=$?; kill $EP; wait $EP 2>/dev/null
  if [ $rc = 0 ] && bank1_is fromslot2 "$IMG"; then res fromslot2 ok; else res fromslot2 no "exit $rc, bank1 match: $(bank1_is fromslot2 "$IMG" && echo yes || echo no)"; fi; fi

if case_on refuse; then emu 1 refuse 16802
  echo YES | timeout 400 bash "$H/../restore-bank1.sh" 127.0.0.1 16802 slot2 > "$LOG/refuse.out" 2>&1; rc=$?; kill $EP; wait $EP 2>/dev/null
  if [ $rc = 2 ] && bank1_is refuse "$IMG" && grep -q "bank 1 already boots" "$LOG/refuse.out"; then res refuse ok; else res refuse no "exit $rc"; fi; fi

if case_on fromfile; then emu none fromfile 16803
  echo YES | timeout 400 bash "$H/../restore-bank1.sh" 127.0.0.1 16803 "$IMG" > "$LOG/fromfile.out" 2>&1; rc=$?; kill $EP; wait $EP 2>/dev/null
  if [ $rc = 0 ] && bank1_is fromfile "$IMG"; then res fromfile ok; else res fromfile no "exit $rc"; fi; fi

if case_on blankslot2; then emu none blankslot2 16804
  echo YES | timeout 400 bash "$H/../restore-bank1.sh" 127.0.0.1 16804 slot2 > "$LOG/blankslot2.out" 2>&1; rc=$?; kill $EP; wait $EP 2>/dev/null
  if [ $rc = 3 ] && grep -q "bank 2 has no bootable image" "$LOG/blankslot2.out"; then res blankslot2 ok; else res blankslot2 no "exit $rc"; fi; fi

echo "$pass passed, $fail failed"; [ $fail -eq 0 ]
