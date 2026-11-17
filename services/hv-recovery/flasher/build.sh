#!/bin/sh
set -e
ROOT=${ANDROID_BUILD_TOP:?set ANDROID_BUILD_TOP to the imx-android-15.0.0_1.2.0 android_build tree}
CLANG="$ROOT/prebuilts/clang/host/linux-x86/clang-r536225/bin/clang"
SYS="$ROOT/out/soong/ndk/sysroot"
HERE=$(cd "$(dirname "$0")" && pwd)
"$CLANG" --target=aarch64-linux-android35 --sysroot="$SYS" -O2 -Wall -fPIE -pie -nostartfiles -Wl,-e,_start \
  -o "$HERE/hvflash" "$HERE/crt0.S" "$HERE/crt_glue.c" "$HERE/hvflash.c"
"$CLANG" -O2 -Wall -o "$HERE/hvflash-host" "$HERE/hvflash.c"
