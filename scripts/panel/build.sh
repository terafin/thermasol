#!/bin/bash
# Build a signed vendor + vbmeta pair from: pinned base vendor + overlay/ + the HAL binary.
# No panel access. Fails closed at every check. Output: $OUT/<id>/{vendor.img,vbmeta.img,MANIFEST}
source "$(dirname "$0")/lib.sh"
AUDIO_APEX=$TREE/vendor/apex/com.android.hardware.audio.apex
OV=${OVERLAY:-$REPO/scripts/panel/overlay}

step "check inputs"
for p in vendor boot dtbo product system; do
  [ "$(sha "$BASE/$p.img")" = "${BASE_SHA[$p]}" ] || die "base $p missing or wrong sha — run pull-base.sh"
done
[ -s "$AUDIO_APEX" ] || die "audio APEX $AUDIO_APEX missing — run build-audio.sh"
[ "$(cat "$TREE/.audio-hal.sha" 2>/dev/null)" = "$(sha "$AUDIO_APEX")" ] || die "audio APEX was not built by build-audio.sh"
MINSDK=$("$H/aapt2" dump xmltree --file AndroidManifest.xml "$AUDIO_APEX" 2>/dev/null | sed -nE 's/.*minSdkVersion\([^)]*\)=([^ ]*).*/\1/p' | head -1)
[ "$MINSDK" = 35 ] || die "audio APEX minSdkVersion is [$MINSDK], not 35 — built with a pre-release config; the panel would refuse it"
[ -f "$KEY" ] || die "signing key $KEY missing"
ok "inputs pinned; audio APEX $(sha "$AUDIO_APEX" | cut -c1-16)"

ID=$(date -u +%Y%m%dT%H%M%SZ); D=$OUT/$ID; mkdir -p "$D"; T=$D/tree; MNT=$D/mnt
cleanup() { sudo umount "$MNT" 2>/dev/null || true; sudo rm -rf "$T" "$MNT" "$D/systree" "$D/smnt"; }
trap cleanup EXIT

step "unpack base vendor"
mkdir -p "$T" "$MNT"
sudo mount -o ro,loop "$BASE/vendor.img" "$MNT"
sudo cp -a "$MNT/." "$T/"
sudo umount "$MNT"

step "apply overlay"
CIL=$T/etc/selinux/vendor_sepolicy.cil
while IFS=$'\t' read -r old new; do
  [ -z "$old" ] && continue
  n=$(sudo grep -cxF -- "$old" "$CIL" || true)
  [ "$n" = 1 ] || die "cil replace: expected exactly 1 line matching [$old], found $n"
  sudo python3 - "$CIL" "$old" "$new" <<'PY'
import sys; p,o,n=sys.argv[1:]; s=open(p).read().split("\n"); s=[n if l==o else l for l in s]; open(p,"w").write("\n".join(s))
PY
  ok "cil replaced: $new"
done < "$OV/sepolicy.cil.replace"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  sudo grep -qxF -- "$line" "$CIL" && { ok "cil already has: $line"; continue; }
  echo "$line" | sudo tee -a "$CIL" >/dev/null; ok "cil added: $line"
done < "$OV/sepolicy.cil.add"

# delete-lines: each line of overlay/delete-lines is "<vendor-relpath><TAB><exact line>"; that line must
# appear exactly once in the base file and is removed (used to drop vendor boot triggers).
if [ -s "$OV/delete-lines" ]; then
  while IFS=$'\t' read -r rel line; do
    [ -z "$rel" ] && continue
    [ -f "$T/$rel" ] || die "delete-lines target $rel not in base vendor"
    n=$(sudo grep -cxF -- "$line" "$T/$rel" || true)
    [ "$n" = 1 ] || die "delete-lines: expected exactly 1 [$line] in $rel, found $n"
    sudo python3 - "$T/$rel" "$line" <<'PY'
import sys; p,o=sys.argv[1:]; s=open(p).read().split("\n"); open(p,"w").write("\n".join(l for l in s if l!=o))
PY
    ok "$rel: deleted [$line]"
  done < "$OV/delete-lines"
