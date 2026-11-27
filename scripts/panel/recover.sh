#!/bin/bash
# Recover a panel that will not boot: over TFTP, U-Boot rewrites the A/B record so <slot> is
# active, then falls through to normal boot (boota). Use when adb is gone (hung trial boot).
# Usage: recover.sh _b      (then the script power-cycles the panel via Home Assistant)
# Proven recipe (Nov 22/25): eMMC is mmc dev 1, load at 0x60000000, never 'reset' at the end.
source "$(dirname "$0")/lib.sh" || { echo "FAIL: cannot load lib.sh next to $0" >&2; exit 1; }
SLOT=${1:?usage: recover.sh _a|_b}
case $SLOT in _a) REC=$(ab_make 15 0 1 14 0 1);; _b) REC=$(ab_make 14 0 1 15 0 1);; *) die "slot must be _a or _b";; esac
MISC_LBA=0x738000                      # misc partition start (GPT); A/B record at +0x800 = block +4
ADDR=0x60000000
step "build U-Boot script: misc A/B -> $(ab_decode "$REC")"
S=$WORK/recover; mkdir -p "$S"
# read 1 block (512 B) at misc+0x800, patch 32 bytes in RAM, write it back
BYTES=$(echo "$REC" | tr ' ' '\n')
{
  echo "mmc dev 1"
  echo "mmc read $ADDR $(printf '0x%x' $((MISC_LBA + 4))) 1"
  # write only if the block really holds an A/B record: magic 00 41 42 30 ("\0AB0") = LE word 0x30424100
  echo "if itest.l *$ADDR == 0x30424100; then"
  i=0; for b in $BYTES; do echo "  mw.b $(printf '0x%x' $((ADDR + i))) 0x$b 1"; i=$((i+1)); done
  echo "  mmc write $ADDR $(printf '0x%x' $((MISC_LBA + 4))) 1"
  echo "  echo tt-recover: A/B record set for $SLOT"
  echo "else"
  echo "  echo tt-recover: no A/B magic at misc+0x800, nothing written"
  echo "fi"
} > "$S/tt-recover.cmd"
/usr/bin/mkimage -A arm64 -T script -C none -n tt-recover -d "$S/tt-recover.cmd" "$S/tt-recover.scr" >/dev/null || die "mkimage failed"
sudo cp "$S/tt-recover.scr" /srv/tt-tftp/tt-recover.scr
ok "staged /srv/tt-tftp/tt-recover.scr"
# Only a fetch after this power cycle counts: an earlier recovery's "sent" line in the log would
# otherwise read as this one and remove the script before U-Boot asks for it.
since=$(date "+%Y-%m-%d %H:%M:%S")
power_cycle
step "wait for U-Boot to fetch the recovery script"
fetched() { journalctl -u tt-tftp --since "$since" --no-pager | grep -q "sent /srv/tt-tftp/tt-recover.scr"; }
for i in $(seq 1 24); do fetched && break; sleep 5; done
sudo rm -f /srv/tt-tftp/tt-recover.scr
fetched || die "U-Boot never fetched the recovery script"
ok "recovery script served; TFTP cleared"
wait_boot "$SLOT" 300
