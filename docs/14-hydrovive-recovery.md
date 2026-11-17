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
- Then `101#01` → status 2 → `101#02` → status 3 → 2 KB pages on 0x102 → `101#05` + CRC →
  `101#03`, `101#04`.

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
  It would listen ~1.5 s earlier than the shim.

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
