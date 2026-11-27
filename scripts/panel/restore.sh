#!/bin/bash
# Put one slot back from a backup.sh backup, then boot it. Two paths:
#   restore.sh <backup-dir|latest> <_a|_b>          Android is up: write the INACTIVE slot over adb,
#                                                   verify every partition, then swap.sh to it.
#   restore.sh <backup-dir|latest> <_a|_b> --uboot  Android is down: U-Boot writes the slot from TFTP
#                                                   (network recovery hook), sets the A/B record, boots.
# Only the six slot partitions (boot dtbo system vendor product vbmeta) and the A/B record are
# written. The bootloader, its environment, misc and userdata are never touched.
source "$(dirname "$0")/lib.sh"
B=${1:?usage: restore.sh <backup-dir|latest> <_a|_b> [--uboot]}; S=${2:?slot}; MODE=${3:-}
[ "$B" = latest ] && B=$WORK/backup/latest; B=$(readlink -f "$B")
[ "$S" = _a ] || [ "$S" = _b ] || die "slot must be _a or _b"
H=$B/head.img; [ -f "$H" ] && [ -f "$B/SHA256SUMS" ] || die "not a backup: $B"
step "verify backup $B"
# head.img = eMMC from sector 0 up to userdata; tail.img = everything after userdata (fbmisc, vbmeta)
for f in head.img tail.img; do
  [ -f "$B/$f" ] || die "$f missing from the backup"
  [ "$(sha "$B/$f")" = "$(awk -v f="$f" '$2==f{print $1}' "$B/SHA256SUMS")" ] || die "$f does not match its recorded sha"
  ok "$f sha matches"
done
TAIL_SKIP=$(awk '$2=="tail.img"{sub("skip=","",$4); print $4}' "$B/SHA256SUMS")
[ -n "$TAIL_SKIP" ] || die "tail.img has no recorded start sector"
# partition table from the backup's own GPT: name start-sector sector-count
PT=$(python3 - "$H" <<'PY'
import sys, struct
f = open(sys.argv[1], 'rb'); f.seek(512); h = f.read(92)
assert h[:8] == b'EFI PART', 'no GPT in backup'
lba, n, sz = struct.unpack('<QII', h[72:88])
f.seek(lba * 512)
for _ in range(n):
    e = f.read(sz)
    if e[:16] == bytes(16): continue
    first, last = struct.unpack('<QQ', e[32:48])
    print(e[56:128].decode('utf-16-le').rstrip('\0'), first, last - first + 1)
PY
) || die "could not read the backup's partition table"
PARTS="boot dtbo system vendor product vbmeta"
for p in $PARTS; do grep -q "^${p}${S} " <<< "$PT" || die "${p}${S} not in the backup's partition table"; done
HSEC=$(( $(stat -c %s "$H") / 512 )); TSEC=$(( $(stat -c %s "$B/tail.img") / 512 ))
X=$WORK/restore; rm -rf "$X"; mkdir -p "$X"
for p in $PARTS; do
  read -r _ st n <<< "$(grep "^${p}${S} " <<< "$PT")"
  if [ $((st + n)) -le "$HSEC" ]; then src=$H; off=$st
  elif [ "$st" -ge "$TAIL_SKIP" ] && [ $((st - TAIL_SKIP + n)) -le "$TSEC" ]; then src=$B/tail.img; off=$((st - TAIL_SKIP))
  else die "${p}${S} (sectors $st+$n) is in neither head.img nor tail.img"; fi
  dd if="$src" of="$X/${p}${S}.img" bs=512 skip="$off" count="$n" status=none || die "extract ${p}${S}"
  [ "$(stat -c %s "$X/${p}${S}.img")" = $((n * 512)) ] || die "extract ${p}${S}: short"
done
ok "extracted $PARTS for $S"
if [ "$S" = _a ]; then REC=$(ab_make 15 0 1 14 0 1); else REC=$(ab_make 14 0 1 15 0 1); fi

if [ "$MODE" != --uboot ]; then
  adb_up; booted || die "panel not booted — use --uboot"
  [ "$(slot)" != "$S" ] || die "$S is the running slot; restore the other one, or use rollback.sh first"
  # Send each image in 256 MiB chunks (system/product are 1.8 GB and do not fit in /data), check
  # each chunk on the panel, dd it to its offset, then read the whole partition back.
  CHB=268435456
  for p in $PARTS; do
    f=$X/${p}${S}.img; want=$(sha "$f"); size=$(stat -c %s "$f")
    [ "$(sh_p "blockdev --getsize64 /dev/block/by-name/${p}${S}")" = "$size" ] || die "${p}${S}: size differs from the backup"
    if [ "$(part_sha "${p}${S}")" = "$want" ]; then ok "${p}${S} already matches the backup"; continue; fi
    n=$(( (size + CHB - 1) / CHB ))
    for i in $(seq 0 $((n - 1))); do
      c=$X/chunk; dd if="$f" of="$c" bs=$CHB skip="$i" count=1 status=none || die "split ${p}${S}"
      cw=$(sha "$c")
      "$ADB" -s "$PANEL" push "$c" /data/local/tmp/rst.chunk >/dev/null || die "push ${p}${S} chunk $i"
      [ "$(sh_p "sha256sum /data/local/tmp/rst.chunk" | cut -d' ' -f1)" = "$cw" ] || die "${p}${S} chunk $i: pushed copy differs"
      sh_p "dd if=/data/local/tmp/rst.chunk of=/dev/block/by-name/${p}${S} bs=$CHB seek=$i conv=notrunc,fsync 2>/dev/null; rm -f /data/local/tmp/rst.chunk"
      rm -f "$c"
    done
    sh_p "sync; blockdev --flushbufs /dev/block/by-name/${p}${S}"
    [ "$(part_sha "${p}${S}")" = "$want" ] || die "${p}${S}: readback differs — do not boot $S"
    ok "${p}${S} written and verified ($n chunks)"
  done
  rm -rf "$X"
  "$(dirname "$0")/swap.sh" "$S"
  exit 0
