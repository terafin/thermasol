#!/bin/bash
# Pass/fail check of the running panel. Read-only. Exit 0 only if EVERY check passes.
# Expected Sonos rooms come from the Sonos system itself (sonos-rooms.sh), so the panel must
# show every visible room by its real name. Override with EXPECT_ROOMS_FILE=<ip TAB name list>.
source "$(dirname "$0")/lib.sh" || { echo "FAIL: cannot load lib.sh next to $0" >&2; exit 1; }
OV=$REPO/scripts/panel/overlay
EXPECT=${EXPECT_ROOMS_FILE:-}
if [ -z "$EXPECT" ]; then EXPECT=$WORK/expected-rooms.tsv; "$(dirname "$0")/sonos-rooms.sh" > "$EXPECT" || die "could not read the Sonos room list"; fi
adb_up
# Wait for the audio HAL to settle: discovery may restart it once after boot to add a new amp or drop
# a device that cannot play, and a check taken mid-restart sees no outputs. Settled = the saved amp
# list has not changed and the HAL has been up, with the same pid, for 20 s.
settle_end=$(( $(date +%s) + 120 )); prev=""; same=0
while [ "$(date +%s)" -lt "$settle_end" ]; do
  cur="$(sh_p "pidof android.hardware.audio.service-aidl.imx; getprop | grep persist.vendor.sonos.amp" 2>/dev/null | md5sum)"
  if [ "$cur" = "$prev" ]; then same=$((same+5)); [ "$same" -ge 20 ] && break; else same=0; prev=$cur; fi
  sleep 5
done
fail=0
pass() { echo "  ok: $1"; }
bad()  { echo "  FAIL: $1"; fail=1; }

echo "slot=$(slot) enforce=$(sh_p getenforce) record=$(ab_decode "$(ab_read)")"
booted && pass "boot completed" || bad "boot completed"
[ "$(sh_p getenforce)" = Enforcing ] && pass "SELinux enforcing" || bad "SELinux enforcing"
[ "$(sh_p getprop init.svc.vendor.audio-hal-aidl)" = running ] && pass "audio service (hosts the Sonos module) running" || bad "audio service running"

# denials since this boot only (logcat -d covers the current boot's buffer)
AVC=$(sh_p "logcat -d -b all 2>/dev/null" | grep 'avc:.*denied' | grep 'hal_audio_sonos' | grep -v '{ list }' || true)
if [ -z "$AVC" ]; then pass "no hal_audio_sonos denials (known { list } ignored)"
else bad "hal_audio_sonos denials:"; echo "$AVC" | tail -5 | sed 's/^/      /'; fi

AP=$(sh_p "dumpsys media.audio_policy 2>/dev/null")
MODS=$(echo "$AP" | sed -nE 's/^ *[0-9]+\. Handle: [0-9]+; "([^"]+)"$/\1/p')
for m in primary usb r_submix bluetooth sonos; do
  if echo "$MODS" | grep -qx "$m"; then pass "audio module $m present"; else bad "audio module $m missing"; fi
done

# Every room is an AVAILABLE output device (attached bus device, address = player IP) ...
AVAIL=$(echo "$AP" | awk '/Available output devices/{f=1;next} f&&/^ *$/{f=0} f' \
        | sed -nE 's/.*\{AUDIO_DEVICE_OUT_BUS, @:([0-9.]+)\}.*/\1/p' | sort -u)
# ... and a system output route named after the room (what the output switcher shows)
MR=$(sh_p "dumpsys media_router 2>/dev/null")
ROUTES=$(echo "$MR" | sed -nE 's/.*SystemMediaRoute2Provider:ROUTE_ID_BUS_([0-9.]+) \| (.*)$/\1\t\2/p' | sort -u)
echo "  available sonos outputs: $(echo $AVAIL)"
echo "  sonos routes:"; echo "$ROUTES" | sed 's/^/      /'
while IFS=$'\t' read -r ip name; do
  [ -z "$ip" ] && continue
  echo "$AVAIL" | grep -qx "$ip" || { bad "room $name ($ip) is not an available output"; continue; }
  got=$(echo "$ROUTES" | awk -F'\t' -v ip="$ip" '$1==ip{print $2}' | head -1)
  if [ -z "$got" ]; then bad "room $name ($ip) has no output route"
  elif [ "$got" != "$name" ]; then bad "route $ip named [$got], expected [$name]"
  else pass "room $name ($ip) is an output"; fi
done < "$EXPECT"
extra=$(comm -13 <(cut -f1 "$EXPECT" | sort -u) <(echo "$ROUTES" | cut -f1 | grep . | sort -u) | grep . || true)
# A listed amp that did not answer discovery this time is a remembered amp that is switched off,
# not grouping; only a route that answers as a Sonos player under a different name is wrong.
for ip in $extra; do
  if curl -s -m4 "http://$ip:1400/xml/device_description.xml" | grep -q "<roomName>"; then
    bad "unexpected sonos route $ip (answers but not in discovery)"
  else echo "  note: $ip is listed but offline (remembered amp)"; fi
