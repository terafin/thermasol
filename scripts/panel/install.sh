#!/bin/bash
# Install a published release onto the panel's INACTIVE slot, trial-boot it, and keep it only if the
# panel comes up healthy on it. The running slot is never written, so it stays the fallback.
#
#   install.sh <release-tag|dir> [--yes]
#     <release-tag>  e.g. v1.4-android15, downloaded from GitHub into $WORK/releases/<tag>
#     <dir>          a directory already holding boot dtbo system vendor product vbmeta .img + SHA256SUMS
#
# Order, each step refusing on any mismatch:
#   1. image set: SHA256SUMS match, and imgcheck.py verifies it the way the panel's U-Boot will
#   2. panel: this is a TT10V2 (dart_mx8mm, Android 15), booted, A/B record valid, partition sizes match
#   3. a verified backup.sh backup from this boot of this panel must exist (made here if missing)
#   4. write all six images to the inactive slot with write_part_verified (chunk sha + full readback)
#   5. arm a TRIAL on it (tries 4, not successful) and reboot. This panel's U-Boot picks by priority only,
#      so a slot that fails to boot does NOT fall back by itself: recover with recover.sh <running slot>
#   6. on the new slot: boot completed, SELinux enforcing, vbmeta digest = the image set's, then mark it
#      successful with the other slot kept bootable as the fallback
source "$(dirname "$0")/lib.sh" || { echo "FAIL: cannot load lib.sh next to $0" >&2; exit 1; }
SRC=${1:?usage: install.sh <release-tag|dir> [--yes]}; YES=${2:-}
PARTS="boot dtbo system vendor product vbmeta"
REPO_SLUG=${REPO_SLUG:-terafin/thermasol}
IMGCHECK=${IMGCHECK:-$(dirname "$0")/imgcheck.py}

step "image set"
if [ -d "$SRC" ]; then D=$(readlink -f "$SRC")
else
  D=$WORK/releases/$SRC; mkdir -p "$D"
  command -v gh >/dev/null || die "gh (GitHub CLI) is needed to download $SRC; or pass a directory"
  for f in $PARTS SHA256SUMS; do n=$f; [ "$f" = SHA256SUMS ] || n=$f.img
    [ -s "$D/$n" ] || gh release download "$SRC" -R "$REPO_SLUG" -p "$n" -D "$D" --clobber >/dev/null || die "download $n from $SRC"
  done
fi
for p in $PARTS; do [ -s "$D/$p.img" ] || die "$D/$p.img missing"; done
[ -s "$D/SHA256SUMS" ] || die "$D/SHA256SUMS missing"
(cd "$D" && sha256sum -c --quiet SHA256SUMS) || die "SHA256SUMS does not match the images in $D"
ok "SHA256SUMS match"
DIGEST=$(python3 -I "$IMGCHECK" release "$D" | sed -n 's/^vbmeta_digest=//p')
[ -n "$DIGEST" ] || die "imgcheck.py rejected the image set (run it by hand to see why)"
ok "imgcheck: signature, hashes and layout verify; vbmeta digest ${DIGEST:0:16}"

step "panel"
adb_up; booted || die "panel not booted"
[ "$(sh_p getprop ro.product.device)" = dart_mx8mm ] || die "not a TT10V2 (ro.product.device is not dart_mx8mm)"
[ "$(sh_p getprop ro.hardware)" = freescale ] || die "ro.hardware is not freescale"
[ "$(sh_p getprop ro.build.version.release)" = 15 ] || die "panel is not on Android 15 (install from stock: docs/09-install-from-stock.md)"
CUR=$(slot); TGT=$(other "$CUR")
REC=$(ab_read); ab_decode "$REC" >/dev/null || die "A/B record is not valid: [$REC]"
for p in $PARTS; do [ "$(sh_p "blockdev --getsize64 /dev/block/by-name/${p}${TGT}")" = "$(stat -c %s "$D/$p.img")" ] || die "$p.img is not the size of ${p}${TGT}"; done
ok "TT10V2 on Android 15, running $CUR, A/B $(ab_decode "$REC"); will write $TGT"
[ "$(sh_p getprop ro.boot.vbmeta.digest)" != "$DIGEST" ] || ok "note: the running slot already has this image set"

step "backup"
BOOTID=$(sh_p cat /proc/sys/kernel/random/boot_id)
BK=$WORK/backup/latest
if [ ! -f "$BK/SHA256SUMS" ] || [ "$(cat "$BK/boot_id" 2>/dev/null)" != "$BOOTID" ]; then
  "$(dirname "$0")/backup.sh" || die "backup failed; nothing was written"
  echo "$BOOTID" > "$WORK/backup/latest/boot_id"
fi
ok "verified backup of this boot: $(readlink -f "$BK")"

if [ "$YES" != --yes ]; then
  echo; echo "About to write $D to the INACTIVE slot $TGT (running $CUR stays the fallback)."
  read -r -p "Type the slot name ($TGT) to continue: " a; [ "$a" = "$TGT" ] || die "not confirmed; nothing was written"
fi

step "write $TGT"
[ "$(slot)" = "$CUR" ] || die "slot changed under us"
for p in $PARTS; do
  if [ "$(part_sha "${p}${TGT}")" = "$(sha "$D/$p.img")" ]; then ok "${p}${TGT} already matches"; continue; fi
  write_part_verified "$D/$p.img" "${p}${TGT}"; ok "${p}${TGT} written and verified"
done

step "trial boot $TGT"
"$(dirname "$0")/swap.sh" "$TGT" --trial || die "trial boot of $TGT failed; if the panel is dark: recover.sh $CUR"
[ "$(sh_p getenforce)" = Enforcing ] || die "booted $TGT but SELinux is not enforcing; run rollback.sh"
[ "$(sh_p getprop ro.boot.vbmeta.digest)" = "$DIGEST" ] || die "booted $TGT but its vbmeta digest is not the image set's; run rollback.sh"
ok "$TGT booted: enforcing, vbmeta digest matches"

step "keep $TGT"
if [ "$TGT" = _a ]; then ab_write "$(ab_make 15 0 1 14 0 1)"; else ab_write "$(ab_make 14 0 1 15 0 1)"; fi
ok "installed on $TGT; $CUR kept as the fallback. Run test.sh, and rollback.sh to go back."
