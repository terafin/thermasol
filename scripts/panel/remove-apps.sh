#!/bin/bash
# Remove everything that is not part of the shipped design from the running panel, and reclaim space.
# Idempotent. Audio goes through the native Sonos output devices, so no app belongs in the audio path:
#  - ShowerCast / tone / submix capture: the retired app-based Sonos path.
#  - ttaudio, ttaudiosource, airvia: the retired HydroVive / AirPlay audio path.
# Then clear caches that only hold downloaded models and voice packs; each app re-downloads on use.
source "$(dirname "$0")/lib.sh"
adb_up; booted || die "panel not booted"
step "uninstall apps that are not part of the design"
#  - ttvolume: a custom volume bubble; Android's own output picker (Quick Settings media card ->
#    output chip) already carries the volume slider for the selected amp, over the full range.
RETIRED="com.ghost.showercast com.ghost.tone com.ghost.submixcap
  net.siliconspirit.ttaudio net.siliconspirit.ttaudiosource com.opus.airvia
  net.siliconspirit.ttvolume"
for pkg in $RETIRED; do
  if sh_p "pm list packages $pkg" | grep -qx "package:$pkg"; then
    sh_p "pm uninstall $pkg" | grep -q Success || die "uninstall $pkg failed"; ok "uninstalled $pkg"
  else ok "$pkg not installed"; fi
done
step "clear downloaded model / voice caches"
before=$(sh_p "df -h /data | tail -1" | awk '{print $4}')
for pkg in com.google.android.inputmethod.latin com.google.android.as com.google.android.tts; do
  sh_p "pm list packages $pkg" | grep -qx "package:$pkg" || { ok "$pkg not installed"; continue; }
  sh_p "pm clear --cache-only $pkg" >/dev/null 2>&1 || true
  # only the downloaded model/voice packs; settings (shared_prefs, databases) are left alone
  sh_p "su 0 sh -c 'cd /data/data/$pkg/files 2>/dev/null && rm -rf datadownload superpacks share_content; rm -rf /data/data/$pkg/cache/*'" || true
  ok "$pkg caches cleared"
done
sh_p "pm trim-caches 999G" >/dev/null 2>&1 || true
after=$(sh_p "df -h /data | tail -1" | awk '{print $4}')
ok "free on /data: ${before} -> ${after}"
