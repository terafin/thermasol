#!/bin/bash
# Shared config + helpers for the panel pipeline. Every value here is a FACT read off the
# panel or the build tree on 2026-11-25 — change it only by re-reading the source of truth.
set -euo pipefail

# Site-specific settings (panel address, Home Assistant, how to fetch its token) live in a git-ignored
# local.env next to this file; see local.env.example. Everything below has a generic default.
[ -f "$(dirname "${BASH_SOURCE[0]}")/local.env" ] && . "$(dirname "${BASH_SOURCE[0]}")/local.env"

BT=${BT:-$HOME/android15-build/imx-android-15.0.0_1.2.0/android_build}
# The panel runs a RELEASED build (AP4A.250205.002, codename REL, SDK 35). Building with the
# pre-release trunk_staging config gives APEXes minSdkVersion="VanillaIceCream", which a released
# device refuses to activate (boot hangs before logd). Always build with the panel's release config.
LUNCH=dart_mx8mm-ap4a-userdebug
H=$BT/out/host/linux-x86/bin
export PATH=$H:$PATH                     # avbtool needs 'fec' from here
AVB=$H/avbtool
MKFS=$H/mkfs.erofs
KEY=$BT/device/nxp/common/security/testkey_rsa4096.pem   # device root of trust (NOT external/avb)
ADB=${ADB:-$HOME/Android/Sdk/platform-tools/adb}
PANEL=${PANEL:?set PANEL=<panel-ip>:5555 in local.env}

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
WORK=${WORK:-$HOME/panel-work}           # inputs + outputs live here, never in the repo
BASE=$WORK/base                          # pinned source images (pulled once, sha-checked)
OUT=$WORK/out                            # build outputs

VENDOR_PSIZE=536870912
VENDOR_SALT=13e2bee85b30e14c8301591a11b4d763c5259dabce29640ec24e598e3bc4effb
VBMETA_PSIZE=1048576
SYSTEM_PSIZE=1879048192
SYSTEM_SALT=13e2bee85b30e14c8301591a11b4d763c5259dabce29640ec24e598e3bc4effb
TREE=$BT/out/target/product/dart_mx8mm
FW_JARS="framework/services.jar framework/oat/arm64/services.odex framework/oat/arm64/services.vdex framework/oat/arm64/services.art"

# Known-good base images (live slot _b, 2026-11-25). Builds start from these, nothing else.
declare -A BASE_SHA=(
  [vendor]=e9fd60309697e8fad04c2d3509cc7b0205a9d9ca8fc479b15a742551f426884e
  [boot]=5d81612048846396a2a93fc5b7a2da7157c6c7146414f773fab641d09db820dd
  [dtbo]=c9d519893db938fa9c8133943911ba63d528cc408ab30107bc784e9f818f538c
  [product]=839432b1eb6ac636703ac00939bb694515202284b5c39f01a65174996e8bad5f
  [system]=2c838f0bef27d9a6b472a03609e335f1376a3ef09836e1bc803241d048e1e81d
)

# A/B record (AvbABData) lives at misc + 0x800, 32 bytes, big-endian CRC32 over the first 28.
MISC_AB_OFFSET=2048

die()  { echo "FAIL: $*" >&2; exit 1; }
step() { echo; echo "=== $* ==="; }
ok()   { echo "  ok: $*"; }

sha() { sha256sum "$1" | cut -d' ' -f1; }

