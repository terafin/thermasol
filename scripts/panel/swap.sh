#!/bin/bash
# Make <slot> the slot that boots next, keeping the other slot bootable + successful as fallback,
# then reboot and confirm. Only ever changes the A/B record in misc.
#   swap.sh <_a|_b>            -> target becomes {pri15,tries0,succ1}, other {pri14,tries0,succ1}
#   swap.sh <_a|_b> --trial    -> target {pri15,tries4,succ0} (falls back after 4 failed boots)
source "$(dirname "$0")/lib.sh" || { echo "FAIL: cannot load lib.sh next to $0" >&2; exit 1; }
T=${1:?usage: swap.sh <_a|_b> [--trial]}; MODE=${2:-}
[ "$T" = _a ] || [ "$T" = _b ] || die "slot must be _a or _b"
adb_up; booted || die "panel not booted"
CUR=$(slot); O=$(other "$T")
step "current: slot=$CUR record=$(ab_decode "$(ab_read)")"
# the slot that stays as fallback must be the one we are running now OR already successful
if [ "$MODE" = --trial ]; then t=(15 4 0); else t=(15 0 1); fi
f=(14 0 1)
if [ "$T" = _a ]; then REC=$(ab_make "${t[@]}" "${f[@]}"); else REC=$(ab_make "${f[@]}" "${t[@]}"); fi
[ "$O" = "$CUR" ] || [ "$MODE" != --trial ] || die "trial target must be the INACTIVE slot (running $CUR)"
step "write ${T}${MODE:+ trial}: $(ab_decode "$REC")"
ab_write "$REC"
step "reboot"
"$ADB" -s "$PANEL" reboot || true
wait_boot "$T" 300
echo "record after boot: $(ab_decode "$(ab_read)")"
