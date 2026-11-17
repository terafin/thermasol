#!/bin/sh
# Cross-build tt-idle-dim for aarch64 Android (bionic) using the AOSP clang.
# Usage: build-android.sh [output-name]   (default: idle_dim)
set -e
ROOT=${AOSP_ROOT:-/home/terafin/android15-build/imx-android-15.0.0_1.2.0/android_build}
CLANG="$ROOT/prebuilts/clang/host/linux-x86/clang-r536225/bin/clang"
SYS="$ROOT/out/soong/ndk/sysroot"
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-idle_dim}
exec "$CLANG" --target=aarch64-linux-android35 --sysroot="$SYS" \
  -O2 -Wall -fPIE -pie -nostartfiles -Wl,-e,_start -Wl,--build-id=sha1 \
  -o "$HERE/$OUT" \
  "$HERE/crt0.S" "$HERE/crt_glue.c" "$HERE/idle_dim.c" "$HERE/idle_logic.c" \
  "$HERE/playback_control.c" "$HERE/hv_can.c"
