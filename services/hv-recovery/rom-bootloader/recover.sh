#!/bin/bash
# HydroVive MCU recovery over the ST ROM bootloader (USART2) via the ESP32 TCP bridge (8E1 on the chip side).
# Steps 1-3 are read-only. Step 4 is the ONLY write: user option bytes with BFB2 cleared.
set -euo pipefail
HOST=${1:?usage: recover.sh <esp32-ip> [port]}; PORT=${2:-6639}
H=$(cd "$(dirname "$0")" && pwd); BL="python3 -I $H/an3155.py $HOST $PORT"
D=$H/run-$(date +%Y%m%d-%H%M%S); mkdir -p "$D"
echo "[1] identify"
if ! $BL id | tee "$D/1-identify.txt"; then
  echo "No answer from the ROM bootloader. Check wiring (GND, GPIO17->PA3, GPIO16<-PA2)."
  echo "If wiring is right, the MCU is running bank-2 code: hold BOOT0 (PB8) at 3.3 V via ~10k, power-cycle, rerun."; exit 4; fi
grep -q 'device_id=0x0469' "$D/1-identify.txt" || { echo "not an STM32G47x (0x469) - stop"; exit 2; }
echo "[2] read option bytes 0x1FFF7800 (48 B)"
if ! $BL read 0x1FFF7800 48 "$D/2-ob.bin"; then
  echo "Option-byte read refused (pre-V13.5 ROM limit). Reading FLASH_OPTR register mirror instead:"
  $BL read 0x40022020 4 "$D/2-optr-reg.bin" && xxd "$D/2-optr-reg.bin" | tee "$D/2-ob.txt" || true
  echo "Not writing blind. Use STM32CubeProgrammer (UART, 8E1): untick BFB2, Apply. Expect 0xFFFFF8AA -> 0xFFEFF8AA."; exit 5; fi
xxd "$D/2-ob.bin" | tee "$D/2-ob.txt"
OPTR=$(python3 -I -c "import struct,sys;print(hex(struct.unpack('<I',open(sys.argv[1],'rb').read()[:4])[0]))" "$D/2-ob.bin")
python3 -I -c "import sys;v=int(sys.argv[1],16);print('OPTR',hex(v),'BFB2=',v>>20&1,'DBANK=',v>>22&1,'nSWBOOT0=',v>>26&1,'nBOOT0=',v>>27&1,'RDP=',hex(v&0xff))" $OPTR | tee -a "$D/2-ob.txt"
echo "[3] back up both banks (512 KB)"
$BL read 0x08000000 0x80000 "$D/3-flash.bin"; sha256sum "$D/3-flash.bin" | tee "$D/3-flash.sha256"
python3 -I -c "import struct,sys;d=open(sys.argv[1],'rb').read();print('bank1 SP/RV',hex(struct.unpack_from('<I',d,0)[0]),hex(struct.unpack_from('<I',d,4)[0]));print('bank2 SP/RV',hex(struct.unpack_from('<I',d,0x40000)[0]),hex(struct.unpack_from('<I',d,0x40004)[0]))" "$D/3-flash.bin" | tee -a "$D/3-flash.sha256"
if [ $(( OPTR >> 20 & 1 )) -eq 0 ]; then
  echo "BFB2 is already 0: clearing it is not the fix. Inspect the bank vectors above and 3-flash.bin. Stopping."; exit 3; fi
read -r -p "[4] write OPTR with BFB2=0 (MCU resets afterwards)? type YES: " ok; [ "$ok" = YES ] || { echo "stopped before any write"; exit 0; }
python3 -I - "$D/2-ob.bin" "$D/4-ob-new.bin" <<'PY'
import struct,sys; d=bytearray(open(sys.argv[1],'rb').read()); old,comp=struct.unpack_from('<II',d,0)
assert comp == (~old & 0xffffffff), f"unexpected OB layout: {old:#x} / {comp:#x} - stop"
assert (old & 0xff) == 0xaa, "RDP is not level 0 (0xAA) - stop, never touch RDP"
v = old & ~(1<<20)
struct.pack_into('<II',d,0,v,(~v)&0xffffffff); open(sys.argv[2],'wb').write(bytes(d[:8])); print(f"OPTR {old:#010x} -> {v:#010x}")
PY
if ! $BL write 0x1FFF7800 "$D/4-ob-new.bin" | tee "$D/4-write.txt"; then
  echo "Write did not get an ACK. Checking whether it took (the ROM resets after an option-byte write)..."; fi
sleep 3
echo "[5] verify: reconnect and read OPTR back"
if $BL read 0x1FFF7800 8 "$D/5-ob-after.bin" 2>/dev/null; then
  NEWV=$(python3 -I -c "import struct,sys;print(hex(struct.unpack('<I',open(sys.argv[1],'rb').read()[:4])[0]))" "$D/5-ob-after.bin")
  echo "OPTR after: $NEWV"
  [ $(( NEWV >> 20 & 1 )) -eq 0 ] && echo "SUCCESS: BFB2 is clear. Power-cycle; the MCU boots bank 1 (v7)." || { echo "FAILED: BFB2 still set."; exit 6; }
else
  echo "No bootloader answer after the write. That is expected if the MCU left the ROM and is now running v7."
  echo "Confirm on the panel: power-cycle and look for 0x143 'A5 B0 8F 07' frames. If absent, rerun this script."; exit 7
fi
