# 01 — Mechanisms

Why this panel behaves the way it does. Not a chronology — the durable facts, each with the
evidence behind it, so you can predict what it will do instead of rediscovering it.

Where something is a reconstruction rather than a measurement, it says so.

---

## Nothing starts `adbd`, and nothing can

This is the fact the whole access model hangs on.

`adbd` is `disabled` in `/system/init.usb.rc`, and every `start adbd` in the deployed system is
gated on a `sys.usb.configfs` value this hardware never holds — the vendor sets it to `2` in
`on boot`. A full scan of `system.img`, `vendor.img`, `product.img`, `boot.img` and all seven
APEX payloads found no other `start adbd`.

**Consequence:** the only thing that ever brought up `adbd` (and `sshd`) was a **Termux:Boot
hook** — `00-restore-access` — which requires `BOOT_COMPLETED`. There is no vendor mechanism to
lean on.

**Recovery mode does give you `adbd`.** Its `init.rc` has no configfs gate. But it brings up
**loopback only** — no `netd`, no DHCP — and binds `adbd` to USB functionfs. With USB excluded,
that route is unreachable however you enter it.

So the reachable transports are exactly:

| Path | Notes |
|---|---|
| ADB over TCP 5555 | works, root — but depends on `adbd` being started by hand |
| SSH 8022 (Termux `sshd`) | works, independent of `adbd` |
| U-Boot console | interrupt autoboot; the flashing and rollback mechanism |
| UART console | 115200 8N1, host `/dev/cu.usbserial-A10OOP3V` — **the adapter is not attached** |
| USB / fastboot / SDP | **unavailable** — no USB on this panel |

## Everything remote lives in `/data`, and a system flash destroys it

The access stack is Termux plus boot hooks under `~/.termux/boot/`. All of it is in `/data`.
**A system image flash wipes `/data`**, taking Termux, `sshd` and every hook with it — leaving a
sealed panel with no remote path.

Whatever you flash, rebuild the access stack in the same session. See
[06-procedures.md](06-procedures.md) §I.

## The panel is not PoE-powered

The switch port has `poe_enable=False`. A remote power cycle is impossible. The only power
action is the mains breaker — a human.

## A Termux adb *server* is mutually exclusive with `adbd`

The server holds the smartsocket listener, so every `adbd` start aborts with
`Could not install *smartsocket* listener: Address already in use`. init then latches
`ro.init.updatable_crashing=1` and stops restarting `adbd` for the entire boot.

That presents as permanent loss of ADB. **Never start an adb server in Termux.**

Separately, `adb root` sets `service.adb.root=1`, after which `adbd` aborts on every start and
crash-loops. Recover with `setprop service.adb.root ""; setprop ctl.restart adbd`.

## The shower/CAN layer needed no porting

`mcp251xfd`, `can0_osc`, `pwm-backlight`, `wm8904` and `gpio-keys` are all already in the
vendor tree. Only four ThermaSol-specific devices had to be carried over:

| Device | Compatible | Where |
|---|---|---|
| Touch controller | `atmel,maxtouch` | i2c2 @ 0x4b |
| MIPI→LVDS bridge | `ti,sn65dsi83` | i2c2 @ 0x2c |
| RTC | `isil,isl12057/8` | i2c |
| Wi-Fi/BT combo | `brcm,bcm4329-fmac` | — |

Display timings were captured **verbatim from the running panel**, not guessed — see
[03-hardware.md](03-hardware.md).

## The static logo is `bootanimation.zip`, and it proves less than it looks

The stationary ThermaSol logo is `/system/media/bootanimation.zip` — a single frame looping
forever. `bootanim` starts only *after* `/data` mounts, so the logo proves the filesystem stage
completed.

But `bootanim` has **two** possible starters — `init` and SurfaceFlinger — so seeing the logo
proves only that `bootanim` is running. **Silence on the wire does not mean the boot stopped
before `netd`**: `netd` is native and starts at `zygote-start`, and `eth0`'s address is
configured by the *framework*, not by `netd`.

