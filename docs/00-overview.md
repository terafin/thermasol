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
  physical breaker trip.
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

## The five phases

1. **2026-09-13 — Bricked, then recovered.** An earlier attempt (previous agent) left the
   panel unable to boot. Recovered by quarantining Google Mobile Services.
2. **2026-09-28 — Lost access entirely.** The panel stopped answering on the network. This
   produced the long forensic brief that established *why* and what the access model is.
3. **2026-10-11 → 10-14 — Rooted, then rebuilt the access stack.** UART found, U-Boot
   reached, TFTP flashing proven, a Termux-based supervision stack built.
4. **2026-10-15 → 10-18 — Android 15 port.** Device tree port, image build, A/B flash,
   then a long tail of hardware defects (display, touch, audio, Bluetooth).
5. **2026-10-18 → 10-20 — Behaviour and polish.** Volume curve, fullscreen/navigation,
   idle policy, Google sign-in, and the unresolved ceiling-speaker hiss.

Read [01-history.md](01-history.md) for the narrative, and [02-access.md](02-access.md) if
you need to get a shell on this thing right now.
