#!/bin/bash
# Build com.ghost.showercast (platform-signed). Compose-free pipeline:
#   kotlinc -> jar -> d8 (+kotlin-stdlib) -> aapt2 link -> zipalign -> apksigner(platform)
#
# Set these if the toolchain is not at the defaults:
#   JAVA_HOME     JDK 17+
#   KOTLINC       path to the kotlinc binary
#   ANDROID_SDK   an Android SDK with build-tools/35.0.0 and platforms/android-35
#   PLATFORM_P12  the device's platform signing key (PKCS#12, passphrase "android").
#                 THIS FILE MUST NEVER BE COMMITTED. Provide it locally and point
#                 PLATFORM_P12 at it. Without it the APK cannot get CAPTURE_AUDIO_OUTPUT.
set -uo pipefail
cd "$(dirname "$0")"

JAVA_HOME=${JAVA_HOME:-$HOME/toolchain/jdk17}
export PATH="$JAVA_HOME/bin:$PATH"
KOTLINC=${KOTLINC:-$HOME/kotlinc/kotlinc/bin/kotlinc}
SDK=${ANDROID_SDK:-$HOME/toolchain/android-sdk}
BT="$SDK/build-tools/35.0.0"
AJAR="$SDK/platforms/android-35/android.jar"
STDLIB="$(cd "$(dirname "$KOTLINC")/.." && pwd)/lib/kotlin-stdlib.jar"
KS="${PLATFORM_P12:-$HOME/platform.p12}"

[ -f "$KS" ] || { echo "ERROR: platform key not found at $KS"; echo "Set PLATFORM_P12=/path/to/platform.p12 (passphrase 'android'). Never commit the key."; exit 1; }
[ -x "$KOTLINC" ] || { echo "ERROR: kotlinc not found at $KOTLINC"; exit 1; }
[ -d "$BT" ] || { echo "ERROR: build-tools not found at $BT"; exit 1; }

rm -rf build && mkdir -p build/classes
echo "=== [1/6] kotlinc ==="
"$KOTLINC" -classpath "$AJAR:$STDLIB" -d build/classes $(find src -name '*.kt') 2>build/kotlinc.log
if [ -f build/classes/com/ghost/showercast/ShowerCastService.class ]; then
  echo "kotlin compile ok ($(grep -c 'warning:' build/kotlinc.log 2>/dev/null || echo 0) warnings)"
else
  echo "KOTLIN COMPILE FAILED:"; grep -E 'error:|e: ' build/kotlinc.log | head -40; exit 1
fi

echo "=== [2/6] jar app classes ==="
jar cf build/app-classes.jar -C build/classes .

echo "=== [3/6] d8 (app + kotlin-stdlib) ==="
"$BT/d8" --lib "$AJAR" --min-api 30 --output build build/app-classes.jar "$STDLIB" 2>build/d8.log
[ -f build/classes.dex ] || { echo "D8 FAILED"; cat build/d8.log; exit 1; }
echo "d8 ok"

echo "=== [4/6] aapt2 link ==="
"$BT/aapt2" link -o build/base.apk -I "$AJAR" --manifest AndroidManifest.xml 2>build/aapt2.log
[ -f build/base.apk ] || { echo "AAPT2 FAILED"; cat build/aapt2.log; exit 1; }
echo "aapt2 ok"

echo "=== [5/6] add dex + align ==="
cp build/base.apk build/app-unsigned.apk
(cd build && zip -q app-unsigned.apk classes.dex)
"$BT/zipalign" -f 4 build/app-unsigned.apk build/app-aligned.apk

echo "=== [6/6] sign (platform) ==="
"$BT/apksigner" sign --ks "$KS" --ks-pass pass:android --key-pass pass:android --out showercast-platform.apk build/app-aligned.apk
"$BT/apksigner" verify --print-certs showercast-platform.apk 2>&1 | grep -iE 'SHA-256|Verified' | head -2
ls -lh showercast-platform.apk
echo "BUILD DONE"