done
# every app remove-apps.sh retires must stay gone (one list, owned by remove-apps.sh)
RETIRED=$(sed -n '/^RETIRED="/,/"$/p' "$(dirname "$0")/remove-apps.sh" | tr -d '"' | sed 's/^RETIRED=//')
apps=""; installed=$(sh_p "pm list packages 2>/dev/null")
for pkg in $RETIRED; do echo "$installed" | grep -qx "package:$pkg" && apps="$apps $pkg"; done
[ -z "$apps" ] && pass "no retired apps installed" || bad "retired apps still installed:$apps (run remove-apps.sh)"
# The panel scales the stream before it reaches the amp; the bus volume must not sit at the quiet
# default (6/18), or every amp "plays" near-silence. The shower volume control moves it from 9 up.
busv=$(sh_p "dumpsys audio" | grep -A6 '^- STREAM_MUSIC' | sed -nE 's/.*\(bus\): ([0-9]+).*/\1/p' | head -1)
[ "${busv:-0}" -ge 9 ] && pass "amp media volume $busv/18 (not the quiet default)" \
  || bad "amp media volume is ${busv:-unset}/18: amps would play near-silence"

# Silent playback: mute an awake amp, route media to it, play digital silence through Android's own
# player, and confirm via UPnP that the amp is playing the panel's stream. Then restore everything.
[ -s "$WORK/panel-route.jar" ] || "$(dirname "$0")/build-route.sh" >/dev/null
"$ADB" -s "$PANEL" push "$WORK/panel-route.jar" /data/local/tmp/panel-route.jar >/dev/null
PR="CLASSPATH=/data/local/tmp/panel-route.jar app_process / PanelRoute"
U="$(dirname "$0")/sonos-upnp.sh"
PIP=$(sh_p "ip -4 addr show eth0" | sed -nE 's/.*inet ([0-9.]+).*/\1/p' | head -1)
# Every awake amp is tested in turn, which also proves switching from one amp to the next.
AMPS=""; for ip in $(echo "$AVAIL"); do [ -n "$("$U" "$ip" getmute 2>/dev/null || true)" ] && AMPS="$AMPS $ip"; done
MUTES=""   # "ip=mute" for each amp touched, restored on any exit
# put back the output the user had chosen (the panel saves every change as the sticky choice)
# the user's choice is the saved sticky route, not whatever media happens to be routed to right now
PREV=$(sh_p "settings get global thermasol_last_output_route" 2>/dev/null | sed -nE 's/^ROUTE_ID_BUS_([0-9.]+)$/\1/p')
PREV=${PREV:-speaker}
restore_all() {
  for m in $MUTES; do "$U" "${m%=*}" mute "${m#*=}" >/dev/null 2>&1 || true; done
  sh_p "$PR select $PREV" >/dev/null 2>&1 || true
}
trap restore_all EXIT
n=0
for AMP in $AMPS; do
  was=$("$U" "$AMP" getmute 2>/dev/null || true); MUTES="$MUTES $AMP=${was:-0}"
  if ! "$U" "$AMP" mute 1 >/dev/null 2>&1 || [ "$("$U" "$AMP" getmute 2>/dev/null || true)" != 1 ]; then
    bad "playback: could not confirm $AMP muted — not playing anything"; continue
  fi
  sh_p "$PR select $AMP" >/dev/null || true
  ( sh_p "$PR silence 10" > $WORK/.pr.$$ 2>&1 || true ) &
  # probes are observations: a failed call means "not playing yet", never a script error (set -e)
  uri=""; st=""
  for i in $(seq 1 16); do
    sleep 1
    uri=$("$U" "$AMP" uri 2>/dev/null || true); st=$("$U" "$AMP" state 2>/dev/null || true)
    if echo "$uri" | grep -q "$PIP" && [ "$st" = PLAYING ]; then break; fi
  done
  wait || true; routed=$(cat $WORK/.pr.$$ 2>/dev/null || true); rm -f $WORK/.pr.$$
  if echo "$uri" | grep -q "http://$PIP:" && [ "$st" = PLAYING ]; then
    pass "playback: $AMP playing the panel stream ($uri) [$routed]"; n=$((n+1))
  else bad "playback: $AMP state=[$st] uri=[$uri] routed=[$routed]"; fi
  "$U" "$AMP" mute "${was:-0}" >/dev/null 2>&1 || bad "playback: could not restore mute on $AMP"
done
sh_p "$PR select $PREV" >/dev/null || true
after=$(sh_p "settings get global thermasol_last_output_route" 2>/dev/null)
want=$([ "$PREV" = speaker ] && echo ROUTE_ID_BUILTIN_SPEAKER || echo "ROUTE_ID_BUS_$PREV")
[ "$after" = "$want" ] && pass "chosen output restored ($after)" || bad "chosen output not restored: [$after], expected [$want]"
[ "$n" -ge 2 ] || bad "playback: only $n amp(s) verified playing; need at least 2"

if [ $fail = 0 ]; then step "TEST PASS"; exit 0; else step "TEST FAIL"; exit 1; fi
