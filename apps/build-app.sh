#!/bin/bash
# Build one helper app from apps/<pkg>/ (AndroidManifest.xml, res/, java/) into an APK.
# Usage: build-app.sh <app-dir> <out.apk> [--sign <keystore-or-pk8> <cert.x509.pem>]
# FRAMEWORK_JAR=<framework.jar>: for an app that uses hidden platform APIs (from the AOSP tree's build).
set -euo pipefail
APP=$(readlink -f "${1:?app dir}"); OUTAPK=$(readlink -f -m "${2:?out apk}")
SDK=${ANDROID_SDK:-$HOME/Android/Sdk}
BT=$(ls -d "$SDK"/build-tools/* | sort -V | tail -1); PLAT=$SDK/platforms/android-35/android.jar
[ -f "$PLAT" ] || { echo "need $PLAT (Android SDK platform 35)" >&2; exit 1; }
mkdir -p "$(dirname "$OUTAPK")"; W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mkdir -p "$W/res" "$W/gen" "$W/classes" "$W/dex"
if [ -d "$APP/res" ]; then "$BT/aapt2" compile --dir "$APP/res" -o "$W/res/res.zip"; fi
"$BT/aapt2" link -I "$PLAT" --manifest "$APP/AndroidManifest.xml" \
  $( [ -f "$W/res/res.zip" ] && echo "$W/res/res.zip" ) --java "$W/gen" -o "$W/base.apk"
if [ -d "$APP/java" ] && [ -n "$(find "$APP/java" -name '*.java')" ]; then
  javac --release 11 -nowarn -classpath "${FRAMEWORK_JAR:+$FRAMEWORK_JAR:}$PLAT" -d "$W/classes" $(find "$APP/java" "$W/gen" -name '*.java') 2>&1 | grep -v "^warning\|^Note:" || true
  [ -n "$(find "$W/classes" -name '*.class')" ] || { echo "javac produced no classes" >&2; exit 1; }
  "$BT/d8" --release --min-api 29 --lib "$PLAT" --output "$W/dex" $(find "$W/classes" -name '*.class')
  (cd "$W/dex" && zip -q -j "$W/base.apk" classes.dex)
fi
"$BT/zipalign" -f -p 4 "$W/base.apk" "$OUTAPK.unsigned"
if [ "${3:-}" = --sign ]; then
  "$BT/apksigner" sign --key "$4" --cert "$5" --out "$OUTAPK" "$OUTAPK.unsigned"; rm -f "$OUTAPK.unsigned"
else mv "$OUTAPK.unsigned" "$OUTAPK"; fi
echo "built $OUTAPK"
