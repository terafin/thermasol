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

## Rules this added

- Never send a bank-swap, option-byte or bootloader command to a peripheral without a verified
  way back: the image it currently runs, and a channel to its bootloader that you have tested.
- The U-Boot image lives in the eMMC user area at 0x8400, with no A/B copy. Do not write it.
- When the panel listens without ACKing, a silent bus floods with retransmits; that is a
  measurement, not a fault.

## Sources

[`services/hv-recovery/`](../services/hv-recovery/) has the CAN tools, the first-stage shim
and the payload `/init`. None of them contain ThermaSol's firmware; `mkhv5h.sh` generates the
embedded image header from the published `latest.bin`.
