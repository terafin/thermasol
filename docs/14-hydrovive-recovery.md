# 14 — HydroVive amp: the bricked update and the recovery evidence

**Status: the ceiling amp (HydroVive light/sound unit) has not responded on CAN since 2026-11-16.**
This page is the evidence chain. Read it before you send anything to that unit. The cause was
an agent sending a firmware-update command; the hiss it was trying to fix is
[issue #1](https://github.com/terafin/thermasol/issues/1).

## What happened

On 2026-11-16 the panel sent the HydroVive "enter bootloader" command `A5 BC 7B 01` on CAN IDs
0x101 and 0x131, the same frame ThermaSol's library sends in `hvlsr_start_bootloader`. The unit
had been reporting firmware **v7** (`0x143: A5 B0 8F 07`). The only image ThermaSol publishes
is **v5** (`thermatouch.tsolup.com/firmware/hydrovive/latest.bin`, 47 676 B, sha256 `37c81d0b…`).
The panel went bus-off. The unit has sent no frame since, through many cold power cycles.

## The hardware

- MCU: STM32G474-class, dual-bank flash (DBANK=1, 2 × 256 KB, 2 KB pages).
- Application CAN: FDCAN2 on PB5/PB6. 24 MHz HSE → PLL → 96 MHz FDCAN clock, prescaler 60,
  1+13+2 TQ = **100 kbit/s**. ThermaSol's DSV-4000 generator firmware uses the same template.
- Other interfaces in v5: I2C2 to the ADAU1701 DSP (PA8/PA9), USART2 debug at 19200 (PA2/PA3),
  USART1 to the Bluetooth module (PC4/PC5). None of them is on the CAN harness.
- The panel, the amp and the steam generator share one supply. Cycling it reboots all three
  at the same instant.

## What `BC 01` does (v5 `0x159A–0x15F6`; DSV-4000 `0x3980` is identical)

1. Unlock flash and erase **one page: bank 2, page 0x7F** (`0x0807F800–0x0807FFFF`). Word 0
   of both banks is untouched.
2. Read OPTR and write the **inverse of BFB2** (bit 20): it is a toggle, not a set.
   `OB_Launch` → reset.
3. v5 keeps no flag, magic or CRC at the end of bank 2. The DSV-4000's `0x0803F800` is "WIFI"
   in an application settings table (`INLT/PID/SYSF/CALI/USER/FLOG/USTA/WIFI` from
   `0x0803C000`), not a bootloader flag.

After the reset, ST's ROM decides what runs (AN2606 Fig. 60, G47x V13.x). With BFB2=1: if
bank-2 word 0 is a valid SRAM address, swap and boot bank 2; otherwise boot bank 1 if its word 0
is valid; otherwise stay in the ROM bootloader. The G47x ROM bootloader talks USART1/2/3,
I2C2/3/4, SPI1/2 and DFU only, **never FDCAN**.

## ThermaSol's panel side (libthermacan 11.0.2, `process_msg`)

- RX 0x100 (HydroVive), 0x103 (DSV-4000), 0x10A (DSV-4000 slave): `d0 == 4` → resend;
  otherwise version = `d1`, status = `d2`; `d7 != 0` clears ack-pending.
- `start_bootloader` sends `A5 BC 7B 01` and sleeps 250 ms. `load_firmware` then busy-waits for
  status 1 **without transmitting**: the panel never solicits; the device must announce itself.
- Then status 1 → `101#01` → status 2 → `101#02` → status 3 → 2 KB pages on 0x102, each followed
  by `101#05` with that page's CRC → `101#03`, `101#04`. Every wait comes before its command.

## Observations since the command

| Test | Result |
|---|---|
| Listen-only cold boots at 100k, 50k, 62.5k, 25k, 16.67k; listen scans 10k–1M | no unit frame |
| Active 100k: `101#01`, `101/131 A5BC7B01`, RTR 0x100, 2.8–9.3 s and 16–157 s, 3 cold boots | no reply |
| **ACK test**: panel listen-only at 100k, 2.7–4.7 s of kernel time | ~1515 generator frames in 2 s, 0 errors |
| STM32 ROM sync `0x7F` (8E1) on the panel's spare UART1 at 19200/57600/115200 | no reply, no noise |

**The ACK test is the decisive one.** The generator normally sends ~3 frames/s; 1515 in 2 s is
its retransmit flood, because no node ACKs. With the panel silent, the unit is the only other
node, so its FDCAN is neither ACKing nor sending error flags: **no CAN controller on the unit is
active on the bus at any rate**, from about 6.8 s after power-on. A ThermaSol CAN updater
running in bank 2 would have FDCAN up and would ACK, so that is not what runs. What remains is
bank-2 code that never enables CAN (or enables it only briefly at reset), or the ROM bootloader.

## The early window

The panel's U-Boot takes ~4.1 s (`androidboot.boottime 1BLE`), so `can0` exists at ~7 s after
power-on at the earliest. Things tried or measured to listen earlier:

- **First-stage `/init` shim** ([`services/hv-recovery/initshim`](../services/hv-recovery/initshim/)):
  CAN modules moved to load position 28; listening from ~2.7 s of kernel time. Nothing heard.
- **U-Boot tftp boot**: the network path took U-Boot from 4.1 s to **13.5 s**, so it listens
  later, not earlier. The U-Boot environment was restored.
- **Local eMMC payload** ([`services/hv-recovery/payload`](../services/hv-recovery/payload/)):
  the same kernel, an initramfs with the stock first-stage modules, and `/init` that listens at
  100k in **normal** mode (the panel ACKs, so a one-shot announcement is received, not lost),
  runs the vendor update on status 1, pings the hardware watchdog, logs to ramoops and reboots.
  Tried on 2026-11-17 and abandoned: the payload kernel hangs before `/init`, leaving the panel
  dark until a power cycle. See [The local-payload attempt](#the-local-payload-attempt).

## The local-payload attempt

The unit's only recoverable state is the first seconds after power-on, so the payload was booted
directly from the eMMC by the U-Boot environment — no network, no slot write.

**Why the environment and not a slot.** The eMMC tail above the last partition is unused space
and boots with no image write: Image at LBA 30,340,000 (`3d89f010…`), initramfs at 30,410,000
(`fda08cd2…`), the live device tree at 30,420,000 (`aa854ee2…`). The GPT's last partition
(`vbmeta_b`) ends at LBA 30,330,879 and the last usable LBA is 30,535,646; the three ranges were
read back as all zeros before writing and hash-matched after. Those three ranges still hold the
payload as staged. Nothing boots them — the environment is stock — but anything that repartitions
the disk must not allocate them without zeroing them first.

**The one-shot must disarm itself, not be cleared by the payload.** `hv-recovery/payload` ends
with `reboot(RB_AUTOBOOT)` unconditionally, so an armed `bootcmd` plus a payload that hangs or
panics is an endless loop — payload, reboot, payload — with no adb and no network to break it.
The armed `bootcmd` therefore restores the stock command as its **first** action, before the
kernel is loaded:

```
setenv bootcmd ${bootcmd_safe}; saveenv; mmc dev 1; mmc read ${loadaddr} 0x1CEF3A0 0xEC2D;
mmc read ${rdaddr} 0x1D00510 0x2A7; setenv rdsize 0x54D7C; mmc read ${fdtaddr} 0x1D02C20 0x87;
setenv bootargs ${payargs}; booti ${loadaddr} ${rdaddr}:${rdsize} ${fdtaddr}; run bootcmd_orig
```

`bootcmd_safe` is `run bootcmd_orig`, so the restore needs no quoting. The eMMC is U-Boot mmc
device **1**: its device tree (inside `flash.bin`, FDT at 0x107dac) maps `mmc1` to `30b60000`,
which Linux exposes as `/dev/block/mmcblk2`, and `fastboot_dev=mmc1` already boots Android.
`rdsize` is the initramfs length in bytes, not the sector-padded read size.

**Cycle 1 — the environment with only `bootdelay=0`** (stock `bootcmd`, so nothing new can fail):
adb at 50 s, `boot_completed` at 53 s, slot `_b`. U-Boot time 4107 → 3124 ms.

**Cycle 2 — armed.** Off 08:24:57Z, on 08:25:24Z. The panel never answered adb, never answered
ping (ARP incomplete), and stayed dark for 7½ minutes until a power cycle. It then booted
Android normally in ~57 s.

What the panel's flash and logs show afterwards:

- **The disarm ran.** The environment read back `bootcmd=run bootcmd_orig`, `bootcmd_safe=run
  bootcmd_orig`, `bootdelay=0`, `bootcmd_orig` unchanged, CRC `0x6c38b977` valid.
- **`booti` was reached and did not return to the fallback.** A failed `mmc read` or `booti`
  would have fallen through to `run bootcmd_orig` and booted Android 50 s later. It did not.
- **`/sys/fs/pstore` is empty.** There is no `console-ramoops-0`, so nothing reached the point
  where ramoops or the ramoops console exists. `panic=5` would have warm-reset into Android, and
  so would the 60 s watchdog in `/init`; neither happened. The CPU hung before either could run,
  which is why only a power cycle recovered it.
- The arm64 header is sound: `text_offset=0`, `flags=0xa`, `image_size=0x1e20000` against a file
  of `0x1d85a00`. The kernel relocates itself to a 2 MiB-aligned base and lands well below the
  device tree at 0x43000000 and the initramfs at 0x44680000, so relocation did not overwrite
  either.

**Why this is the end of the attempt.** A hang before the payload can arm its own watchdog is
unrecoverable from software, and the only way back is somebody physically power-cycling the
appliance. Bare metal does not remove that: a bare-metal payload that hangs before enabling the
watchdog has the same hole, and the prize — a few seconds of listening on a bus that has carried
no unit frame in any cold boot since the failure — does not justify the risk to a sealed panel.
The original
environment is restored (md5 `1b1533ff…`) and the panel runs the published v1.2.

**What a future attempt would need**, all of it before any armed boot: a warm-reset path that
exists before userspace (U-Boot `wdt start`, if this build has it), a payload that proves its
own boot on a bench machine rather than the panel, and a console — the device has none exposed.

## Reading the unit's flash is not possible over CAN

The question "can we pull v7 off the chip before overwriting it" has a definite answer: no.
Every frame `libthermacan` 11.0.2 can emit into the bootloader state was enumerated from the
binary, and all of them are command- or write-direction:

| frame | function |
|---|---|
| `0x101 A5 BC 7B 01` (also `0x131`) | `hvlsr_start_bootloader` |
| `0x101` d0=`01`, then `02` | `hvlsr_bootloader_load_firmware` |
| `0x102` `[page, cnt_hi, cnt_lo, 0x69, 4 bytes]` | `send_flash_page` |
| `0x101` d0=`05`, d1=page, d2..5 = CRC32 of that page | `send_flash_page`, after every page |
| `0x101` d0=`03`, then `04` | `hvlsr_complete_update_and_restart` |

The only device-to-panel data in the library is the status frame on 0x100 (version, status,
ack pending). There is no page read, no memory read and no range CRC: the `05` CRC is the unit
checking what it received. Guessing an undocumented opcode on a bootloader we cannot test risks
erasing the chip it was meant to preserve. A copy of v7 has to come from somewhere else — the
app's download cache, or a vendor artefact — not from the device.

## The bare-metal attempt and the stuck panel

The kernel route ended with two measured results: `booti` on a raw Image is entered and hangs
(`stage = prebooti`, three times, with no panic and no pstore), and `bootm` on a legacy gzip
uImage is **rejected** (`stage = bootm-ret`). Even a working kernel only reaches CAN at about
6 s, so a bare-metal payload was the next step: an 812-byte arm64 image with a valid header that
`booti` loads at `0x40080000`, programs the pinmux, drives the MCP2518FD over ECSPI1, and never
touches Linux.

It hung on its first run and the panel has not come back since. What is known:

- The armed environment was verified on flash before the cycle (md5 `a2447cd8…`) and it **does**
  define `bootcmd_safe=run bootcmd_orig`, so the disarm had its variable.
- No packets from the panel on the wire for 60 s, so `bootcmd` did not fall through to a default
  environment running a network command. It says no more than that: U-Boot powers the PHY and
  brings the link up itself before `bootcmd` runs (below), so silence on the wire is not evidence
  that the boot stopped before network.
- Three power cycles (12 s, 15 s, 30 s off) did not restore Android.

Two faults are mine and both are in the chain, not the payload:

1. `saveenv` is a command like any other, and a flat `;` chain continues when it fails. If it
   fails, `bootcmd` in flash stays armed and every boot re-enters the payload. The self-disarm
   guards a hang; it does not guarantee that the disarm was stored.
2. `booti` is called unconditionally. If the `mmc read` fails, `booti` jumps into whatever is at
   `0x40080000` and hangs instead of falling through to `run bootcmd_orig`.

The payload that was staged also wrote SNVS `LPGPR` (`0x30370068`) as its first instruction — the
same class of always-on register that aborted U-Boot's `mw` — which is the leading suspect for
the hang itself. The replacement payload removes that write, bounds every wait, and ends in a
PSCI reset instead of returning.

### U-Boot powers the PHY before `bootcmd`

The bootloader on the panel is U-Boot **2019.04-41468-ge20d4ecd9f** (May 31 2022), read from the
`flash.bin` at `0x8400`. Every line number below is for that vendor tree (`varigit/uboot-imx` at
`e20d4ecd9f`, 41,468 commits past the `v2019.04` tag); on the upstream tag the same three places
are `common/board_r.c:554`, `:800` and `:827`.

In that build `initr_net` sits in `init_sequence_r` (`common/board_r.c:846`), ahead of
`run_main_loop` (`:885`), and `initr_net` calls `eth_initialize()` (`:557-560`). Both the
function and its sequence entry are inside `#ifdef CONFIG_CMD_NET` (`:556` and `:845`), so
everything below rests on that symbol being set — it is, in
`configs/imx8mm_var_dart_android_defconfig:129`. `eth_initialize()` probes the Ethernet device
(`net/eth-uclass.c:396,409` → `uclass_first_device_check` → `device_probe`,
`drivers/core/uclass.c:600-612`), and the FEC probe enables the PHY's supply, releases its reset
and soft-resets it (`drivers/net/fec_mxc.c:1396`, `:1405`, `phy_connect` → `phy_reset` at
`:1305`). The board's device tree supplies both properties: `&fec1` has
`phy-supply = <&reg_eth_phy>` and `phy-reset-gpios = <&gpio1 9 GPIO_ACTIVE_LOW>`
(`arch/arm/dts/fsl-imx8mm-var-dart.dts:402-403`), with `reg_eth_phy` on `gpio1_io07` there at
`:50-56`; `CONFIG_DM_ETH`, `CONFIG_DM_GPIO`, `CONFIG_DM_REGULATOR` and
`CONFIG_DM_REGULATOR_FIXED` are all set in the same defconfig.

So a link blip is expected on every boot that reaches `board_init_r`, with no network command
anywhere in the chain (`bootcmd_orig` is `run cmaargs; boota ${fastboot_dev}`), and a payload that
hangs leaves the link up because it only reprograms ECSPI pins. Two consequences:

- **Link up is evidence that U-Boot started, not that Linux did.** It places the boot at or past
  `initr_net`.
- **A boot that never links did not reach `initr_net`** — or the probe failed, which prints
  `Could not get PHY for …` or `No ethernet found` and continues into `bootcmd` anyway. Only the
  console separates those two.

### What the v10 cycle left on flash

The v10 chain ran `setenv bootargs ${payargs}; …; saveenv`, and v10's `payargs` was the only one
in the series that did **not** carry the Android command line:

```
console=ttymxc3,115200 earlycon=ec_imx6q,0x30a60000,115200 clk_ignore_unused keep_bootcon panic=1
```

Every earlier version (v6–v9) saved a superset of the Android set — `init=/init`,
`androidboot.hardware`, `root=/dev/mmcblk2p6`, the verified-boot fields and, in v8/v9, `ramoops`
— and every one of those cycles came back. The readbacks are on disk and match those strings
field for field: `env-after-v6.bin` through `env-after-v9.bin`.

**That stripped `bootargs` is why the panel does not come back.** It is the one variable v10 does
not share with any cycle that recovered, and the boot path does not restore what it dropped:
`android_image_get_kernel` (`common/image-android.c:80-90`) copies the env `bootargs` into the
kernel command line, and the boot image's own `hdr->cmdline` is appended **only in the `else`
branch, when `bootargs` is unset**. Everything added afterwards is `androidboot.serialno`,
`btmacaddr`, `soc_type`, `boot_device_root`, `boottime`, `bootreason`, then `bootargs_sec`,
`bootargs_3rd`, `dtbo_idx` and `keystore`. That tail supplies `androidboot.force_normal_boot=1`
(`drivers/fastboot/fb_fsl/fb_fsl_boot.c:256`, inside `#ifndef CONFIG_ANDROID_AUTO_SUPPORT`, and
that symbol is set in neither the defconfig nor the board header) — so the missing token is not
that one. The v6–v9 readbacks show the appended tail growing on top of a base that already held
the Android set, which is why those cycles booted and this one did not.

**The token that stops this boot is `androidboot.hardware=freescale`, through the first-stage
fstab.** It was established at source and against the deployed image:

- `init` switches to `/first_stage_ramdisk` and then calls `CreateFirstStageMount`, which needs
  `GetFstabPath()` to return a path.
- `GetFstabPath` (`system/core/fs_mgr/libfstab/fstab.cpp`) tries three properties in order —
  `fstab_suffix`, `hardware`, `hardware.platform` — looking for `fstab.<suffix>` across
  `/odm/etc`, `/vendor/etc`, `/system/etc`, `/first_stage_ramdisk/system/etc`, `/`, and
  `/first_stage_ramdisk`.
- `fstab_suffix` is **not** lost with the command line. `fs_mgr_get_boot_config`
  (`libfstab/boot_config.cpp:173-191`) reads the device tree *first*, from
  `/proc/device-tree/firmware/android/<key>`, and the panel's live DTB carries
  `fstab_suffix = "nxp"`. So the first property is always tried, whatever the cmdline says.
  That DTB was read off the running unit — `/firmware/android/{compatible,fstab_suffix,
  boot_devices,...}` dumped over adb on 2026-11-17 and kept at a recorded digest
  `8427df15a7…`, 73,856 B, FDT v17 — with `compatible = "android,firmware"` present, which is
  what `is_dt_compatible()` tests. Unlike a source citation, an observation off the unit cannot be
  repeated while the unit is dark, so it is recorded with its digest rather than asserted bare.
- The ramdisk in the deployed boot image has no `fstab.nxp`. Extracted from `boot_b.img`
  (sha256 `5d81612048…`, ramdisk 19,435,281 B, LZ4 legacy, 584 entries), `cpio -t | grep fstab`
  lists only `first_stage_ramdisk/fstab.freescale` and `system/etc/recovery.fstab`. `fstab.nxp`
  exists only in the vendor image at `/vendor/etc/fstab.nxp`, which first stage cannot read.
- With `fstab_suffix=nxp` missing from the ramdisk, the second property is what resolves:
  `hardware=freescale` finds `first_stage_ramdisk/fstab.freescale`. v10's `payargs` dropped
  `androidboot.hardware`, so neither property resolves, `GetFstabPath()` returns `""`, and
  first-stage mount is fatal.

That is also why the panel booted for months with these same images: every earlier cmdline carried
`androidboot.hardware=freescale`, so the lookup succeeded on its second property and nothing
depended on `fstab.nxp` being present.

Two other routes reach the same mount, both needing a `dtbo` write and a `vbmeta` re-sign, because
`dtbo` is a chain part of `vbmeta` (the panel's DTB lists `boot_devices` and `vbmeta` parts
`vbmeta,dtbo,boot,system,vendor,product`). A `dtbo` supplying
`/firmware/android/hardware = "freescale"` satisfies `GetFstabPath()` directly, since
`fs_mgr_get_boot_config` reads the device tree before `ro.boot` or the cmdline. A `dtbo` restoring
the `/firmware/android/fstab` sub-tree works for a different reason:
`ReadDefaultFstab()` merges `ReadFstabFromDt()` ahead of the file lookup and returns true if either
populated entries, gated only by `IsDtFstabCompatible()` requiring
`/firmware/android/fstab/compatible = "android,fstab"`. Restoring `bootargs` is the cheapest of the
three and needs no image write.

A different tree applies if the panel is ever put back on stock firmware. Stock Android 10 has
no `libfstab/` directory; its function is `system/core/fs_mgr/fs_mgr_fstab.cpp:446-462` on
`android10-release`, and it tries only `hardware` then `hardware.platform` across `/odm/etc`,
`/vendor/etc` and `/` — no `fstab_suffix`, no `/first_stage_ramdisk`. The token that matters there
is still `androidboot.hardware`: it is the only property asked before falling to
`hardware.platform`. `fs_mgr_get_boot_config` is device-tree-first on both versions.

Both slot images were extracted and agree. The published v1.2 boot image that slot B runs
(sha256 `5d81612048…`, ramdisk 19,435,281 B, 584 entries) and the boot_a image deployed beside it
(sha256 `90653e87…`, ramdisk 19,500,738 B, 585 entries) each list only
`first_stage_ramdisk/fstab.freescale` and `system/etc/recovery.fstab`. Neither carries
`fstab.nxp`, so the chain holds whichever slot boots.

The link evidence agrees rather than conflicts: on the switch, port 12's `link_down_count` and
`stp_state_change_count` both advanced across the post-v10 power cycles, and a port cannot go
down without first having come up. The PHY did link at each power-on — U-Boot reached
`initr_net` — and the failure is downstream of it, in Linux, with the command line above.

**A first-stage failure hangs; it does not loop.** Android's own restart path cannot recover the
unit, because the pad that carries the reset is owned by the touch controller at steady state.
Four separate trees are needed to show it, and each cite below names its own:

- **U-Boot, `varigit/uboot-imx@e20d4ecd9f`.** U-Boot and its SPL mux `GPIO1_IO02` to
  `WDOG1_WDOG_B`: `board/variscite/imx8mm_var_dart/imx8mm_var_dart.c:39-40,97-101` and
  `spl.c:329-330,338-342`.
- **The panel's own DT** — the live dump recorded at `8427df15a7…` (see the tree-observation note
  above). Both pin groups write the same pad, `0x030`/`0x298`: `wdoggrp` in mode `1`
  (`WDOG1_WDOG_B`) and `captouchgrp` in mode `0` (GPIO). The touch node (`atmel,maxtouch`,
  `touch@4b`, `status = "okay"`) names `captouchgrp` as its `pinctrl-0` and takes the pad as its
  IRQ (`irq-gpio = <&gpio1 2 1>`, `interrupt-parent` = `gpio1`).
- **The A15 kernel tree on tellah**, `vendor/variscite/kernel_imx`, whose version string is
  `6.6.58-4k-ga9e7dfe9bde2` — the same string the panel's boot image prints.
  `arch/arm64/boot/dts/freescale/imx8mm-pinfunc.h:24-25` is the mode table those two values come
  from (`GPIO1_IO2` = `0x0`, `WDOG1_WDOG_B` = `0x1`); `CONFIG_TOUCHSCREEN_ATMEL_MXT=y` in its
  built config, so the touch driver is present before first-stage init runs. The source DTS names
  the group (`imx8mm-var-som.dtsi:345`, `&wdog1` → `pinctrl_wdog`), but the **compiled** DT the
  panel runs does not: its `watchdog@30280000` is `status = "okay"` with no `pinctrl-0`, and
  nothing references `wdoggrp`. So nothing in the kernel ever puts the pad back on `WDOG_B`.
- **The ATF tree beside it**, `vendor/nxp-opensource/arm-trusted-firmware`. A kernel restart goes
  to PSCI, not to a kernel watchdog: `psci_sys_reset_nb` registers at priority 129
  (`drivers/firmware/psci/psci.c:338-340`, kernel tree) against `imx2_wdt` at 128
  (`drivers/watchdog/imx2_wdt.c:345`, kernel tree). ATF's `imx_system_reset` is external `WDOG_B`
  only — `IMX_WDOG_B_RESET` is defined for i.MX8MM at
  `plat/imx/imx8m/imx8mm/include/platform_def.h:189`, so it calls `imx_wdog_restart(true)`, which
  arms WDOG1 with a 0.5 s timeout and ends in `while (1)`
  (`plat/imx/imx8m/imx8m_psci_common.c:195-233`: `WCR = (old & 0x000E) | WDE | SRS`, so `WDE`
  is set and `WT` stays 0).
- **Why that armed timeout does nothing.** U-Boot's `set_wdog_reset` sets `WDT` alongside
  `WDZST` — `arch/arm/mach-imx/imx8m/soc.c:78-88` in `varigit/uboot-imx@e20d4ecd9f`, the tree the
  panel boots, whose comment says `WDZST` is write-once and names the external `WDOG_B` route. ATF's
  `& 0x000E` mask preserves both bits, so the timeout drives `WDOG_B` only and never the internal
  reset — and `WDOG_B`'s pad is on GPIO, so the timer expires into a pin that goes nowhere.

With the pad on GPIO, that timeout reaches nothing and ATF waits forever. `tt_reboot_pin.ko`
restores the mux on a normal restart, but it is a vendor module and never loads when first-stage
init dies. So any first-stage failure parks the unit until power is cycled — which is what the
frozen port counters show. An external pull on that same net may still reset the board — and that
is recorded as an inference, not a fact:

> **Inference, not established.** `03-hardware.md:58-59` records that a weak input pull-down on
> `GPIO1_IO02` resets the board, and `13-instruments-lie.md:59` that pulling the presumed `CHG`
> pin low does the same. If those two pins are one net — the maXTouch `CHG` line sharing the
> PMIC's `WDOG_B` — then a low on it resets the unit whatever the SoC mux is set to, and a touch
> on the frozen panel would do it. No schematic has been read to confirm the shared net, and the
> two notes were written from separate probes that could each have reset the board for their own
> reason. If it holds, it is not a recovery: the unit replays the same failing boot.

**Check the link before booking a console session.** It is the observation that separates a unit
that booted Linux badly from one that never got there, and it costs a glance at the switch port:
link up at power-on means the boot reached `initr_net`, so the saved command line is the thing to
fix; link down means the fault is at or before `initr_net` — where the two chain faults live — and
this cause is ruled out without a UART trip.

One trap for whoever checks the code next: this reading is the **vendor** tree. Upstream
`v2019.04` (`common/image-android.c:85-90`) appends `hdr->cmdline` unconditionally, which would
make a stripped `bootargs` harmless; the vendor tree at `e20d4ecd9f` moves that append into the
`else` branch. The panel runs the vendor build, and the difference decides whether this cause
exists at all.

At a console, restore the Android command line and reboot:

```
setenv bootargs 'init=/init consoleblank=0 androidboot.hardware=freescale androidboot.force_normal_boot=1 firmware_class.path=/vendor/firmware transparent_hugepage=never androidboot.primary_display=imx-drm'; saveenv; reset
```

Try it before `env default -a`: it leaves the rest of the environment intact.

**A prompt that does not appear is an answer, not a dead end.** No prompt means no U-Boot to type
at, so the saved `bootargs` is ruled out and the fault is at or before `initr_net` — the SPL/ATF
or early `board_init_r` window. That is a different investigation, and the UART output itself is
its first evidence: what SPL and ATF print, or their silence.

## Recovering a panel that boots to nothing

Needs hands on the unit. There is no remote path: adb is down, the network never comes up, and
power cycles do not change the outcome.

**This section is a plan, not a transcript.** Nothing below has been executed — it cannot be,
without the unit in front of you. Two steps in particular are unverified and are the ones a
recovery depends on: that a failed `bootcmd` really does leave U-Boot at a prompt you can type
into, and that `tftpboot` works from that prompt with the network not yet brought up. Treat the
commands as the intended sequence and verify each result as you go.

**Console.** The SoC's UART4 is `ttymxc3`, `0x30a60000`, **115200 8N1**, three-wire (TX, RX,
GND) on the SoM header. `bootdelay=0` leaves no countdown to interrupt. Whether a prompt is
waiting follows from the link: U-Boot powers the PHY itself before `bootcmd` runs, so a unit that
links and then goes quiet is one whose `bootcmd` failed, and its prompt should be there; a unit
that never links may not be reaching `board_init_r` at all, and nothing appears. Send a carriage
return first to confirm.

