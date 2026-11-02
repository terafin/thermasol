# 01 — Mechanisms

Why this panel behaves the way it does. Not a chronology — the durable facts, each with the
evidence behind it, so you can predict what it will do instead of rediscovering it.

Where something is a reconstruction rather than a measurement, it says so.

---

## `adbd` on stock stops at a shell you do not have yet

The whole access model starts here, and the two builds are **not** the same.

### On the shipped Android 10 build — Termux is the only way in

`adbd` is `disabled` in `/system/init.usb.rc`, and every `start adbd` in that image is gated on
a `sys.usb.configfs` value this hardware never holds. A scan of `system.img`, `vendor.img`,
`product.img`, `boot.img` and all seven APEX payloads found no other `start adbd`.

So on A10, **the only thing that ever brought up `adbd` — or `sshd` — was a Termux:Boot hook**
(`00-restore-access`), and that hook needs `BOOT_COMPLETED`, which needs Termux installed first.

There is no vendor mechanism to lean on. That is why the install path is
[09-install-from-stock.md](09-install-from-stock.md): get a shell by redirecting the vendor
store, and everything else follows.

### On the Android 15 build — Termux is not involved

Observed on the deployed A15 panel:

| | Value |
|---|---|
| `init.svc.adbd` | **running**, pid 550, started at **20.94 s** uptime, ppid 1 (init) |
| `persist.sys.usb.config` | `adb` |
| `ro.debuggable` | `1` |
| `ro.boot.usb.debugging` | empty — that trigger never fired |
| `pm list packages \| grep termux` | **no match** |
| Termux on the device | **not installed** |

`init.usb.rc` has `on boot && property:persist.sys.usb.config=*` →
`setprop sys.usb.config ${persist.sys.usb.config}`, which sets `sys.usb.config=adb`.

The most plausible mechanism — **inference, not proven** — is that `on init` sets
`sys.usb.configfs 0`, the `on boot` above sets `sys.usb.config=adb`, and that pair satisfies
`property:sys.usb.config=adb && property:sys.usb.configfs=0` → `start adbd`; the vendor's own
`on boot` then flips `configfs` to `2` afterwards, which is the value visible once the panel is
up.

**Consequence:** on A15 `adbd` comes up on its own, and `persist.sys.usb.config` is a
**persistent** property — it survives a `/data` wipe. Do not assume that means access is safe:
that has only been observed across one 12-day uptime, not across a reboot.

**Recovery mode gives `adbd` regardless.** Its `init.rc` has no configfs gate. But it brings up
**loopback only** — no `netd`, no DHCP — and binds `adbd` to USB functionfs. With USB excluded,
that route is unreachable however you enter it.

Reachable transports on the current build:

| Path | Notes |
|---|---|
| ADB over TCP 5555 | works, root — self-started on A15 (see above) |
| SSH 8022 (Termux `sshd`) | **not present on the current A15 image** — Termux is not installed |
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
| "`adbd` never starts on its own, so nothing to worry about there" | true on **A10** only. On the **A15** build it starts itself at ~21 s from `persist.sys.usb.config=adb` — see above |
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
