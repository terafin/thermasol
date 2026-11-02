#!/bin/sh
# Pull the APK that is ACTUALLY installed for a package, and hash it.
#
# Learned the hard way: the build directory's APK is frequently NOT what is installed.
# Always patch from this output, never from a build artifact.
#
#   pull-installed-apk.sh com.thermasol.touchsteam2 [outdir]
set -eu
PKG=${1:?usage: $0 <package> [outdir]}
OUT=${2:-.}
ADB=${ADB:-adb}; PANEL=${PANEL:-<panel-ip>:5555}; PORT=${PORT:-5038}
"$ADB" -P "$PORT" connect "$PANEL" >/dev/null 2>&1 || true

PATHS=$("$ADB" -P "$PORT" -s "$PANEL" shell "pm path $PKG" | tr -d '\r' | sed 's/^package://')
[ -n "$PATHS" ] || { echo "package not installed: $PKG" >&2; exit 1; }
BASE=$(echo "$PATHS" | head -1)
echo "installed base.apk: $BASE"

"$ADB" -P "$PORT" -s "$PANEL" pull "$BASE" "$OUT/$PKG.apk" >/dev/null
sha256sum "$OUT/$PKG.apk"

# Also report the running process's executable, if the app is running.
PID=$("$ADB" -P "$PORT" -s "$PANEL" shell "pidof $PKG" | tr -d '\r')
if [ -n "$PID" ]; then
  echo "running pid: $PID"
  "$ADB" -P "$PORT" -s "$PANEL" shell "su 0 sh -c 'sha256sum /proc/$PID/exe'"
fi
