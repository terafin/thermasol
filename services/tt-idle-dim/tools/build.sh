#!/bin/bash
# Build hvframe for the panel (aarch64 Android) with the Android NDK.
set -euo pipefail
NDK=${ANDROID_NDK:-$(ls -d "$HOME"/Android/Sdk/ndk/* 2>/dev/null | sort -V | tail -1)}
[ -x "$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" ] || { echo "set ANDROID_NDK to an Android NDK (r28 tested)" >&2; exit 1; }
cd "$(dirname "$0")"
"$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" --target=aarch64-linux-android29 \
  -O2 -Wall -Werror -fPIE -pie -o hvframe hvframe.c
echo "built $(pwd)/hvframe"
