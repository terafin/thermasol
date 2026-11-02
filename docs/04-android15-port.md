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
- A "successful" build can silently build the wrong things. Verify by **timestamp and hash**
  that `boot.img`, `dtbo.img` and `Image` were actually rebuilt — a run that reports
  success while `boot.img` is hours old is not a build.

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

Armed-trial discipline that was adopted after a stale-approval bug:

1. Read the **actual current** slot and boot UUID immediately before writing.
2. Write the inactive slot.
3. Arm the trial.
4. Reboot; on health checks passing, write the current-boot approval **atomically** and
   **remove the trial arm in the same operation**.
5. A stale arm from an earlier attempt must never be able to promote an unproven image.

### Never chain `boot` in vbmeta

This board's 2019 U-Boot has a signing bug (`get_margin_pos`). If `vbmeta` carries a **chain
partition descriptor for `boot`**, slot B parks in fastboot forever and no cycle can drain
it. vbmeta must be `flags=0`, five hash/hashtree descriptors, no chains.

### Image hygiene

Every image is rebuilt metadata-preserving: extract the vendor EROFS, change exactly the
intended payload, compare **all 999 inodes** for uid/gid/mode/capabilities/SELinux label,
rebuild with the original salt, re-sign `vbmeta`, and verify with `avbtool verify_image`
before writing.

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
