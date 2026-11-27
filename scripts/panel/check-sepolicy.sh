#!/bin/bash
# Compile a build's SELinux policy exactly as init does at boot (secilc, same args and files).
# A policy that fails here hangs the panel in early init. Usage: check-sepolicy.sh <build-dir|latest>
source "$(dirname "$0")/lib.sh"
D=${1:-latest}; [ "$D" = latest ] && D=$OUT/latest; D=$(readlink -f "$D")
SYS=$D/system.img; [ -s "$SYS" ] || SYS=$BASE/system.img
VEN=$D/vendor.img; [ -s "$VEN" ] || die "no vendor.img in $D"
M=$WORK/polcheck; sudo umount -q $M/s $M/v $M/p 2>/dev/null || true; mkdir -p $M/s $M/v $M/p
trap 'sudo umount -q $M/s $M/v $M/p 2>/dev/null || true' EXIT
sudo mount -o ro,loop "$SYS" $M/s; sudo mount -o ro,loop "$VEN" $M/v; sudo mount -o ro,loop "$BASE/product.img" $M/p
S=$M/s/system/etc/selinux; V=$M/v/etc/selinux; P=$M/p/etc/selinux
VER=$(sudo cat $V/plat_sepolicy_vers.txt)
step "secilc as init (vendor policy version $VER)"
ARGS=("$S/plat_sepolicy.cil" -m -M true -G -N -c 30 "$S/mapping/$VER.cil" -o $M/out.pol -f /dev/null)
for f in "$S/mapping/$VER.compat.cil" "$P/product_sepolicy.cil" "$P/mapping/$VER.cil" "$V/plat_pub_versioned.cil" "$V/vendor_sepolicy.cil"; do
  sudo test -f "$f" && ARGS+=("$f")
done
for f in $M/s/system_ext/etc/selinux/system_ext_sepolicy.cil $M/s/system_ext/etc/selinux/mapping/$VER.cil; do sudo test -f "$f" && ARGS+=("$f"); done
sudo "$H/secilc" "${ARGS[@]}" 2>&1 | tail -15
[ "${PIPESTATUS[0]}" = 0 ] || die "SELinux policy does not compile — this build would hang at boot"
ok "policy compiles"
