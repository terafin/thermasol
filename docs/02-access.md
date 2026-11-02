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

Termux `sshd` on **port 8022**. The original installation used **password authentication** with a
zero-byte `authorized_keys` — the setuid `su` lives at `/system/xbin/su` and Termux cannot run it,
so a key-only setup has to be added deliberately. Set a key (`~/.ssh/authorized_keys`, mode 600)
before you rely on this path; the key is **not** in this repo and cannot be recovered from it.

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

**The UART adapter is not attached.** Do not assume it is available; find one before you plan
on this path.

## U-Boot

Interrupt autoboot to reach `u-boot=>`. From there you can `tftpboot` images into RAM,
`mmc write` them, and change the active slot.

**This is the no-shell path.** If the panel has a shell, flash with `dd` over `adb` instead —
it needs no UART and no wall — see [06-procedures.md](06-procedures.md) §C. U-Boot is the
fallback for a dark panel or a slot that will not boot.

Useful variables live in the eMMC **user area at 0x400000**, not in any A/B slot — so flashing a
slot does not touch them.

**The CMA allocation is not one of them.** CMA is sized by the device tree; the environment
variable is not what sets it, and the `cmaargs` value in a saved environment is already the
effective one.

### Two commands that destroy the device

**`mmc dev 1 1` destroys the bootloader.** `mmc dev` takes **exactly one argument**. A second
argument selects the boot0 hardware partition, and from there a write lands on the bootloader
itself. Type `mmc dev 1` and nothing else.

**`reset` after `setenv` discards the change.** This bootloader's saved environment does not
survive a `reset` intact — it comes back from defaults. To boot with transient values use
`run bootcmd`.

### Reading block numbers

`mmc part` prints partition offsets in **hex with no `0x` prefix**. `mmc read` **parses hex but
echoes decimal**:

```
u-boot=> mmc read 0x48000000 738004 2000
MMC read: dev # 1, block # 7569412, count 8192: 8192 blocks read: OK
                    ^^^^^^^ decimal echo of 0x738004
```

`738004` reads back as `block # 7569412`. **Never retype the echo** — you will write to a different
place. Copy the hex you typed.

### The misc / A-B metadata write

`misc` at byte offset `0x800` holds 32 bytes: magic `\0AB0`, a version, a slot record, and a
CRC32 of the first 28 bytes stored **big-endian at offset 28**.

Write it with per-word `mw.l` and **always** bracket the write with `md.b`:

```
u-boot=> md.b 0x... 20        # BEFORE — record this
u-boot=> mw.l 0x... <word>
...
u-boot=> md.b 0x... 20        # AFTER — must differ only where you intended
```

Getting the CRC wrong is not a brick, but it does mean the bootloader ignores the record.

### CMA

CMA size comes from the **device tree**, not the U-Boot environment. The value in a saved
environment is whatever was last set; setting `cmaargs` does not override the DT node. With no
`linux,cma` node present the fallback is **16 MiB** — not 800 M — and the framebuffer fails with
`-ENOMEM`.

To change CMA, change the DT node and rebuild `dtbo`.

## Things that will bite you

- **`adb root` crash-loops `adbd` on this build.** It sets `service.adb.root=1`, after which
  `adbd` aborts on every start: nothing on 5555, `[init.svc.adbd]: [restarting]`. Fix without
  root, from SSH or Termux: `setprop service.adb.root ""; setprop ctl.restart adbd`.
- **Separately, a Termux adb *server* racing `adbd` produces the same empty-port symptom.** The
  server holds the smartsocket listener; `adbd` aborts and init latches
  `ro.init.updatable_crashing=1`. Fix: `su 0 kill -9 <termux adb pid>`, then
  `setprop ctl.restart adbd`. Check which of the two you have before acting.
- **`su` from Termux is denied by SELinux, not missing.** `/system/xbin/su` is the real setuid
  binary; Termux's domain is `untrusted_app` and the uid boundary rejects it. Run privileged
  commands through `adb shell su 0 …` instead. Separately, `init` cannot exec `su` (policy
  denial); a startup script needs an `init → shell → su` route.
- **`-92` is `START_CLASS_NOT_FOUND`, not a `su` failure.** It means the app was launched before
  user unlock.
- **`dumpsys SurfaceFlinger`, `dumpsys window`, `logcat -d`, `ps -A --sort=-RSS` and repeated
  `screencap` kill the panel** for ~70 s each (load 19–22), twice requiring a power cycle.
  Single spaced reads only.
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
