#!/bin/bash
# Compile discovery.h for the host and run it against the live Sonos system; compare the room
# set (ip + full name) with sonos-rooms.sh. Exit 0 only if they match exactly and ports start at 4097.
set -euo pipefail
H=$(cd "$(dirname "$0")" && pwd); T=$(mktemp -d)
g++ -std=c++17 -O1 -pthread -o "$T/dt" "$H/discovery-hosttest.cpp"
"$T/dt" 2>/dev/null | sort > "$T/got"
"$H/../sonos-rooms.sh" | sort > "$T/want"
cut -f1,2 "$T/got" | sort > "$T/got2"
echo "discovered:"; sed 's/^/  /' "$T/got"
if diff "$T/want" "$T/got2"; then echo "HOSTTEST rooms match ($(wc -l < "$T/want"))"; else echo "HOSTTEST FAIL: rooms differ"; exit 1; fi
min=$(cut -f3 "$T/got" | sort -n | head -1); [ "$min" = 4097 ] || { echo "HOSTTEST FAIL: first port $min"; exit 1; }
dup=$(cut -f3 "$T/got" | sort | uniq -d); [ -z "$dup" ] || { echo "HOSTTEST FAIL: duplicate ports $dup"; exit 1; }
echo "HOSTTEST PASS"; rm -rf "$T"