fi

# remove: each line of overlay/remove is a vendor path deleted from the base (must exist)
if [ -s "$OV/remove" ]; then
  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    sudo test -e "$T/$rel" || die "remove target $rel not in base vendor"
    sudo rm -rf "${T:?}/$rel"; ok "removed $rel"
  done < "$OV/remove"
fi

# append: each line of overlay/append/<vendor-relpath> is appended to that existing vendor file if absent
if [ -d "$OV/append" ]; then
  for rel in $(cd "$OV/append" && find . -type f | sed 's#^\./##'); do
    [ -f "$T/$rel" ] || die "append target $rel does not exist in base vendor"
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      sudo grep -qxF -- "$line" "$T/$rel" && { ok "$rel already has: $line"; continue; }
      echo "$line" | sudo tee -a "$T/$rel" >/dev/null; ok "$rel appended: $line"
    done < "$OV/append/$rel"
  done
fi

# files + labels: every overlay file must have a label line
( cd "$OV/files" && find . -type f ! -name .keep | sed 's#^\./##' ) | while read -r rel; do
  lab=$(awk -F'\t' -v p="$rel" '$1==p{print $2}' "$OV/labels")
  [ -n "$lab" ] || die "overlay file $rel has no label in overlay/labels"
  sudo install -D -m 0644 -o 0 -g 0 "$OV/files/$rel" "$T/$rel"
  sudo setfattr -n security.selinux -v "$lab" "$T/$rel"
  ok "file $rel [$lab]"
done
[ -n "${KEEP_BASE_APEX:-}" ] && ok "KEEP_BASE_APEX: leaving base audio APEX" || \
sudo install -m 0644 -o 0 -g 0 "$AUDIO_APEX" "$T/apex/com.android.hardware.audio.apex"
sudo setfattr -n security.selinux -v u:object_r:vendor_apex_file:s0 "$T/apex/com.android.hardware.audio.apex"
ok "audio APEX installed (reference audio service + Sonos module) [vendor_apex_file]"

step "label check (every overlay file + binary must carry its label)"
for rel in apex/com.android.hardware.audio.apex $(cut -f1 "$OV/labels" | grep . || true); do
  v=$(sudo getfattr -n security.selinux --only-values "$T/$rel" 2>/dev/null | tr -d '\0')
  [ -n "$v" ] && [ "$v" != u:object_r:unlabeled:s0 ] || die "$rel is unlabeled"
done
ok "labels present"

step "repack erofs + verity footer"
sudo "$MKFS" -zlz4hc,level=9 -C4096 --mount-point=/vendor "$D/vendor.img" "$T" >/dev/null
sudo chown "$(id -u):$(id -g)" "$D/vendor.img"
"$AVB" add_hashtree_footer --image "$D/vendor.img" --partition_name vendor \
  --partition_size $VENDOR_PSIZE --hash_algorithm sha256 --salt $VENDOR_SALT --rollback_index 0 --algorithm NONE
[ "$(stat -c%s "$D/vendor.img")" = $VENDOR_PSIZE ] || die "vendor image is not $VENDOR_PSIZE bytes"

