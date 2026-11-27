#!/bin/bash
# Compile hal/PanelRoute.java (output selection + silent playback test helper) to $WORK/panel-route.jar.
# Runs on the panel via app_process; it is not installed. Needs the framework header jar from the tree.
source "$(dirname "$0")/lib.sh" || { echo "FAIL: cannot load lib.sh next to $0" >&2; exit 1; }
FW=$BT/out/soong/.intermediates/frameworks/base/framework/android_common/turbine-combined/framework.jar
[ -s "$FW" ] || die "no framework header jar — run build-framework.sh"
S=$WORK/route; rm -rf "$S"; mkdir -p "$S/c"
javac -nowarn -source 11 -target 11 -cp "$FW" -d "$S/c" "$REPO/scripts/panel/hal/PanelRoute.java" 2>&1 | grep -E "error" && die "PanelRoute does not compile"
(cd "$S/c" && jar cf ../classes.jar .)
"$H/d8" --min-api 35 --lib "$FW" --output "$S" "$S/classes.jar" 2>&1 | grep -vE "^Warning|^$" || true
(cd "$S" && rm -f "$WORK/panel-route.jar" && zip -q "$WORK/panel-route.jar" classes.dex) || die "packaging failed"
ok "panel-route.jar $(sha "$WORK/panel-route.jar" | cut -c1-16)"