adb_up() {
  # adb root restarts adbd; on a just-booted panel that races the check, so retry to a deadline.
  local end=$(( $(date +%s) + 60 ))
  while :; do
    timeout 8 "$ADB" connect "$PANEL" >/dev/null 2>&1 || true
    timeout 8 "$ADB" -s "$PANEL" root >/dev/null 2>&1 || true
    sleep 2
    timeout 8 "$ADB" connect "$PANEL" >/dev/null 2>&1 || true
    [ "$(timeout 8 "$ADB" -s "$PANEL" shell id -u </dev/null 2>/dev/null | tr -d '\r')" = 0 ] && break
    [ "$(date +%s)" -lt "$end" ] || die "adb is not root on $PANEL"
    sleep 3
  done
}
# The first 8 MB of the eMMC user area hold the bootloader, the GPT and the U-Boot environment
# (with the network recovery hook); boot0/boot1 are the eMMC boot areas. Nothing here may write
# them: every panel command is refused if it names a raw eMMC device as a write target.
FIRST_PART_SECTOR=16384
guard_cmd() {
  case "$*" in
    *of=/dev/block/mmcblk2[!p]*|*of=/dev/block/mmcblk2|*of=/dev/block/mmcblk2\ *|*">"*force_ro*|*"> "*force_ro*|*">"*mmcblk2boot*|*"> "*mmcblk2boot*)
      die "refused: command would write a raw eMMC area (bootloader/GPT/env/boot0-1): $*";;
  esac
}
sh_p() { guard_cmd "$@"; "$ADB" -s "$PANEL" shell "$@" </dev/null | tr -d '\r'; }
slot()  { sh_p getprop ro.boot.slot_suffix; }
other() { [ "$1" = _a ] && echo _b || echo _a; }
booted(){ [ "$(sh_p getprop sys.boot_completed)" = 1 ]; }

part_sha() {   # $1=by-name partition  [$2=bytes to hash, default whole]
  if [ -n "${2:-}" ]; then sh_p "head -c $2 /dev/block/by-name/$1 | sha256sum" | cut -d' ' -f1
  else sh_p "sha256sum /dev/block/by-name/$1" | cut -d' ' -f1; fi
}

# Write a host image into a by-name partition over adb, verified. adb exec-in is NOT used: it
# delivered the right byte count with wrong content in 1 of 3 tests. Each 256 MiB chunk is pushed
# as a file, its sha checked on the panel, then dd'd to its offset; the whole partition is read
# back at the end. Never targets a raw eMMC device (sh_p refuses).
write_part_verified() {   # $1 = host file, $2 = by-name partition
  local f=$1 p=$2 want size n i c cw CHB=268435456 tmp
  want=$(sha "$f"); size=$(stat -c %s "$f")
  [ "$size" -le "$(sh_p "blockdev --getsize64 /dev/block/by-name/$p")" ] || die "$p: image larger than the partition"
  tmp=$(mktemp -d); n=$(( (size + CHB - 1) / CHB ))
  for i in $(seq 0 $((n - 1))); do
    c=$tmp/chunk; dd if="$f" of="$c" bs=$CHB skip="$i" count=1 status=none || { rm -rf "$tmp"; die "split $p"; }
    cw=$(sha "$c")
    "$ADB" -s "$PANEL" push "$c" /data/local/tmp/wp.chunk >/dev/null || { rm -rf "$tmp"; die "push $p chunk $i"; }
    [ "$(sh_p "sha256sum /data/local/tmp/wp.chunk" | cut -d' ' -f1)" = "$cw" ] || { rm -rf "$tmp"; die "$p chunk $i: pushed copy differs"; }
    sh_p "dd if=/data/local/tmp/wp.chunk of=/dev/block/by-name/$p bs=$CHB seek=$i conv=notrunc,fsync 2>/dev/null; rm -f /data/local/tmp/wp.chunk"
  done
  rm -rf "$tmp"
  sh_p "sync; blockdev --flushbufs /dev/block/by-name/$p; echo 3 > /proc/sys/vm/drop_caches"
  [ "$(part_sha "$p" "$size")" = "$want" ] || die "$p readback differs from $(basename "$f")"
}

ab_read() { sh_p "dd if=/dev/block/by-name/misc bs=1 skip=$MISC_AB_OFFSET count=32 2>/dev/null | od -An -tx1" | tr -s ' \n' ' ' | sed 's/^ //;s/ $//'; }

# Build a 32-byte AvbABData record: ab_make PRI_A TRIES_A SUCC_A PRI_B TRIES_B SUCC_B -> hex
ab_make() {
  python3 - "$@" <<'PY'
import sys, zlib, struct
pa, ta, sa, pb, tb, sb = map(int, sys.argv[1:])
assert 0 <= pa <= 15 and 0 <= pb <= 15 and 0 <= ta <= 7 and 0 <= tb <= 7
body = b"\0AB0" + bytes([1, 0, 0, 0]) + bytes([pa, ta, sa, 0, pb, tb, sb, 0]) + bytes(12)
rec = body + struct.pack(">I", zlib.crc32(body) & 0xffffffff)
print(rec.hex(" "))
PY
}

