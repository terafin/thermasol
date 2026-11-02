# 04 — The Android 15 port

## Source

| | |
|---|---|
| BSP | Variscite `imx-android-15.0.0_1.2.0` |
| Source archive | `imx-android-15.0.0_1.2.0.tar.gz` (357 MB) |
| Manifest repo | `github.com/varigit/variscite-bsp-platform`, branch `imx-android-15-var01` |
| Manifest file | `var-android-15.0.0_1.2.0.xml` (19 manifests, 55 projects) |
| Local build dir | `<android_build>` |
| Built with | AOSP 35, clang-r530567, Java 21 (not the host default) |

## What actually had to be ported

The mental model that was wrong, and cost days: **the shower/CAN layer needs zero porting.**
`mcp251xfd`, `can0_osc`, `pwm-backlight`, `wm8904`, `gpio-keys`, `ov5640`, `ads7846` are all
already in the vendor tree. `vendor/variscite/can-utils` is a first-class project.

Only four devices are ThermaSol-specific and had to be carried over:

| Device | Compatible | Where |
|---|---|---|
| Touch controller | `atmel,maxtouch` | i2c2 @ 0x4b |
| MIPI→LVDS bridge | `ti,sn65dsi83` | i2c2 @ 0x2c |
| RTC | `isil,isl12057/8` | i2c |
| Wi-Fi/BT combo | `brcm,bcm4329-fmac` | (Wi-Fi part unused — physically broken) |

The port itself is `tt10v2-port.dtsi`: an overlay merged into the Variscite DART device tree.
Display timings in it are **measured, not guessed** — see
[03-hardware.md](03-hardware.md).

## Build

```sh
cd <android_build>
source build/envsetup.sh
lunch dart_mx8mm-userdebug
m -j"$(nproc)"
```

Notes that cost time:

- `repo sync` must be run **from `android_build/`**, and linuxbrew's `git` wanted a system
  gitconfig that did not exist.
- The Java used is 21; the host default was 27 and breaks the build.
- **Verify by timestamp and hash that `boot.img` and `Image` were actually rebuilt.** Treat a
  "build completed successfully" line as a claim, not a result. *(Note: an earlier draft of
  this document asserted we had observed exactly this failure. The evidence set does not
  support that — it is recorded here as a precaution, not as something that happened.)*

## A/B and flashing

Six A/B partitions: `boot`, `dtbo`, `system`, `vendor`, `product`, `vbmeta`.

**There is no USB.** Flashing is U-Boot + TFTP:

```
mmc dev 1
tftpboot 0x50000000 <image>
mmc write 0x50000000 <LBA> <blocks>
mmc read  0x60000000 <LBA> <blocks>
cmp.b 0x50000000 0x60000000 <bytes>     # must report identical
```

**Verify every chunk with `mmc read` + `cmp`.** The one time this was skipped, an aborted
attempt had written stale RAM.

### Slot discipline

- Slot **A** is kept bootable at all times. It is the fallback.
- New images are written to the **inactive** slot, then that slot is armed.
- The A/B metadata lives in `misc` at `0x800`: 32 bytes, magic `\0AB0`, version 1, CRC32 over
  the first 28 bytes, big-endian CRC at offset 28.

Armed-trial discipline, adopted after a **stale approval was hit for real**: a boot-success
mark written for one boot was later disarmed by the guard because it belonged to an older boot.
The record is explicit — *"Do not allow a second reboot to inherit stale first-boot approval."*

1. Read the **actual current** slot and boot UUID immediately before writing.
2. Write the inactive slot.
3. Arm the trial.
4. Reboot; on health checks passing, write the current-boot approval **atomically** and
   **remove the trial arm in the same operation**.
5. A stale arm from an earlier attempt must never be able to promote an unproven image.

**The approval file's contents are a boot id**, not a slot name. That is the whole point: an
approval is bound to one boot instance.