fi

# --- U-Boot path: chunks over TFTP, written by the network recovery hook ---
CH=16777216; CS=$((CH / 512)); ADDR=0x48000000
T=/srv/tt-tftp; R=rst
if timeout 8 "$ADB" connect "$PANEL" >/dev/null 2>&1 && [ "$(timeout 8 "$ADB" -s "$PANEL" shell getprop ro.boot.slot_suffix 2>/dev/null | tr -d '\r')" = "$S" ]; then
  die "the panel is up and running $S; --uboot rewrites $S while it is the slot U-Boot falls back to — restore the other slot, or use the adb path"
fi
[ -z "$(ls -A "$T" 2>/dev/null)" ] || die "$T is not empty; clear it first (anything there runs on every boot)"
step "stage chunks in $T/$R"
sudo mkdir -p "$T/$R"
{
  echo "mmc dev 1"
  echo "setenv ttfail 0"
  # the hook gives up after ~3 s; a 4 GB restore needs patience and a retry per chunk
  echo "setenv tftptimeout 3000"
  echo "setenv tftptimeoutcountmax 10"
  for p in $PARTS; do
    read -r _ st n <<< "$(grep "^${p}${S} " <<< "$PT")"
    split -b $CH -d -a 3 "$X/${p}${S}.img" "$X/${p}${S}." || die "split ${p}${S}"
    i=0
    for c in "$X/${p}${S}".[0-9][0-9][0-9]; do
      cn=$(( ($(stat -c %s "$c") + 511) / 512 ))
      sudo cp "$c" "$T/$R/$(basename "$c")"
      cf=$R/$(basename "$c"); off=$(printf '0x%x' $((st + i * CS))); cnt=$(printf '0x%x' "$cn")
      echo "if test \$ttfail = 0; then setenv ttok 0; for try in 1 2 3; do if test \$ttok = 0; then if tftpboot $ADDR $cf; then setenv ttok 1; fi; fi; done; if test \$ttok = 1; then mmc write $ADDR $off $cnt; else setenv ttfail 1; echo tt-restore: FAILED $cf; fi; fi"
      i=$((i + 1))
    done
    echo "echo tt-restore: ${p}${S} done"
  done
  # only after every chunk landed: point the A/B record at the restored slot
  echo "if test \$ttfail = 0; then"
  echo "  mmc read $ADDR $(printf '0x%x' $(( $(grep '^misc ' <<< "$PT" | cut -d' ' -f2) + MISC_AB_OFFSET / 512 ))) 1"
  echo "  if itest.l *$ADDR == 0x30424100; then"
  j=0; for b in $REC; do echo "    mw.b $(printf '0x%x' $((ADDR + j))) 0x$b 1"; j=$((j + 1)); done
  echo "    mmc write $ADDR $(printf '0x%x' $(( $(grep '^misc ' <<< "$PT" | cut -d' ' -f2) + MISC_AB_OFFSET / 512 ))) 1"
  echo "    echo tt-restore: A/B record set for $S"
  echo "  fi"
  echo "  echo tt-restore: complete"
  echo "else"
  echo "  echo tt-restore: incomplete, A/B record left as it was"
  echo "fi"
} > "$X/tt-recover.cmd"
grep -q '^misc ' <<< "$PT" || die "misc not in the backup's partition table"
NCH=$(grep -c tftpboot "$X/tt-recover.cmd")
LAST=$(grep -o "$R/[a-z_]*\.[0-9]*" "$X/tt-recover.cmd" | tail -1)
/usr/bin/mkimage -A arm64 -T script -C none -n tt-restore -d "$X/tt-recover.cmd" "$X/tt-recover.scr" >/dev/null || die "mkimage failed"
sudo cp "$X/tt-recover.scr" "$T/tt-recover.scr"
ok "staged $NCH chunks + tt-recover.scr"
cleanup() { sudo rm -rf "$T/tt-recover.scr" "$T/$R"; rm -rf "$X"; }
trap cleanup EXIT
since=$(date '+%Y-%m-%d %H:%M:%S')   # before the power cycle: only this run's fetches count
power_cycle
step "wait for U-Boot to fetch every chunk (last: $LAST)"
sent() { journalctl -u tt-tftp --since "$since" --no-pager | grep -c "sent $T/$R/"; }
last=0; idle=0
until journalctl -u tt-tftp --since "$since" --no-pager | grep -q "sent $T/$LAST"; do
  sleep 10; now=$(sent)
  if [ "$now" -gt "$last" ]; then last=$now; idle=0; echo "  $now/$NCH chunks"; else idle=$((idle + 10)); fi
  [ "$idle" -lt 300 ] || die "no chunk fetched for 5 minutes ($last of $NCH); the A/B record is unchanged"
done
ok "U-Boot fetched every chunk ($(sent) transfers for $NCH chunks)"
sudo rm -f "$T/tt-recover.scr"   # never leave it: it would run again on the next power-on
wait_boot "$S" 300
for p in $PARTS; do
  [ "$(part_sha "${p}${S}")" = "$(sha "$X/${p}${S}.img")" ] || die "${p}${S} on the panel differs from the backup"
  ok "${p}${S} matches the backup"
done
