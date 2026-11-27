#!/bin/bash
# Pull the known-good base images off the panel's CURRENT known-good slot, once, and pin them.
# Read-only on the panel. Refuses anything whose sha does not match lib.sh BASE_SHA.
# Usage: pull-base.sh <slot>   (the slot holding the known-good images, e.g. _b)
source "$(dirname "$0")/lib.sh" || { echo "FAIL: cannot load lib.sh next to $0" >&2; exit 1; }
SRC=${1:?usage: pull-base.sh <_a|_b>}
mkdir -p "$BASE"; adb_up
declare -A SIZE=([boot]=50331648 [dtbo]=4194304 [product]=1879048192 [system]=1879048192 [vendor]=536870912)
for p in vendor boot dtbo product system; do
  f=$BASE/$p.img
  if [ -f "$f" ] && [ "$(sha "$f")" = "${BASE_SHA[$p]}" ]; then ok "$p already pinned"; continue; fi
  step "pull ${p}${SRC}"
  "$ADB" -s "$PANEL" exec-out "cat /dev/block/by-name/${p}${SRC}" > "$f.part"
  [ "$(stat -c%s "$f.part")" = "${SIZE[$p]}" ] || die "$p: short read"
  [ "$(sha "$f.part")" = "${BASE_SHA[$p]}" ] || die "$p$SRC sha $(sha "$f.part") != pinned ${BASE_SHA[$p]}"
  mv "$f.part" "$f"; ok "$p pinned"
done