**The misc write is an exact-old-state transition, not a read-modify-write.** The native
helper refuses to run unless the argument, the boot id and `androidboot.slot_suffix` all match
expectations, then: takes `flock(LOCK_EX|LOCK_NB)` on `/dev/block/by-name/misc`, writes an
exclusive 288-byte backup, `pwrite`s exactly 32 bytes at offset 2048, `fsync`s, issues a block
cache flush ioctl, re-reads, and asserts that **only bytes [128,160) changed and both 128-byte
neighbouring regions are byte-identical**. A `pwrite` plus a `sha256sum` is not proof; the
neighbour comparison is.

**Two slot-writer traps, both caught before any write:**

- A copied writer script still carried the **other** slot's device nodes. Caught by a string
  scan before execution, and now guarded by a unit test asserting the other slot's name never
  appears in a `dd` target.
- `avbab status` and `avbab show` **do not exist** on this panel. Reading A/B state is a
  read-only 32-byte read of `misc`.

**Do not run `avbab revert-a` casually** — it disables the other slot. Any revert must first
read the actual running slot, boot id, and a CRC-valid A/B record.

**The boot guard does not reboot on its own.** If the trial slot boots but fails its purpose,
a human (or an explicit script) has to return to the old slot.

### Never chain `boot` in vbmeta

This board's 2019 U-Boot has a bug in `get_margin_pos`: it returns
`RANGE_OUTSIDE_PARTITION`, so `avb_slot_verify` fails — and because an AVB I/O error **skips
the tries decrement**, the slot parks in USB fastboot **forever**. No number of reboots can
drain it.

So if `vbmeta` carries a **chain partition descriptor for `boot`** (which is what
`BOARD_AVB_BOOT_KEY_PATH` does by default), the slot is unrecoverable from software.

Every image builder enforces the inverse explicitly:

```python
assert not re.search('Chain Partition descriptor', info, re.I)
assert len(re.findall(r'(?:Hash|Hashtree) descriptor:', info)) == 5
assert re.search(r'\nFlags:\s+0\n', info)
```

**One thing that looks contradictory and is not:** the builders pass
`--follow_chain_partitions` to `verify_image` *and* assert there is no chain. That flag only
matters if a chain descriptor exists — which the assertion above forbids. Do not "fix" this by
removing either half.

### Image hygiene

Every image is rebuilt metadata-preserving, and the mechanism matters:

1. `fsck.erofs --extract` the baseline, capturing every inode's uid/gid/mode/capabilities and
   `security.selinux` label.
2. Serialise that into an `fs_config` and a `file_contexts` file.
3. Change **only** the intended payload.
4. `mkfs.erofs -d0 -zlz4hc,level=9 -T <original mtime> --mount-point=/vendor
   --fs-config-file=… --file-contexts=…`
5. Re-extract the **new** image and compare filesystems again — a separate gate, not a
   formality.
6. Re-run `add_hashtree_footer` using the **original salt, props, partition size and rollback
   index**, read back out of `avbtool info_image` on the baseline. Re-deriving these silently
   changes the root digest.

The inode count must equal the baseline's (999 for vendor). `METADATA-PASS.json` records
`{"inodes": 999, "uid_gid_mode_caps_selinux_preserved": true}` — that number, not a vibe.

**Trap:** `mkfs.erofs` rejects an image whose `fs_config` has no **empty-root entry**, and the
pack fails. That is a pre-flash failure, not a device result — treat it as such.

## What flashing destroys

Everything in `/data`: Termux, all boot hooks, SSH keys, the ADB-at-boot config, the panel
healer, the idle policy. The U-Boot environment survives (it is in eMMC user area, not a
slot), so the **CMA fix and the UART console survive** a slot flash.

Rebuild the access stack *before* declaring the flash done — see
[06-procedures.md](06-procedures.md).

## The restore-to-stock rule

Slot A was never written during the A15 work. The original Android 10 image and its vbmeta
are preserved off-device with recorded hashes. Rolling back is: set the active slot back to A
in U-Boot. One variable, no writes.
