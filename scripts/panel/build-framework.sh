#!/bin/bash
# Build services.jar (and its compiled odex/vdex/art) from the pinned tree plus overlay/framework.patch.
# The tree's unpatched services.jar is byte-identical to the panel's base system, so the only change
# in the result is the patch. Records the patch sha so build.sh refuses a stale or unpatched jar.
source "$(dirname "$0")/lib.sh"
OV=$REPO/scripts/panel/overlay; P=$OV/framework.patch
[ -s "$P" ] || die "no overlay/framework.patch"
step "apply framework.patch to frameworks/base"
cd "$BT/frameworks/base" || die "no frameworks/base"
if patch -p1 -R --dry-run -s -f < "$P" >/dev/null 2>&1; then ok "already applied"
else patch -p1 --dry-run -s -f < "$P" >/dev/null || die "framework.patch does not apply to the pinned tree"
     patch -p1 -s -f < "$P" || die "patch failed"; ok "applied"; fi
step "build services (m services)"
cd "$BT" || die "no build tree"
L=$WORK/build-framework-$(date +%s).log
( set +u; source build/envsetup.sh >/dev/null && lunch $LUNCH >/dev/null && m -j16 services ) > "$L" 2>&1 \
  || { tail -30 "$L"; die "services build failed (log $L)"; }
for f in $FW_JARS; do [ -s "$TREE/system/$f" ] || die "build produced no $f"; ok "$f $(sha "$TREE/system/$f" | cut -c1-12)"; done
sha "$P" > "$TREE/.framework-patch.sha"
step "FRAMEWORK OK"
