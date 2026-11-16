# Release v1.2-android15 — verified

## What changed from v1.1

Only `vendor.img` and `vbmeta.img` changed. Inside vendor, only `bin/tt_idle_dim` changed (`e1ff56f2…` → `ec905b34…`).

## `sha256sum -c SHA256SUMS`

```
5d81612048846396a2a93fc5b7a2da7157c6c7146414f773fab641d09db820dd  boot.img
c9d519893db938fa9c8133943911ba63d528cc408ab30107bc784e9f818f538c  dtbo.img
2c838f0bef27d9a6b472a03609e335f1376a3ef09836e1bc803241d048e1e81d  system.img
839432b1eb6ac636703ac00939bb694515202284b5c39f01a65174996e8bad5f  product.img
8b4ab623ab1f0e31e8ee19d8afd2d9536fd6755b869ac0a08a1980c6a7191946  vendor.img
c814a60c9a40355f6f79dcff460a3b0ff31c23b8da140b1b2d97ec133fbb2cd8  vbmeta.img
```

The four unchanged images were downloaded from v1.1, and all four passed `sha256sum -c` against v1.1's SHA256SUMS.
The digests GitHub reports for the v1.2 assets match the table above.

## AVB, against the public AOSP test key

```
vbmeta: Successfully verified SHA256_RSA4096 vbmeta struct in vbmeta.img
boot: Successfully verified sha256 hash of boot.img for image of 34469888 bytes
dtbo: Successfully verified sha256 hash of dtbo.img for image of 69099 bytes
product: Successfully verified sha256 hashtree of product.img for image of 948834304 bytes
system: Successfully verified sha256 hashtree of system.img for image of 861192192 bytes
vendor: Successfully verified sha256 hashtree of vendor.img for image of 101650432 bytes
```

## Vendor diff against v1.1

Both images were loop-mounted and compared on all 1000 inodes:

- path, type, mode, uid:gid, mtime, size and link target: one line differs (`bin/tt_idle_dim`, size 19888 → 21504)
- SELinux and other xattrs (3000 lines): identical
- per-file sha256: one line differs (`bin/tt_idle_dim`)

The hashtree salt is the same as v1.1's (`13e2bee8…`). Re-signing v1.1's vbmeta with no changes reproduced it byte for byte. Diffing `info_image` for the two vbmetas shows only the vendor image size, tree/FEC offsets and root digest changed.

## On the panel (2026-11-16)

- Slot B was written first while A was running, and the full-partition sha256 read back matched. Then: armed, booted `_b`, gates passed (eth0, adbd, ThermaSol, can0 UP), approved.
- `/vendor/bin/tt_idle_dim` read back `ec905b34…`, from vendor itself with no bind mount.
- Slot A was then written from `_b`. All four partitions (`vendor_a`, `vendor_b`, `vbmeta_a`, `vbmeta_b`) read back the hashes above.
- Behaviour, using the flashed binary with a 15 s timer and the production supervisor's live playback verdict:
  - YouTube live video playing, 45 s: stayed on YouTube, backlight 71, no DIM/HOME.
  - Same video paused, 30 s: `HOME sent` → launcher in focus → `DIM 0 (restore 71)`.
- The production daemon (300 s timer) then idled the panel on its own: `state=dim`, launcher in focus.
