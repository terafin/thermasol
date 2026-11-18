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
# ROM build byte (ST, community.st.com thread 61363): 0x1FFF6FFE, high nibble = major-0, low = minor; 0xD4 = V13.4.
# V13.3 and older cannot boot bank 2 at all; V13.4 and later reject a bank whose SP is outside SRAM1.
if $BL read 0x1FFF6FFE 1 "$D/1-romver.bin" >/dev/null 2>&1; then
  RV=$(od -An -tu1 "$D/1-romver.bin" | tr -d ' ')
  printf 'ROM build V%d.%d (byte 0x%02X)' $(( (RV>>4) )) $(( RV & 15 )) "$RV" | sed 's/V\([0-9]\)\./V1\1./' | tee -a "$D/1-identify.txt"
  if [ "$RV" -lt $((0xD4)) ]; then echo " (dual-bank boot erratum: this ROM never boots bank 2)" | tee -a "$D/1-identify.txt"
  else echo " (rejects a bank whose initial SP is above 0x20017FFF)" | tee -a "$D/1-identify.txt"; fi
else echo "ROM build byte at 0x1FFF6FFE not readable - continuing" | tee -a "$D/1-identify.txt"; fi
# SYSCFG_MEMRMP.FB_MODE (RM0440): 1 means bank 2 is mapped at 0x08000000, which would turn every "bank 1"
# address below into bank 2. AN2606 Fig. 60: the ROM sets the swap only when it jumps to user code.
if $BL read 0x40010000 4 "$D/1-memrmp.bin" >/dev/null 2>&1; then
  if [ $(( $(od -An -tu4 "$D/1-memrmp.bin") >> 8 & 1 )) -eq 1 ]; then
    echo "FB_MODE=1: bank 2 is mapped at 0x08000000, so bank addresses here would be swapped. Not continuing."; exit 11; fi
  echo "FB_MODE=0: bank 1 at 0x08000000" | tee -a "$D/1-identify.txt"
else echo "SYSCFG_MEMRMP not readable - continuing on the documented default (FB_MODE=0)" | tee -a "$D/1-identify.txt"; fi
echo "[2] read option bytes 0x1FFF7800 (48 B)"
if ! $BL read 0x1FFF7800 48 "$D/2-ob.bin"; then
  echo "Option-byte read refused (pre-V13.5 ROM limit). Reading FLASH_OPTR register mirror instead:"
  if $BL read 0x40022020 4 "$D/2-optr-reg.bin"; then
    REG=$(python3 -I -c "import struct,sys;print(hex(struct.unpack('<I',open(sys.argv[1],'rb').read())[0]))" "$D/2-optr-reg.bin")
    echo "FLASH_OPTR register: $REG" | tee "$D/2-ob.txt"
    [ "$REG" = "0xfffff8aa" ] && echo "That is the ST factory value with only BFB2 set - the expected state."
  fi
  echo "Not writing: a Write Memory to the option area erases all 48 option bytes (AN3155), and this ROM will not let them be read back first."
  echo "Use STM32CubeProgrammer: STM32_Programmer_CLI -c port=<tty> br=57600 P=EVEN -ob BFB2=0 -ob displ"; exit 5; fi
