#!/bin/bash
# Make a flash backup (recover.sh's 3-flash.bin, 512 KB) readable: split the banks, print each bank's
# vector words, firmware version banner and strings, compare bank 1 with ThermaSol's v5, and, if Ghidra
# is available (GHIDRA=<install dir>), decompile each non-blank bank.
# usage: analyze-backup.sh <3-flash.bin> [v5.bin]
set -euo pipefail
F=${1:?usage: analyze-backup.sh <3-flash.bin> [v5.bin]}; V5=${2:-}; O=${F%.bin}-analysis; mkdir -p "$O"
[ "$(stat -c %s "$F")" = 524288 ] || { echo "expected a 524288-byte backup"; exit 2; }
head -c 262144 "$F" | python3 -I -c "import sys;sys.stdout.buffer.write(sys.stdin.buffer.read().rstrip(b'\xff'))" > "$O/bank1.bin"
tail -c 262144 "$F" | python3 -I -c "import sys;sys.stdout.buffer.write(sys.stdin.buffer.read().rstrip(b'\xff'))" > "$O/bank2.bin"
for b in bank1 bank2; do
  n=$(stat -c %s "$O/$b.bin"); echo "== $b: $n bytes used"
  [ "$n" -gt 8 ] || { echo "   blank"; continue; }
  python3 -I - "$O/$b.bin" <<'PY'
import struct,sys,re
d=open(sys.argv[1],'rb').read(); sp,rv=struct.unpack_from('<II',d,0)
print(f"   SP {sp:#010x} ({'SRAM1, ROM accepts' if 0x20000000<=sp<=0x20017fff else 'outside SRAM1, ROM rejects on V13.4'})  reset {rv:#010x}")
for m in re.finditer(rb'HydroVive, firmware version[^\0]*',d): print('   banner:',m.group().decode(errors='replace'))
PY
  strings -n 6 "$O/$b.bin" > "$O/$b.strings.txt"; echo "   $(wc -l < "$O/$b.strings.txt") strings -> $b.strings.txt"
  sha256sum "$O/$b.bin" | sed 's/^/   /'
done
if [ -n "$V5" ]; then
  cmp -s "$O/bank1.bin" "$V5" && echo "bank 1 is byte-identical to the v5 image given" || echo "bank 1 differs from the v5 image given (expected if it holds v7)"
fi
if [ -n "${GHIDRA:-}" ] && [ -x "$GHIDRA/support/analyzeHeadless" ]; then
  S=$(cd "$(dirname "$0")" && pwd)/tools
  for b in bank1 bank2; do
    [ "$(stat -c %s "$O/$b.bin")" -gt 8 ] || continue
    P=$(mktemp -d /tmp/ghidra-proj-XXXXXX)   # Ghidra refuses project paths with a dot-directory (e.g. ~/.local)
    "$GHIDRA/support/analyzeHeadless" "$P" p -import "$O/$b.bin" -loader BinaryLoader \
      -loader-baseAddr 0x08000000 -processor ARM:LE:32:Cortex -scriptPath "$S" -postScript DecompAll.java "$O/$b.c" \
      > "$O/ghidra-$b.log" 2>&1 && echo "$b decompiled -> $b.c ($(grep -c '^// ==== ' "$O/$b.c") functions)" || echo "$b: Ghidra failed, see ghidra-$b.log"
    rm -r -- "$P"
  done
else echo "set GHIDRA=<ghidra install dir> to decompile"; fi