**Restore the environment.** From the prompt, either:

```
env default -a; saveenv; reset
```

or write the saved original back over the environment area (LBA `0x2000`, 8 sectors of 512):

```
tftpboot 0x41000000 env-orig-0x400000.bin     # the 4 KB blob, md5 1b1533ff43325d1a0c437826dd9aad88
mmc dev 1
mmc write 0x41000000 0x2000 8
reset
```

Either way the panel then boots Android from slot `_b`, which is unmodified.

**If there is no prompt**, the SoC did not reach U-Boot. What the console shows next is the
evidence: SPL and ATF print before `board_init_r`, so their output narrows the fault to the stage
that failed, and complete silence narrows it to power or the BootROM. The BootROM serial-download
path (`SERIAL_DOWNLOAD`, USB OTG with `imx_usb_loader` / `uuu` and the vendor `flash.bin`) is not
open to this panel — there is no reachable USB ([04-android15-port.md](04-android15-port.md#ab-and-flashing)).
UART output is the channel that remains.

**Do not** write `flash.bin` (the bootloader at `0x8400`), and do not touch slot A: neither is
involved in this failure.

## Rules this added

- Never send a bank-swap, option-byte or bootloader command to a peripheral without a verified
  way back: the image it currently runs, and a channel to its bootloader that you have tested.
- The U-Boot image lives in the eMMC user area at 0x8400, with no A/B copy. Do not write it.
- When the panel listens without ACKing, a silent bus floods with retransmits; that is a
  measurement, not a fault.
- **A payload whose only failure mode is a hang cannot be made safe by a disarming `bootcmd`.** The
  disarm protects the panel only if it is stored; a `saveenv` that fails inside the chain is
  invisible. Before any payload that can hang: verify the disarm by reading the env back, and give
  the payload a bounded exit (PSCI reset) and no access to registers that can stall the bus.
- **Never `booti` unconditionally.** Check the loaded image (magic, size) in the chain first, so a
  failed read falls through to the stock boot instead of jumping into stale RAM.
- **U-Boot brings the link up before `bootcmd`.** `initr_net` probes the FEC and powers the PHY, so
  a link is evidence that U-Boot ran, never that Linux did. Judge how far a boot got by the
  console, not by the switch.
- **Never `saveenv` a `bootargs` you have replaced.** A saved `bootargs` outlives the cycle that
  set it: the next boot uses it for real, and an incomplete one is read by the bootloader as the
  kernel command line to build on. Change `bootargs` in RAM for a test and let the reset discard
  it; save only a value you would accept on the next unattended power-on.

## Sources

[`services/hv-recovery/`](../services/hv-recovery/) has the CAN tools, the first-stage shim
and the payload `/init`. None of them contain ThermaSol's firmware; `mkhv5h.sh` generates the
embedded image header from the published `latest.bin`.