xxd "$D/2-ob.bin" | tee "$D/2-ob.txt"
# Bank-2 option block (PCROP2, WRP2A/B, SEC2). Not written by this script; read so step 5 can tell if the
# ROM's option erase touched it (AN3155 says the whole option area is erased; which blocks is not documented).
if $BL read 0x1FFFF800 48 "$D/2-ob2.bin" >/dev/null 2>&1; then echo "bank-2 option block saved (2-ob2.bin)"; else echo "bank-2 option block not readable on this ROM"; fi
OPTR=$(python3 -I -c "import struct,sys;print(hex(struct.unpack('<I',open(sys.argv[1],'rb').read()[:4])[0]))" "$D/2-ob.bin")
python3 -I -c "import sys;v=int(sys.argv[1],16);print('OPTR',hex(v),'BFB2=',v>>20&1,'DBANK=',v>>22&1,'nSWBOOT0=',v>>26&1,'nBOOT0=',v>>27&1,'RDP=',hex(v&0xff))" $OPTR | tee -a "$D/2-ob.txt"
echo "[3] back up both banks (512 KB)"
$BL read 0x08000000 0x80000 "$D/3-flash.bin"; sha256sum "$D/3-flash.bin" | tee "$D/3-flash.sha256"
# ROM rule (ST, thread 61363; ST's own FLASH_DualBoot bank-2 binary uses SP 0x20000480): a bank's initial
# SP must lie in SRAM1, 0x20000000-0x20017FFF (SP may equal the top+1 only on newer ROMs; treat it as rejected).
python3 -I - "$D/3-flash.bin" <<'PY2' | tee -a "$D/3-flash.sha256"
import struct,sys; d=open(sys.argv[1],'rb').read()
for n,o in (("bank1",0),("bank2",0x40000)):
    sp,rv=struct.unpack_from('<II',d,o)
    if sp==0xffffffff: v="blank (ROM skips it)"
    elif 0x20000000<=sp<=0x20017fff: v="inside SRAM1 (ROM accepts)"
    else: v="outside SRAM1 (ROM rejects it)"
    print(f"{n} SP {sp:#010x}: {v}; reset vector {rv:#010x}")
PY2
# Clearing BFB2 makes the next boot run bank 1 directly, with no ROM check. Refuse unless bank 1 looks like
# a real image: initial SP in SRAM and an odd (Thumb) reset vector inside bank 1.
if ! python3 -I -c "import struct,sys;sp,rv=struct.unpack_from('<II',open(sys.argv[1],'rb').read(),0);sys.exit(0 if 0x20000000<sp<=0x20020000 and rv&1 and 0x08000000<=rv<0x08040000 else 1)" "$D/3-flash.bin"; then
  echo "bank 1 has no bootable image (vector words above). Clearing BFB2 would boot it; not writing."
  echo "If the firmware is in bank 2 instead, this is a different state from docs/14; keep 3-flash.bin and stop."; exit 10; fi
if [ $(( OPTR >> 20 & 1 )) -eq 0 ]; then
  echo "BFB2 is already 0: clearing it is not the fix. Inspect the bank vectors above and 3-flash.bin. Stopping."; exit 3; fi
if [ -n "${RV:-}" ] && [ "$RV" -ge $((0xD5)) ]; then
  echo "This ROM is V13.5 or later, which accepts a CCM stack pointer (AN2606 Table 102: 'Add CCSRAM/ENGI"
  echo "support'). On it the ROM should have started v5 or v7, so the diagnosis in docs/14 does not explain"
  echo "this unit. Clearing BFB2 boots bank 1 directly and is probably still harmless, but the cause is"
  echo "something else; the flash backup in $D is the thing to study first."
  read -r -p "type V135-CONTINUE to clear BFB2 anyway, anything else to stop: " ok135
  [ "$ok135" = V135-CONTINUE ] || { echo "stopped before any write"; exit 12; }
fi
read -r -p "[4] write OPTR with BFB2=0 (MCU resets afterwards)? type YES: " ok; [ "$ok" = YES ] || { echo "stopped before any write"; exit 0; }
python3 -I - "$D/2-ob.bin" "$D/4-ob-new.bin" <<'PY'
import struct,sys; d=bytearray(open(sys.argv[1],'rb').read()); old,comp=struct.unpack_from('<II',d,0)
assert comp == (~old & 0xffffffff), f"unexpected OB layout: {old:#x} / {comp:#x} - stop"
assert (old & 0xff) == 0xaa, "RDP is not level 0 (0xAA) - stop, never touch RDP"
v = old & ~(1<<20)
assert len(d)==48, f"need the full 48-byte option block, got {len(d)}"
names=["OPTR","PCROP1_START","PCROP1_END","WRP1A","WRP1B","SEC1"]   # RM0440 Table 11, bank-1 block
for i,n in enumerate(names):
    wv,wc=struct.unpack_from('<II',d,8*i)
    assert wc==(~wv)&0xffffffff, f"{n} @0x{0x1FFF7800+8*i:08X}: {wv:#010x}/{wc:#010x} is not value+complement - stop, read looks corrupt"
    print(f"  {n:13s} {wv:#010x}")
