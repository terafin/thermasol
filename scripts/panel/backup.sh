#!/bin/bash
# Read-only full backup of the panel's storage to $WORK/backup/<utc-time>/.
# Copies the eMMC boot partitions (boot0/boot1), the whole user area (GPT, bootloader at 0x8400,
# U-Boot environment, every slot partition, misc, metadata) and userdata separately, then checks
# each file's sha256 against the same bytes read on the panel. Nothing is written to the panel.
# Usage: backup.sh            (userdata is included; it is in use while copied, so best effort)
source "$(dirname "$0")/lib.sh"
adb_up; booted || die "panel not booted"
D=$WORK/backup/$(date -u +%Y%m%dT%H%M%SZ); mkdir -p "$D"
SEC() { sh_p "cat /sys/block/$1/size"; }
UD=$(sh_p "basename \$(readlink /dev/block/by-name/userdata)")
UD_START=$(sh_p "cat /sys/block/mmcblk2/$UD/start"); UD_SIZE=$(SEC "mmcblk2/$UD")
TOTAL=$(SEC mmcblk2)
[ -n "$UD_START" ] && [ -n "$UD_SIZE" ] && [ -n "$TOTAL" ] || die "could not read the partition layout"
AFTER=$((UD_START + UD_SIZE))
# name  device  first-sector  sector-count
PARTS="boot0 mmcblk2boot0 0 $(SEC mmcblk2boot0)
boot1 mmcblk2boot1 0 $(SEC mmcblk2boot1)
head mmcblk2 0 $UD_START
tail mmcblk2 $AFTER $((TOTAL - AFTER))
userdata mmcblk2 $UD_START $UD_SIZE"
step "backup to $D"
sh_p "cat /proc/partitions; ls -l /dev/block/by-name; getprop ro.build.fingerprint; getprop ro.boot.slot_suffix" > "$D/layout.txt"
ab_read > "$D/ab-record.hex"
while read -r name dev skip count; do
  [ "$count" -gt 0 ] || die "$name: empty"
  rd="dd if=/dev/block/$dev bs=512 skip=$skip count=$count 2>/dev/null"
  "$ADB" -s "$PANEL" exec-out "$rd" > "$D/$name.img" || die "$name: copy failed"
  [ "$(stat -c %s "$D/$name.img")" = $((count * 512)) ] || die "$name: short copy"
  want=$(sh_p "$rd | sha256sum" | cut -d' ' -f1); got=$(sha "$D/$name.img")
  if [ "$name" = userdata ]; then
    [ "$want" = "$got" ] && ok "userdata ($((count/2048)) MiB) matches" || ok "userdata copied; changed while in use (best effort)"
  else
    [ "$want" = "$got" ] || die "$name: sha mismatch (panel $want, copy $got)"; ok "$name ($((count/2048)) MiB) $got"
  fi
  echo "$got  $name.img  $dev skip=$skip count=$count" >> "$D/SHA256SUMS"
done <<< "$PARTS"
ln -sfn "$D" "$WORK/backup/latest"
ok "backup complete: $D"
