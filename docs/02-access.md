# 02 — Access: getting a shell on the panel

If the panel is on the network and healthy, you have three ways in. If it is not, read
[06-procedures.md](06-procedures.md).

## Finding the panel

This document uses `<panel-ip>` throughout. The panel takes a DHCP lease; find it with your
router's lease table, or `arp -a` / `ping <hostname>.local` from the LAN. The examples below
set it once:

```sh
export PANEL=<panel-ip>:5555
```

## Prerequisites on the workstation

```sh
ADB=adb
$ADB -P 5038 connect <panel-ip>:5555
$ADB -P 5038 -s <panel-ip>:5555 shell
```

`5038` is the **host** adb server port, not the panel's. The panel listens on 5555.

If IPv4 is unavailable (DHCP failure, half-booted framework), the panel still answers on
IPv6 link-local — this has saved a session more than once:

```sh
$ADB -P 5038 connect '[fe80::def:7b18:fe:3b4b%ens160]:5555'
```

## Runner

Every root command takes this shape:

```sh
$ADB -P 5038 -s <panel-ip>:5555 shell 'su 0 sh -c "<command>"'
```

The single quotes matter: without them the host shell eats `$` and backticks before the
panel ever sees them.

## SSH

Termux `sshd` on **port 8022**, key-based, no password. The private key lives on the
workstation — it is **not** in this repo and cannot be recovered from it. If you are taking
over this panel, you need that key before you need anything else here.

```sh
ssh -p 8022 <panel-ip>
```

This is the *independent* channel. Keep it working: if `adbd` wedges, SSH is how you fix it
without walking to the panel.

## UART

The only true out-of-band path, and the only one that survives a bad flash.

| | |
|---|---|
| Device | `/dev/cu.usbserial-A10OOP3V` (USB-serial adapter on the workstation) |
| Settings | 115200 8N1, **DTR/RTS de-asserted** |
| Prompt | `imx8mm-var-dart:/ $`, then `su 0` for root |
| U-Boot | interrupt autoboot → `u-boot=>` |

**As of 2026-10 the adapter is not attached.** Do not assume it is available.

## U-Boot

Interrupt autoboot to reach `u-boot=>`. From there you can `tftpboot` images into RAM and
`mmc write` them, and you can change the active slot. This is the flash and the rollback
mechanism, because there is no USB.

Useful variables live in the eMMC **user area at 0x400000**, not in any A/B slot — so
flashing a slot does not touch them. That is where the CMA fix lives.

## Things that will bite you

- **`adb root` while a Termux adb *server* is running kills `adbd` for the whole boot.**
  The server holds the smartsocket listener; `adbd` aborts, and init latches
  `ro.init.updatable_crashing=1` and stops retrying. Symptom: nothing listening on 5555 at
  all, port scans empty. Fix: `su 0 kill -9 <termux adb pid>` then
  `setprop ctl.restart adbd`.
- **`grep` and `find` are shell functions in this environment and fail quietly.** Run the
  binaries directly (`command grep`, `command find`) or do the work in Python. A silent
  zero-result `grep` has produced false conclusions more than once.
- **Do not use `Utils.ShutdownAll` as an idle action.** It stops the steam generator and
  flushes water.
- **Do not start `PowerFlushActivity` or `FirmwareUpdateActivity` exploratorily** — they act
  on real hardware in `onCreate`.

## The recovery contract

Three independent paths must stay alive, and they are not equally reliable:

1. **ADB 5555** — fast, root, but wedges if a Termux adb server races it.
2. **SSH 8022** — independent of adbd, depends on Termux + `BOOT_COMPLETED`.
3. **UART** — always works, needs a screwdriver and an adapter that may not be there.

When changing anything that could affect boot, verify you still have *two* of these before
and after.
