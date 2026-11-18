#!/bin/bash
# HydroVive MCU recovery over the ST ROM bootloader (USART2), via the ESP32 TCP bridge.
# Steps 1-3 are read-only. Step 4 is the ONLY write: user option bytes with BFB2=0.
set -euo pipefail
HOST=${1:?usage: recover.sh <esp32-ip> [port]}; PORT=${2:-6639}
D=$(dirname "$0")/run-$(date +%Y%m%d-%H%M%S); mkdir -p "$D"
socat -d pty,raw,echo=0,link="$D/tty" tcp:$HOST:$PORT & SP=$!; trap 'kill $SP 2>/dev/null' EXIT; sleep 1
echo "[1] identify (Get/GetID/GetVersion)"; stm32flash -b 57600 -m 8e1 "$D/tty" | tee "$D/1-identify.txt"
grep -q 'Device ID *: 0x0469' "$D/1-identify.txt" || { echo "not an STM32G47x (0x469) - stop"; exit 2; }
echo "[2] read option bytes 0x1FFF7800 (48 B)"; stm32flash -b 57600 -m 8e1 -c -S 0x1FFF7800:48 -r "$D/2-ob.bin" "$D/tty"; xxd "$D/2-ob.bin" | tee "$D/2-ob.txt"
OPTR=$(python3 -I -c "import struct,sys;print(hex(struct.unpack('<I',open(sys.argv[1],'rb').read()[0:4])[0]))" "$D/2-ob.bin")
echo "OPTR=$OPTR"; python3 -I -c "import sys;v=int(sys.argv[1],16);print('BFB2=',v>>20&1,'DBANK=',v>>22&1,'nSWBOOT0=',v>>26&1,'nBOOT0=',v>>27&1,'RDP=',hex(v&0xff))" $OPTR | tee -a "$D/2-ob.txt"
echo "[3] back up both banks (512 KB)"; stm32flash -b 57600 -m 8e1 -c -S 0x08000000:0x80000 -r "$D/3-flash.bin" "$D/tty"; sha256sum "$D/3-flash.bin" | tee "$D/3-flash.sha256"
python3 -I -c "import struct,sys;d=open(sys.argv[1],'rb').read();print('bank1 SP/RV',hex(struct.unpack_from('<I',d,0)[0]),hex(struct.unpack_from('<I',d,4)[0]));print('bank2 SP/RV',hex(struct.unpack_from('<I',d,0x40000)[0]),hex(struct.unpack_from('<I',d,0x40004)[0]))" "$D/3-flash.bin" | tee -a "$D/3-flash.sha256"
read -r -p "[4] write OPTR with BFB2=0 and reset? type YES: " ok; [ "$ok" = YES ] || { echo "stopped before any write"; exit 0; }
NEW=$(python3 -I -c "import sys;print(hex(int(sys.argv[1],16)&~(1<<20)))" $OPTR)
python3 -I - "$D/2-ob.bin" "$D/4-ob-new.bin" "$NEW" <<'PY'
import struct,sys; d=bytearray(open(sys.argv[1],'rb').read()); v=int(sys.argv[3],16)
old=struct.unpack_from('<I',d,0)[0]; comp=struct.unpack_from('<I',d,4)[0]
# G4 option word is stored with its bitwise complement at +4. Only proceed if the read-back matches that layout.
assert comp == (~old & 0xffffffff), f"unexpected OB layout: {old:#x} / {comp:#x} - stop"
assert (v & 0xff) == (old & 0xff) == 0xaa, "RDP is not level 0 (0xAA) - stop, never touch RDP"
assert v == old & ~(1<<20), "new value must differ from old only in BFB2"
struct.pack_into('<II',d,0,v,(~v)&0xffffffff); open(sys.argv[2],'wb').write(bytes(d[:8]))
PY
stm32flash -b 57600 -m 8e1 -c -S 0x1FFF7800:8 -w "$D/4-ob-new.bin" "$D/tty" | tee "$D/4-write.txt"
echo "done: the MCU reloads option bytes and boots bank 1 (v7). Check the panel for 0x143 frames."
