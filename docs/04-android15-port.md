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
| Wi-Fi/BT combo | `brcm,bcm4329-fmac` | — |

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
  "build completed successfully" line as a claim, not a result.

## Debugging a boot that never reaches userspace

The Android 15 kernel stall was found with these, and getting them wrong wastes days.

**This U-Boot ignores the `boot.img` kernel cmdline.** Everything you thought you could pass in
`BOARD_KERNEL_CMDLINE` has to go in U-Boot's `bootargs` instead:

```
u-boot=> setenv bootargs 'console=ttymxc3,115200 ... initcall_debug keep_bootcon ignore_loglevel clk_ignore_unused'
u-boot=> run bootcmd
```

Use `run bootcmd`, **not** `reset` — see [02-access.md](02-access.md).

**Without `printk.devkmsg=on`, init's module lines stop at exactly 10 per 5 s** and it looks
like a hang. It is not; it is rate limiting.

**A dead console is not evidence the CPU is dead.** `console=ttymxc3` is inserted *ahead* of
ramoops in the console list, so a stuck UART write blocks `console_flush_on_panic` — and the
lockup, panic and emergency-restart paths go with it. Consequences:

- ramoops cannot hold anything newer than the last successful console write;
- a BREAK is invisible, because RX interrupts are cleared during console writes;
- "no output" may mean "the console is wedged", not "the kernel stopped".

**`pstore` mounted does not mean it works.** With no `ramoops` node in the board device tree
there is no `/dev/pmsg0` and nothing is recorded. Check for the node, not the mount.

