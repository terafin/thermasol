#!/bin/bash
# Flash a built vendor+vbmeta pair to the INACTIVE slot, then trial-boot it.
# Usage: flash.sh <build-dir|latest>
# Sequence (never touches the running slot):
#   1. if running _a: swap to _b first (so _a is inactive)
#   2. confirm the inactive slot's boot/dtbo/product/system == pinned base (vbmeta covers them)
#   3. dd vendor + vbmeta into the inactive slot, full-partition readback sha must match
#   4. arm a TRIAL on it and reboot; test.sh decides success
source "$(dirname "$0")/lib.sh" || { echo "FAIL: cannot load lib.sh next to $0" >&2; exit 1; }
D=${1:?usage: flash.sh <build-dir|latest>}; [ "$D" = latest ] && D=$OUT/latest
D=$(readlink -f "$D"); M=$D/MANIFEST; [ -f "$M" ] || die "no MANIFEST in $D"
VSHA=$(awk -F= '$1=="vendor"{print $2}' "$M"); BSHA=$(awk -F= '$1=="vbmeta"{print $2}' "$M")
[ "$(sha "$D/vendor.img")" = "$VSHA" ] && [ "$(sha "$D/vbmeta.img")" = "$BSHA" ] || die "build files do not match MANIFEST"
grep -q '^vbmeta: Successfully verified SHA256_RSA4096' "$D/verify.txt" || die "build did not verify"
SSHA=$(awk -F= '$1=="system"{print $2}' "$M")   # set only when the build carries a patched system
[ -z "$SSHA" ] || [ "$(sha "$D/system.img")" = "$SSHA" ] || die "system.img does not match MANIFEST"

"$(dirname "$0")/check-sepolicy.sh" "$D" || die "policy check failed"
"$(dirname "$0")/check-vintf.sh" "$D" || die "VINTF check failed"
# New audio code goes on the panel only after the AIDL audio VTS passed for that exact APEX
# (vts-audio.sh runs it against the APEX the panel is already running, which is the same one).
ASHA=$(awk -F= '$1=="audio_apex"{print $2}' "$M")
if [ -n "$ASHA" ]; then
  # VTS needs the HAL running, so a new APEX can only be tested on the panel: it goes to the inactive
  # slot as a trial (the running slot stays as fallback), vts-audio.sh tests it and rolls back on a
  # failure, and commit.sh refuses to keep an APEX without a recorded VTS pass.
  if [ "$(cat "$TREE/.audio-vts.sha" 2>/dev/null)" = "$ASHA" ]; then ok "audio APEX ${ASHA:0:16} passed VTS"
  else ok "audio APEX ${ASHA:0:16} not yet VTS-tested: trial only — run vts-audio.sh before commit.sh"; fi
fi
adb_up; booted || die "panel not booted"
TARGET=_a
if [ "$(slot)" = _a ]; then
  step "running _a: swap to _b first so _a is inactive"
  "$(dirname "$0")/swap.sh" _b
fi
[ "$(slot)" = _b ] || die "expected to be running _b"

step "inactive slot _a: covered partitions must equal pinned base"
COVERED="boot dtbo product"; [ -n "$SSHA" ] || COVERED="$COVERED system"
if [ -z "$SSHA" ]; then
  # build uses the base system: if system_a holds a patched system, put the base back (from system_b)
  sz=$(stat -c%s "$BASE/system.img")
  if [ "$(part_sha system_a "$sz")" != "${BASE_SHA[system]}" ]; then
    [ "$(part_sha system_b "$sz")" = "${BASE_SHA[system]}" ] || die "neither system slot holds the base system"
    step "system_a is not base: copy system_b -> system_a"
    sh_p "dd if=/dev/block/by-name/system_b of=/dev/block/by-name/system_a bs=4194304 conv=notrunc,fsync && sync"
    [ "$(part_sha system_a "$sz")" = "${BASE_SHA[system]}" ] || die "system_a copy did not verify"
    ok "system_a == base"
  fi
fi
for p in $COVERED; do
  sz=$(stat -c%s "$BASE/$p.img"); got=$(part_sha "${p}_a" "$sz")
  [ "$got" = "${BASE_SHA[$p]}" ] || die "${p}_a differs from base ($got) — vbmeta would fail. Copy ${p}_b to ${p}_a first."
  ok "${p}_a == base"
done

write_part() {  # $1 file $2 partition
  local f=$1 p=$2 want; want=$(sha "$f")
  step "write $(basename "$f") -> $p"
  [ "$(slot)" = _b ] || die "slot changed under us"
  "$ADB" -s "$PANEL" exec-in "dd of=/dev/block/by-name/$p bs=4194304 conv=notrunc,fsync" < "$f" \
    || die "write to $p failed"
  sh_p "sync; echo 3 > /proc/sys/vm/drop_caches"
  # read back from the partition (caches dropped); retry once before calling it a failure
  local got; got=$(part_sha "$p" "$(stat -c%s "$f")")
  if [ "$got" != "$want" ]; then
    sleep 5; sh_p "sync; echo 3 > /proc/sys/vm/drop_caches"
    got=$(part_sha "$p" "$(stat -c%s "$f")")
  fi
  [ "$got" = "$want" ] || die "$p readback $got != $want"
  ok "$p readback matches"
}
[ -n "$SSHA" ] && write_part "$D/system.img" system_a
write_part "$D/vendor.img" vendor_a
write_part "$D/vbmeta.img" vbmeta_a

if ! "$(dirname "$0")/swap.sh" _a --trial; then
  step "trial boot of _a failed: recovering to _b"
  "$(dirname "$0")/recover.sh" _b || die "AUTO-RECOVERY FAILED — panel needs attention"
  die "build $(awk -F= '$1=="id"{print $2}' "$M") did not boot; panel recovered to _b"
fi
echo "flashed $(awk -F= '$1=="id"{print $2}' "$M") to _a; now run test.sh"