## A partial GApps overlay is fatal, and it is self-perpetuating

Privileged-permission failure mode, recorded because it bricks the panel to the static logo:

`/data/system/packages.xml` can carry the privileged private-flag (`privateFlags="8"`) for
`com.google.android.gms` against a privapp allowlist that exists only inside a **bind mount**
created by `gapps-bind.sh`. A reboot destroys the mount and the allowlist with it, so
`PermissionManagerService.systemReady()` throws inside `system_server` under
`ro.control_privapp_permissions=enforce` and `system_server` dies.

Because `boot_completed` is never sent, the hook that would re-apply the overlay can never run.
Deterministic and self-perpetuating.

**Repair, three steps** (step 2 alone was enough):

1. `rm -f /data/local/gapps-enable` and unmount any live overlay
   (`umount /system/priv-app /system/app /system/etc/permissions /system/etc/sysconfig`).
2. Move — **not delete** — `com.google.android.gms-*` and `com.android.vending-*` out of
   `/data/app` into a quarantine dir.
3. With the framework stopped, edit the GMS record in `/data/system/packages.xml`,
   `privateFlags="8"` → `"0"`.

**Why a partial overlay is fatal:** `gapps-bind.sh` binds priv-app *first* and the permissions
directory *third*. If priv-app binds and a later pair fails, GMS is privileged with no allowlist
— and `01-gapps` still fires `setprop ctl.restart zygote`.

**After the repair** the framework restart leaves the shower kiosk down: `service touchsteam` is
`class core`, `disabled`, `oneshot`, and nothing restarts it. `su 0 setprop ctl.start touchsteam`
brings it back.

Never recreate the bind mount, and never recreate `/data/local/gapps-enable`.

## Why something that "should" work doesn't

A table of inferences that looked sound and were wrong. Each is here so the same reasoning
isn't repeated.

| Wrong inference | Killed by |
|---|---|
| "`/data/local.prop` is a mechanism on Android 10" | the string table of the shipped `init` |
| "`ALLOW_LOCAL_PROP_OVERRIDE` makes the file inert" | the target property is defined nowhere, so the write-once rule never applies |
| "`service adbd` is not in the deployed config" | it is — in `/system/init.usb.rc`, which had not been looked in |
| "`adbd` starts automatically on every boot" | `/vendor/etc/init/hw/init.freescale.usb.rc` sets `sys.usb.configfs 2`, and no deployed action handles it |
| "a non-Termux adb path exists" | wrong inference from a true premise; access converges on Termux |
| "silence on the wire proves the boot stopped before `netd`" | `netd` is native and starts at `zygote-start`; `eth0`'s address comes from the framework |
| "the logo proves the failure is before Android" | `bootanim` has two possible starters, so it proves only that `bootanim` is running |
| "U-Boot netconsole is output-only" | false |
| "fastboot in 2019.04 is USB-only" | false |
| "`avc: granted` proves permissive" | invalid reasoning — the conclusion survives on `getenforce` instead |
| "the shower dies without vendor drivers" | all the drivers were already in the vendor tree |

**A claimed `adbd` USB-or-TCP control flow was string proximity presented as control flow**, and
the durability fix built on it was withdrawn. That is the pattern to watch for: a plausible
reading of a file that never checks the file's own gates.

---

## Bootloader

`U-Boot 2019.04-41468-ge20d4ecd9f (May 31 2022)`, commit `e20d4ecd9f` — the Variscite ADIN1300
PHY fix. That is also the build with `CONFIG_CMD_NET` + `CONFIG_CMD_TFTPBOOT`, which is what
makes network flashing possible at all. It has a `get_margin_pos` signing bug — see
[04-android15-port.md](04-android15-port.md) for why that forbids chaining `boot` in vbmeta.