**Self-recovery is what makes debugging possible.** `imx2_wdt` started **at probe** with a 60 s
timeout has been observed resetting a stalled panel unattended. That is what removed breaker
trips from the debug loop. See issue [#13](https://github.com/terafin/thermasol/issues/13).

## A/B and flashing

Six A/B partitions: `boot`, `dtbo`, `system`, `vendor`, `product`, `vbmeta`.

**There is no USB.** There are two ways to write a slot, and they are not equally good:

| Route | Needs | Use when |
|---|---|---|
| **`adb` + `dd` to the inactive slot** | only a shell — no UART, no wall | **the default.** This is what [09-install-from-stock.md](09-install-from-stock.md) Stage 2 does, start to finish. |
| **U-Boot + TFTP** | the UART adapter and the wall open | you have no shell at all — a dark panel, or a slot that will not boot |

The `dd` route is the one that made this whole effort possible on a sealed panel, because it
needs nothing but Termux. Everything below describes the TFTP route, which is the fallback for
when no shell exists.

```
mmc dev 1
tftpboot 0x50000000 <image>
mmc write 0x50000000 <LBA> <blocks>
mmc read  0x60000000 <LBA> <blocks>
cmp.b 0x50000000 0x60000000 <bytes>     # must report identical
```

**Verify every chunk with `mmc read` + `cmp`.** The one time this was skipped, an aborted
attempt had written stale RAM.

### Chunk sizing: the defect that corrupts silently

`tftpboot` into a fixed RAM address, `mmc write` a fixed block count. If you advance the
destination LBA by a **constant** (`0x20000` sectors, say) rather than by the size of the chunk
you actually transferred, the cursor drifts past the partition end — and `mmc write` will happily
write whatever is next:

> `dtbo_b` ended up 60 MiB into `boot_a`; `boot_b` ended up 16 MiB into `system_a`. Both
> reported **success**.

**Compute sectors per chunk from the panel's own GPT, per partition, and assert before writing:**

```sh
# on the panel, for the target partition
cat /proc/partitions                       # block counts, decimal
adb shell 'su 0 sgdisk -p /dev/block/mmcblk0'   # or read the partition table directly
```

```sh
lba=...; sectors=...; partition_end=...
[ $(( lba + sectors - 1 )) -le $partition_end ] || die "chunk overruns partition"
```

### TFTP mechanics that cost hours

- TFTP is **UDP and fails by hanging**, not by refusing. Before blaming the panel, confirm the
  server is actually listening: `ss -lunp | grep ':69 '`.
- Run the server as a **transient systemd unit**, not a background shell process — a herdr
  restart SIGKILLs the latter mid-transfer.
- Do **not** root the server in `/tmp`; it vanishes.
- U-Boot's TFTP `blksize` is **1468** (~15 s per 64 MiB). Measuring throughput with `curl`
  defaults to 512 and gives a ~3× wrong number — do not size timeouts off it.
- Set `serverip` **after** `dhcp`. A TFTP-only dnsmasq does not answer DHCP, so `dhcp` alone
  leaves it unset.
- A `*.00` glob matches only chunk `00`. Expect 67 files / ~4.1 GB for a full set.

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

### Integrity is not content

The dark-panel post-mortem named a failure class worth its own gate: **every hash and AVB check
passed while the image was content-wrong.** A stock DART dtbo had been flashed, and 194 of 248
modules were installed nowhere. Nothing detected it, because nothing checked that the image
*describes this panel*.

Run these four gates before flashing, not after:

1. **DT describes this panel** — the `compatible` strings and the panel's own devices are
   present, not a stock EVK/DART tree.
2. **Drivers are installed**, not merely built — the `.ko` files exist in the image.
3. **They are in `modules.load`** — an installed module that is not listed never loads.
4. **DT ↔ driver join** — every node's `compatible` has a loaded driver.

Gate 4 is the one that catches the whole class. A passing hash proves the bytes are the ones you
built; only these prove the bytes are the *right* bytes.

## What flashing destroys

Everything in `/data`: Termux, all boot hooks, SSH keys, the ADB-at-boot config, the panel
healer, the idle policy. The U-Boot environment survives (it is in eMMC user area, not a
slot), so the **CMA fix and the UART console survive** a slot flash.

Rebuild the access stack *before* declaring the flash done — see
[06-procedures.md](06-procedures.md).

## Rolling back — read this before you plan on it

**The plan and the reality here are different.**

*For a fresh port* the rule is: keep one slot stock, verify it, and rollback is "set the active
slot back" — one variable, no writes. That is still the right way to do it, and
[09-install-from-stock.md](09-install-from-stock.md) is written for it.

*On this panel* it is no longer true. **Both slots now hold Android 15.** The stock Android 10
images exist only as host-side backups; neither slot has them.

### Android 10 would not have saved us anyway

When A10 was last booted on this unit during the repair, it came up with **no network at all**.
U-Boot brings up the ADIN1300 PHY, then the kernel disables it:

```
[    3.554] eth_phy_pwr: disabling
```

The A10-side device-tree overlay's `regulator-eth-phy` has neither `regulator-always-on` nor
`boot-on`, so nothing re-enables it. There is no `Link is Up` anywhere in 427 s of log.

**Consequence:** "roll back to stock" on this panel produces a dark, network-less screen — the
exact state the docs warn is unrecoverable without opening the wall. Do not treat slot
restore as a safety net here.

### What the safety net actually is — and what it is not

Be honest about this: **nobody has ever done a slot switch on this panel to prove the other slot
boots.** The wall is closed, the panel works, and a deliberate switch experiment is not something
to run on a sealed device. Treat the rollback as **untested**.

What you actually have, in decreasing order of confidence:

1. **The running slot works.** Verified every day, for free.
2. **The other slot has a matching image on it** — verified by hash, not by booting it.
3. **The watchdog.** `imx2_wdt` starts at probe with a 60 s timeout and has been observed
   resetting a stalled panel unattended.
4. **UART.** Needs the wall open and an adapter that may not be present.

So: a write to the **inactive** slot is recoverable in the sense that the running slot is
unaffected. A write to the **running** slot is not recoverable by slot switch, because the switch
itself is unproven. See [06-procedures.md](06-procedures.md) §J.

If the wall is ever open for other reasons, *then* prove the switch. Until then, do not claim it
works.
