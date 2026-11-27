#!/bin/bash
# AIDL audio VTS for the Sonos module, on the panel, silently. VtsHalAudioCoreTargetTest opens real
# output streams, and the Sonos module tells an amp to play each one; VTS writes zero-filled buffers,
# but every reachable amp is still muted first (confirmed over UPnP) and its mute restored after. An
# amp that answers but cannot be confirmed muted stops the run before anything is sent.
# Records the result against the audio APEX sha, so flash.sh can refuse audio code VTS has not passed.
source "$(dirname "$0")/lib.sh"
adb_up; booted || die "panel not booted"
U="$(dirname "$0")/sonos-upnp.sh"
VTS=$BT/out/target/product/dart_mx8mm/data/nativetest64/VtsHalAudioCoreTargetTest/VtsHalAudioCoreTargetTest
if [ ! -s "$VTS" ]; then
  step "build VtsHalAudioCoreTargetTest"
  ( cd "$BT" && set +u && source build/envsetup.sh >/dev/null && lunch $LUNCH >/dev/null && m -j16 VtsHalAudioCoreTargetTest ) \
    > "$WORK/vts-build.log" 2>&1 || die "VTS build failed ($WORK/vts-build.log)"
fi
step "mute every reachable amp"
MUTES=""
restore() { for m in $MUTES; do "$U" "${m%=*}" mute "${m#*=}" >/dev/null 2>&1 || true; done; }
trap restore EXIT
# Every amp the HAL lists (persisted, not just discovered now) is a port VTS may open: VTS picks
# whichever device port it likes, so one that cannot be confirmed muted stops the run.
LISTED=$(sh_p "getprop" | sed -nE 's/^\[persist\.vendor\.sonos\.amp\.[0-9]+\]: \[([0-9.]+)\|.*/\1/p' | sort -u)
[ -n "$LISTED" ] || die "no persisted amps read from the panel"
for ip in $LISTED; do
  was=$("$U" "$ip" getmute 2>/dev/null | tr -dc '01' || true)
  if [ -z "$was" ]; then
    # silent only if it is truly unreachable (an amp that is off cannot play); one that answers
    # anything on its Sonos port but will not report mute stops the run
    if ping -c1 -W2 "$ip" >/dev/null 2>&1 || curl -s -m3 -o /dev/null "http://$ip:1400/xml/device_description.xml"; then
      die "$ip answers but cannot confirm it muted — not running VTS"
    fi
    echo "  note: $ip is listed but unreachable (off): cannot play"; continue
  fi
  MUTES="$MUTES $ip=$was"
  "$U" "$ip" mute 1 >/dev/null 2>&1 || true
  [ "$("$U" "$ip" getmute 2>/dev/null | tr -dc '01' || true)" = 1 ] || die "could not confirm $ip muted — not running VTS"
  ok "$ip muted"
done
[ -n "$MUTES" ] || die "no amp confirmed muted — not running VTS"
step "VtsHalAudioCoreTargetTest --gtest_filter=*IModule_sonos*"
# VTS owns the HAL while it runs: with audioserver up, its sound-dose callback is already
# registered on every module and the test's "first" registration fails on stock modules too.
"$ADB" -s "$PANEL" push "$VTS" /data/local/tmp/vts-audio >/dev/null
OUTF=$WORK/vts-sonos-$(date +%s).txt
trap 'restore; "$ADB" -s "$PANEL" shell "start audioserver" </dev/null >/dev/null 2>&1 || true' EXIT
"$ADB" -s "$PANEL" shell "stop audioserver" </dev/null
timeout 1200 "$ADB" -s "$PANEL" shell "chmod 755 /data/local/tmp/vts-audio; /data/local/tmp/vts-audio --gtest_filter=*IModule_sonos*; echo VTS_RC=\$?" </dev/null > "$OUTF" 2>&1 || true
"$ADB" -s "$PANEL" shell "rm -f /data/local/tmp/vts-audio; start audioserver" </dev/null || true
grep -E "^\[  (PASSED|FAILED) |FAILED TEST|VTS_RC" "$OUTF" | tail -8
RA=$(sh_p "sha256sum /vendor/apex/com.android.hardware.audio.apex" | cut -d' ' -f1)
if ! grep -q "VTS_RC=0" "$OUTF"; then
  restore; trap - EXIT; "$ADB" -s "$PANEL" shell "start audioserver" </dev/null >/dev/null 2>&1 || true
  if [ "${NO_ROLLBACK:-}" ]; then die "VTS failed (log $OUTF)"; fi
  echo "VTS failed (log $OUTF): rolling back to the fallback slot"
  "$(dirname "$0")/rollback.sh" || true
  die "VTS failed on audio APEX ${RA:0:16}; rolled back"
fi
echo "$RA" > "$TREE/.audio-vts.sha"
step "VTS OK"
