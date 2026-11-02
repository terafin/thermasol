# 00 — Overview

## The device

| | |
|---|---|
| Product | ThermaSol **ThermaTouch TT10V2** |
| Role | The in-shower control panel for a ThermaSol steam shower |
| SoC | NXP **i.MX 8M Mini** (Variscite DART-MX8M-MINI module) |
| Board | Variscite DT8MCustomBoard 2.x |
| Display | 1024×600 LVDS, 120 dpi, via TI SN65DSI83 MIPI→LVDS bridge |
| Touch | Atmel maXTouch on I²C2 @ 0x4b |
| Audio | NXP WM8904 codec on SAI5; ceiling speaker + light are separate CAN devices |
| Fieldbus | CAN via mcp251xfd, `can0` @ 100 kbit/s |
| Bluetooth | Broadcom **BCM4335C0** on UART2 (serdev) |
| Storage | eMMC, A/B slots (`boot`, `dtbo`, `system`, `vendor`, `product`, `vbmeta`) |
| Network | Ethernet (`eth0`) — the shipped board's Wi-Fi is not used on this build |
| Shipped OS | Android 10, `eng.eric.20220531.120206`, userdebug, locked bootloader, AVB green |
| Current OS | Android 15 (`imx-android-15.0.0_1.2.0`, Variscite BSP) |

## Where it lives, and why that matters

The panel is **sealed into a finished bathroom wall** with silicone. Consequences that shape
every decision in this repo:

- There is **no reset button, no USB port, and no documented recovery procedure.** The other
  ThermaSol manual (`manual_dspu-tt10-xx.pdf`) shows a reset button — but it is on the *Smart
  PDM*, which this installation does not have.
- The panel is **not PoE-powered**, so the network cannot power-cycle it. A power cycle is a
  physical power cycle.
- UART is the only true out-of-band path, and it is only reachable while the wall box is open.

So: **remote access is not a convenience here, it is the only recovery mechanism once sealed.**
That is why so much of this document is about keeping a shell alive.

## What "done" means

The goal was never "install Android 15". It was: **a shower that works, controlled by a panel
that is not stuck on a 2022 Android build**, keeping every behaviour the household relies on.

Concretely, the acceptance list that drove the work:

- Steam starts and stops from the panel and from the physical control; the generator draws
  its real ~8.7 kW and returns to 0–2 W.
- Lights, speaker, and steam are controllable; the speaker goes quiet when idle.
- Display sleeps/dims when idle and wakes on touch.
- Native YouTube, Play Store, Plex, Netflix, Apple TV, Home Assistant, Music Assistant,
  1Password.
- Remote recovery over Ethernet.
- No change to the physical installation.

**One item on that list is not met.** The speaker does *not* go quiet when idle: it hisses
continuously, and no control the panel owns changes it. That is
[07-open-issues.md §1](07-open-issues.md#1-the-ceiling-speaker-hisses-and-nothing-we-control-silences-it),
and it is unresolved. Everything else on the list was verified on the device.

## The shape of the work

Four things have to be true, in this order. Each one is a whole document.

1. **You need a shell on a stock, sealed panel.** There is no adb and no USB. The way in is
   the panel's own app store, redirected at a mirror you control — see
   [09-install-from-stock.md](09-install-from-stock.md) and
   [11-vendor-store-mirror.md](11-vendor-store-mirror.md).
2. **The access stack has to survive reboots.** Termux + Termux:Boot hooks over SSH, with adb
   started by hand. This is the only remote path once the wall is closed —
   [06-procedures.md](06-procedures.md) §I.
3. **The image has to be built and flashed without breaking the panel.** Device tree, EROFS
   rebuild, A/B slots, vbmeta — [04-android15-port.md](04-android15-port.md).

   **The flash needs no UART.** Write the inactive slot with `dd` over `adb`, arm it, reboot —
   the whole install runs over the shell from step 1. U-Boot + TFTP is the *fallback*, for a
   panel with no shell at all.
4. **The hardware has to actually work.** Display, touch, audio, Bluetooth and CAN each needed
   a real fix — [05-fixes.md](05-fixes.md).

Read [01-mechanisms.md](01-mechanisms.md) for *why* the panel behaves the way it does, and
[02-access.md](02-access.md) if you need a shell right now.
