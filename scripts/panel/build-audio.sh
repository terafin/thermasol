#!/bin/bash
# Build the vendor audio APEX (reference AIDL audio service, NXP's copy, plus the Sonos module)
# from the pinned tree. Records its sha so build.sh refuses an APEX it did not produce.
source "$(dirname "$0")/lib.sh"
P=$REPO/scripts/panel/overlay/audio-tree.patch
if [ -s "$P" ]; then
  step "apply audio-tree.patch (reference audio service + Sonos module, against NXP android-15.0.0_1.2.0)"
  cd "$BT" || die "no build tree"
  if patch -p1 -R --dry-run -s -f < "$P" >/dev/null 2>&1; then ok "already applied"
  else patch -p1 -s -f < "$P" || die "audio-tree.patch does not apply"; ok "applied"; fi
fi
# The Sonos module runs inside the shared audio service: a send() to a player that hung up raises
# SIGPIPE and kills every audio module, silently (no tombstone). Every send() must use MSG_NOSIGNAL.
SRC=$BT/vendor/nxp-opensource/imx/audio/default/sonos
bad=$(grep -nE "\bsend\(" "$SRC"/*.cpp "$SRC"/*.h 2>/dev/null | grep -v MSG_NOSIGNAL || true)
[ -z "$bad" ] || die "send() without MSG_NOSIGNAL in the Sonos module (SIGPIPE would kill the audio service): $bad"
ok "Sonos module: every send() is SIGPIPE-safe"
step "build com.android.hardware.audio (audio service + Sonos module)"
cd "$BT" || die "no build tree"
L=$WORK/build-audio-$(date +%s).log
( set +u; source build/envsetup.sh >/dev/null && lunch $LUNCH >/dev/null && m -j16 com.android.hardware.audio ) > "$L" 2>&1 \
  || { grep -E "error:|FAILED:" "$L" | head -20; die "audio build failed (log $L)"; }
A=$TREE/vendor/apex/com.android.hardware.audio.apex
[ -s "$A" ] || die "build produced no $A"
# The APEX must verify: its payload's AVB footer is checked against the public key it ships with.
X=$(mktemp -d); ( cd "$X" && unzip -q -o "$A" apex_payload.img apex_pubkey ) || die "APEX has no payload/pubkey"
"$H/avbtool" verify_image --image "$X/apex_payload.img" 2>&1 | grep -q "verified sha256 hashtree" \
  || { rm -rf "$X"; die "audio APEX payload signature/hashtree does not verify"; }
k=$("$H/avbtool" info_image --image "$X/apex_payload.img" | sed -nE 's/.*Public key \(sha1\): *([0-9a-f]+).*/\1/p')
[ -n "$k" ] && [ "$k" = "$(sha1sum "$X/apex_pubkey" | cut -d' ' -f1)" ] \
  || { rm -rf "$X"; die "audio APEX payload is not signed by the apex_pubkey it ships"; }
rm -rf "$X"; ok "audio APEX payload verifies (signature + hashtree, signed by its apex_pubkey)"
sha "$A" > "$TREE/.audio-hal.sha"; ok "audio APEX $(sha "$A" | cut -c1-16)"
step "AUDIO OK"