SYSIMG=$BASE/system.img
if [ -s "$OV/framework.patch" ] && [ -z "${NO_FRAMEWORK:-}" ]; then
  step "system: pinned base + rebuilt services.jar (framework.patch)"
  for f in $FW_JARS; do [ -s "$TREE/system/$f" ] || die "tree has no $f — run build-framework.sh"; done
  [ "$(cat "$TREE/.framework-patch.sha" 2>/dev/null)" = "$(sha "$OV/framework.patch")" ] \
    || die "tree services.jar was not built from overlay/framework.patch — run build-framework.sh"
  ST=$D/systree; SMNT=$D/smnt; mkdir -p "$ST" "$SMNT"
  sudo mount -o ro,loop "$BASE/system.img" "$SMNT"; sudo cp -a "$SMNT/." "$ST/"; sudo umount "$SMNT"
  for f in $FW_JARS; do
    lab=$(sudo getfattr -n security.selinux --only-values "$ST/system/$f" | tr -d '\0')
    [ -n "$lab" ] || die "base system/$f has no label"
    sudo install -m 0644 -o 0 -g 0 "$TREE/system/$f" "$ST/system/$f"
    sudo setfattr -n security.selinux -v "$lab" "$ST/system/$f"
    ok "system/$f replaced [$lab]"
  done
  if [ -d "$OV/system-files" ]; then
    for rel in $(cd "$OV/system-files" && find . -type f | sed 's#^\./##'); do
      lab=$(awk -F'\t' -v p="$rel" '$1==p{print $2}' "$OV/system-labels")
      [ -n "$lab" ] || die "system overlay file $rel has no label in overlay/system-labels"
      sudo install -D -m 0644 -o 0 -g 0 "$OV/system-files/$rel" "$ST/$rel"
      sudo setfattr -n security.selinux -v "$lab" "$ST/$rel"
      ok "system file $rel [$lab]"
    done
  fi
  sudo "$MKFS" -zlz4hc,9 --mount-point=/ "$D/system.img" "$ST" >/dev/null
  sudo chown "$(id -u):$(id -g)" "$D/system.img"; sudo rm -rf "$ST" "$SMNT"
  "$AVB" add_hashtree_footer --image "$D/system.img" --partition_name system \
    --partition_size $SYSTEM_PSIZE --hash_algorithm sha256 --salt $SYSTEM_SALT --rollback_index 0 \
    --algorithm NONE --fec_num_roots 2 \
    $("$AVB" info_image --image "$BASE/system.img" | sed -nE "s/^ +Prop: (com[^ ]+) -> '(.*)'$/--prop \1:\2/p")
  [ "$(stat -c%s "$D/system.img")" = $SYSTEM_PSIZE ] || die "system image is not $SYSTEM_PSIZE bytes"
  SYSIMG=$D/system.img
fi

step "sign vbmeta (SHA256_RSA4096, device key)"
"$AVB" make_vbmeta_image --output "$D/vbmeta.img" \
  --include_descriptors_from_image "$BASE/boot.img" --include_descriptors_from_image "$BASE/dtbo.img" \
  --include_descriptors_from_image "$BASE/product.img" --include_descriptors_from_image "$SYSIMG" \
  --include_descriptors_from_image "$D/vendor.img" \
  --algorithm SHA256_RSA4096 --key "$KEY" --padding_size 4096 --rollback_index 0
truncate -s $VBMETA_PSIZE "$D/vbmeta.img"
"$AVB" info_image --image "$D/vbmeta.img" | grep -q 'Algorithm:.*SHA256_RSA4096' || die "vbmeta is not signed"

step "verify the whole chain"
V=$D/verify; mkdir -p "$V"
for p in boot dtbo product; do ln -sf "$BASE/$p.img" "$V/$p.img"; done; ln -sf "$SYSIMG" "$V/system.img"
ln -sf "$D/vendor.img" "$V/vendor.img"; cp "$D/vbmeta.img" "$V/vbmeta.img"
"$AVB" verify_image --image "$V/vbmeta.img" --key "$KEY" --follow_chain_partitions | tee "$D/verify.txt"
for p in vbmeta boot dtbo product system vendor; do grep -q "^$p: Successfully verified" "$D/verify.txt" || die "verify failed for $p"; done
rm -rf "$V"

{ echo "id=$ID"; echo "vendor=$(sha "$D/vendor.img")"; echo "vbmeta=$(sha "$D/vbmeta.img")"
  [ "$SYSIMG" = "$D/system.img" ] && echo "system=$(sha "$D/system.img")"
  echo "audio_apex=$(sha "$AUDIO_APEX")"; echo "overlay=$(cd "$OV" && find . -type f -exec sha256sum {} + | sort -k2 | sha256sum | cut -c1-16)"
  echo "repo=$(git -C "$REPO" rev-parse --short HEAD)$(git -C "$REPO" diff --quiet -- scripts/panel || echo -dirty)"; } > "$D/MANIFEST"
ln -sfn "$D" "$OUT/latest"
step "BUILD OK"; cat "$D/MANIFEST"