# Decode a record and refuse anything malformed. Prints "A{p,t,s} B{p,t,s}".
ab_decode() {
  python3 - "$1" <<'PY'
import sys, zlib, struct
b = bytes.fromhex(sys.argv[1].replace(" ", ""))
assert len(b) == 32, "record must be 32 bytes"
assert b[:4] == b"\0AB0", "bad magic"
crc = struct.unpack(">I", b[28:])[0]
assert crc == zlib.crc32(b[:28]) & 0xffffffff, "bad CRC"
print("A{%d,%d,%d} B{%d,%d,%d}" % (b[8], b[9], b[10], b[12], b[13], b[14]))
PY
}

ab_write() {   # $1 = hex record; writes, reads back, byte-compares
  local rec=$1 tmp; tmp=$(mktemp)
  ab_decode "$rec" >/dev/null || die "refusing to write malformed record"
  python3 -c "import sys;open(sys.argv[1],'wb').write(bytes.fromhex(sys.argv[2].replace(' ','')))" "$tmp" "$rec"
  "$ADB" -s "$PANEL" push "$tmp" /data/local/tmp/ab.bin >/dev/null; rm -f "$tmp"
  sh_p "dd if=/data/local/tmp/ab.bin of=/dev/block/by-name/misc bs=1 seek=$MISC_AB_OFFSET count=32 conv=notrunc,fsync 2>/dev/null; rm -f /data/local/tmp/ab.bin; sync"
  [ "$(ab_read)" = "$rec" ] || die "A/B readback mismatch: wanted [$rec] got [$(ab_read)]"
  ok "A/B record now $(ab_decode "$rec")"
}

wait_boot() {  # $1 = expected slot, $2 = timeout seconds (wall clock)
  local want=$1 t=${2:-240} end
  end=$(( $(date +%s) + t ))
  sleep 20
  while [ "$(date +%s)" -lt "$end" ]; do
    timeout 8 "$ADB" connect "$PANEL" >/dev/null 2>&1 || true
    if [ "$(timeout 8 "$ADB" -s "$PANEL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; then break; fi
    sleep 5
  done
  [ "$(timeout 8 "$ADB" -s "$PANEL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] \
    || die "panel did not finish booting within ${t}s"
  adb_up
  [ "$(slot)" = "$want" ] || die "booted slot $(slot), expected $want"
  ok "booted on $want"
}

# --- panel power via Home Assistant (token never stored in the repo) ---
# HA_TOKEN, or HA_TOKEN_CMD (a command that prints the token, e.g. a password-manager CLI).
HA_URL=${HA_URL:-http://homeassistant.local:8123}
HA_SWITCH=${HA_SWITCH:-switch.steam_shower_power}
ha_token() {
  if [ -n "${HA_TOKEN:-}" ]; then printf '%s' "$HA_TOKEN"
  elif [ -n "${HA_TOKEN_CMD:-}" ]; then eval "$HA_TOKEN_CMD"
  else die "set HA_TOKEN or HA_TOKEN_CMD in local.env (needed to power-cycle the panel)"; fi
}
ha_state() {
  curl -s --max-time 10 -H "Authorization: Bearer $(ha_token)" "$HA_URL/api/states/$HA_SWITCH" \
    | python3 -c 'import json,sys;print(json.load(sys.stdin).get("state",""))'
}
ha_switch() {  # $1 = on|off ; verifies the state took
  curl -s --max-time 15 -o /dev/null -H "Authorization: Bearer $(ha_token)" -H "Content-Type: application/json" \
    -d "{\"entity_id\":\"$HA_SWITCH\"}" "$HA_URL/api/services/switch/turn_$1" || return 1
  sleep 2; [ "$(ha_state)" = "$1" ]
}
power_cycle() {
  step "power-cycle the panel (Home Assistant $HA_SWITCH)"
  ha_switch off || die "could not turn panel power off"; ok "power off"
  sleep 15
  ha_switch on || die "could not turn panel power on"; ok "power on"
}
