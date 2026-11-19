#!/bin/bash
# Put a bootable image into bank 1 when recover.sh stopped with exit 10 (bank 1 cannot boot).
# Source: "slot2" copies bank 2's image into bank 1 (keeps v7 if v7 is what sits in bank 2), or a file
# (ThermaSol's latest.bin, v5, sha256 37c81d0b...). Refuses if bank 1 already boots. Never touches bank 2
# or the option bytes; run recover.sh afterwards to clear BFB2.
set -euo pipefail
HOST=${1:?usage: restore-bank1.sh <esp32-ip> [port] slot2|<image.bin>}; PORT=${2:-6639}; SRC=${3:?source: slot2 or an image file}
H=$(cd "$(dirname "$0")" && pwd); BL="python3 -I $H/an3155.py $HOST $PORT"; D=$H/restore-$(date +%Y%m%d-%H%M%S); mkdir -p "$D"
V5_SHA=37c81d0b020d0be55287a2ac836909cff0473f08a5ccc74a12eeb8c33083279f
boots(){ python3 -I -c "import struct,sys;sp,rv=struct.unpack_from('<II',open(sys.argv[1],'rb').read(),0);sys.exit(0 if 0x20000000<sp<=0x20020000 and rv&1 and 0x08000000<=rv<0x08040000 else 1)" "$1"; }
# capture first: under pipefail, 'cmd | grep -q' fails if cmd is still writing when grep exits on a match
IDOUT=$($BL id) || { echo "no answer from the ROM bootloader - check wiring"; exit 4; }
case "$IDOUT" in *device_id=0x0469*) ;; *) echo "not an STM32G47x (0x469): $IDOUT - stop"; exit 4;; esac
# SYSCFG_MEMRMP.FB_MODE (RM0440): 1 means bank 2 is mapped at 0x08000000, which would turn every "bank 1"
# address below into bank 2. AN2606 Fig. 60: the ROM sets the swap only when it jumps to user code.
if $BL read 0x40010000 4 "$D/1-memrmp.bin" >/dev/null 2>&1; then
  if [ $(( $(od -An -tu4 "$D/1-memrmp.bin") >> 8 & 1 )) -eq 1 ]; then
    echo "FB_MODE=1: bank 2 is mapped at 0x08000000, so bank addresses here would be swapped. Not continuing."; exit 11; fi
  echo "FB_MODE=0: bank 1 at 0x08000000" | tee -a /dev/null
else echo "SYSCFG_MEMRMP not readable - continuing on the documented default (FB_MODE=0)" | tee -a /dev/null; fi
echo "[1] back up both banks (512 KB)"; $BL read 0x08000000 0x80000 "$D/flash-before.bin"; sha256sum "$D/flash-before.bin" | tee "$D/flash-before.sha256"
head -c 262144 "$D/flash-before.bin" > "$D/bank1-before.bin"; tail -c 262144 "$D/flash-before.bin" > "$D/bank2.bin"
if boots "$D/bank1-before.bin"; then echo "bank 1 already boots; nothing to restore. Run recover.sh."; exit 2; fi
if [ "$SRC" = slot2 ]; then
  boots "$D/bank2.bin" && python3 -I -c "import struct,sys;rv=struct.unpack_from('<I',open(sys.argv[1],'rb').read(),4)[0];sys.exit(0)" "$D/bank2.bin" || { echo "bank 2 has no bootable image either; use a file source."; exit 3; }
  # bank-2 code linked for 0x08000000 (BFB2 swap) is position-correct in bank 1; trim trailing erased flash
  python3 -I -c "import sys;d=open(sys.argv[1],'rb').read().rstrip(b'\xff');open(sys.argv[2],'wb').write(d)" "$D/bank2.bin" "$D/image.bin"
  echo "source: bank 2 image, $(stat -c %s "$D/image.bin") bytes"
else
  cp "$SRC" "$D/image.bin"; S=$(sha256sum "$D/image.bin" | cut -d' ' -f1)
  [ "$S" = "$V5_SHA" ] && echo "source: ThermaSol latest.bin (v5), sha256 matches" || { echo "source file sha256 $S is not ThermaSol's v5 ($V5_SHA)"; read -r -p "type USE-ANYWAY to continue: " a; [ "$a" = USE-ANYWAY ] || exit 5; }
  boots "$D/image.bin" || { echo "source file does not look bootable at 0x08000000 - stop"; exit 5; }
fi
read -r -p "[2] erase bank-1 pages for $(stat -c %s "$D/image.bin") bytes and write the image? type YES: " ok; [ "$ok" = YES ] || { echo "stopped before any write"; exit 0; }
$BL erase-bank1 "$(stat -c %s "$D/image.bin")"; $BL write-flash 0x08000000 "$D/image.bin"
echo "[3] verify"; $BL read 0x08000000 "$(stat -c %s "$D/image.bin")" "$D/bank1-after.bin"
cmp -s "$D/image.bin" "$D/bank1-after.bin" || { echo "VERIFY FAILED: bank 1 differs from the image; backups in $D"; exit 6; }
echo "bank 1 written and verified. Now run recover.sh to clear BFB2."