assert v == old & ~(1<<20) and (v & 0xff) == 0xaa, f"internal: new OPTR {v:#010x} is not old {old:#010x} with only BFB2 cleared - stop"
struct.pack_into('<II',d,0,v,(~v)&0xffffffff)
# AN3155: a Write Memory to the option area erases ALL option bytes first, so write back the whole
# 48-byte block as read, with only OPTR/its complement changed.
open(sys.argv[2],'wb').write(bytes(d)); print(f"OPTR {old:#010x} -> {v:#010x} (full 48-byte block rewritten)")
PY
if ! $BL write 0x1FFF7800 "$D/4-ob-new.bin" | tee "$D/4-write.txt"; then
  echo "Write did not get an ACK. Checking whether it took (the ROM resets after an option-byte write)..."; fi
sleep 3
echo "[5] verify: reconnect and read OPTR back"
if $BL read 0x1FFF7800 48 "$D/5-ob-after.bin" 2>/dev/null; then
  NEWV=$(python3 -I -c "import struct,sys;print(hex(struct.unpack('<I',open(sys.argv[1],'rb').read()[:4])[0]))" "$D/5-ob-after.bin")
  echo "OPTR after: $NEWV"
  python3 -I -c "import sys;a=open(sys.argv[1],'rb').read();b=open(sys.argv[2],'rb').read();diff=[i for i in range(48) if a[i]!=b[i]];print('bytes changed vs before:',diff);sys.exit(0 if set(diff)<=set(range(8)) else 1)" "$D/2-ob.bin" "$D/5-ob-after.bin" || { echo "WARNING: option bytes outside OPTR changed - inspect 2-ob.bin vs 5-ob-after.bin"; exit 8; }
  if [ -f "$D/2-ob2.bin" ] && $BL read 0x1FFFF800 48 "$D/5-ob2-after.bin" >/dev/null 2>&1; then
    if cmp -s "$D/2-ob2.bin" "$D/5-ob2-after.bin"; then echo "bank-2 option bytes unchanged"
    else
      echo "BANK-2 OPTION BYTES CHANGED by the ROM's option erase. Before / after:"; xxd "$D/2-ob2.bin"; xxd "$D/5-ob2-after.bin"
      echo "BFB2 is cleared, so bank 1 (v7) boots regardless. Restore the bank-2 block from 2-ob2.bin before"
      echo "relying on bank 2: STM32CubeProgrammer, Option Bytes view, set PCROP2/WRP2A/WRP2B/SEC2 to the 'before' values."
      exit 9
    fi
  fi
  [ $(( NEWV >> 20 & 1 )) -eq 0 ] && echo "SUCCESS: BFB2 is clear. Disconnect the ESP32 (GPIO17 at least), then power-cycle; the MCU boots bank 1 (v7), which drives the same lines." || { echo "FAILED: BFB2 still set."; exit 6; }
else
  # With BFB2 cleared the reset after an option-byte write boots bank 1 directly, so the ROM is gone:
  # this is what a successful write looks like on real silicon, but the new bytes could not be read back.
  echo "WRITE SENT, NOT READ BACK: the MCU left the ROM after the write, which is what clearing BFB2 does."
  echo "Disconnect the ESP32 (GPIO17 at least), power-cycle, and confirm from the panel (README step 6):"
  echo "  0x143 'A5 B0 8F 07' once a second means v7 is running and the fix took."
  echo "  Nothing on 0x143 after that: reconnect and rerun this script; step 1 will say what state it is in."
  exit 0
fi
