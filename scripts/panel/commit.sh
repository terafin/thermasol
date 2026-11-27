#!/bin/bash
# After test.sh PASSES on a trial slot: mark it successful (keeps the other slot as fallback).
source "$(dirname "$0")/lib.sh" || { echo "FAIL: cannot load lib.sh next to $0" >&2; exit 1; }
adb_up
"$(dirname "$0")/test.sh" || die "test.sh failed — not committing. Run rollback.sh."
RA=$(sh_p "sha256sum /vendor/apex/com.android.hardware.audio.apex" | cut -d' ' -f1)
[ "$(cat "$TREE/.audio-vts.sha" 2>/dev/null)" = "$RA" ] || die "running audio APEX ${RA:0:16} has no VTS pass — run vts-audio.sh"
S=$(slot); R=$(ab_decode "$(ab_read)")
[ "$S" = _a ] || die "commit runs on the trial slot _a (running $S)"
step "commit $S (was $R)"
ab_write "$(ab_make 15 0 1 14 0 1)"
# The fallback must be the build that just passed, never whatever _b last held: flash.sh only ever
# writes _a, so without this a rollback lands on a stale build. Copy every slot partition _a -> _b
# and verify each copy byte-for-byte before trusting it.
step "fallback: copy the committed build _a -> _b"
for p in vendor vbmeta system boot dtbo product; do
  sh_p "dd if=/dev/block/by-name/${p}_a of=/dev/block/by-name/${p}_b bs=4194304 conv=notrunc,fsync && sync"
  [ "$(part_sha "${p}_a")" = "$(part_sha "${p}_b")" ] || die "${p}_b copy did not verify — _b is NOT a valid fallback; do not flash until fixed"
  ok "${p}_b == ${p}_a"
done
ok "fallback _b now holds the committed build"
