#!/bin/sh
# Build the standalone recovery payload: hvnet (/init) and initrd.lz4.
#   ANDROID_BUILD_TOP  imx-android-15.0.0_1.2.0 android_build tree (clang + musl sysroot)
#   MODDIR             directory holding the boot image's first-stage modules (*.ko)
#   MODLOAD            that boot image's modules.load (CAN modules reordered after spi-imx)
#   HVBIN              ThermaSol's published latest.bin (not in this repo)
# Output: out/hvnet, out/initrd.lz4, out/SHA256SUMS. Record SHA256SUMS in the repo before flashing.
set -e
R=${ANDROID_BUILD_TOP:?}; : "${MODDIR:?}" "${MODLOAD:?}" "${HVBIN:?}"
HERE=$(cd "$(dirname "$0")" && pwd); O=$HERE/out; rm -rf "$O"; mkdir -p "$O/rd/m" "$O/rd/dev" "$O/rd/proc" "$O/rd/sys"
"$HERE/../mkhv5h.sh" "$HVBIN" "$O/hv5.h"
"$R/prebuilts/clang/host/linux-x86/clang-r536225/bin/clang" --target=aarch64-unknown-linux-musl \
  --sysroot="$R/prebuilts/build-tools/sysroots/aarch64-unknown-linux-musl" -static -O2 -fno-pie \
  -rtlib=compiler-rt --unwindlib=none -fuse-ld=lld -s -I"$O" -o "$O/hvnet" "$HERE/hvnet.c"
cp "$O/hvnet" "$O/rd/init"; chmod 0755 "$O/rd/init"
# first-stage modules up to and including mcp251xfd.ko, in load order
awk '{print} /^mcp251xfd\.ko$/{exit}' "$MODLOAD" > "$O/rd/m/modules.load"
while read -r m; do cp "$MODDIR/$m" "$O/rd/m/"; done < "$O/rd/m/modules.load"
find "$O/rd" -exec touch -h -d @0 {} +
(cd "$O/rd" && find . | LC_ALL=C sort | cpio -o -H newc --owner=0:0 --reproducible 2>/dev/null) | lz4 -l -12 -f - "$O/initrd.lz4" >/dev/null
(cd "$O" && sha256sum hvnet initrd.lz4 > SHA256SUMS && cat SHA256SUMS)
