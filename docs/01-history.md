# 01 — History: stock to Android 15

A chronological account. Where a step was proven, the proof is named; where something is
still a guess, it says so.

---

## Phase 0 — Stock (until 2026-09-13)

Android 10, `eng.eric.20220531.120206`, userdebug (`ro.debuggable=1`), locked bootloader,
AVB green, verified boot enforcing.

The panel shipped **without any remote-access path**. `adbd` is `disabled` in
`/system/init.usb.rc`, and every `start adbd` in the deployed system is gated on a
`sys.usb.configfs` value this hardware never holds (the vendor sets it to `2` in `on boot`).
A full scan of `system.img`, `vendor.img`, `product.img`, `boot.img` and all seven APEX
payloads found no other `start adbd`.

**The only thing that ever started `adbd` — and `sshd` — was a Termux:Boot hook
(`00-restore-access`)**, which requires `BOOT_COMPLETED`.

### How a shell got onto a stock panel the first time

**What is verified:**

- **Aurora Store was installed on the stock panel.** It appears as a launcher entry in the
  2026-09-13 UI dump (`txt='Aurora Store' ... pkg=app.lawnchair`). Aurora is an open-source
  Play Store client, so the panel could fetch Play apps without signing a Google account in.
- **Termux was installed and running as a normal app.** `uid=10108(u0_a108)`,
  `context=u:r:untrusted_app_27:s0:c108,...` straight from `ps` and `id`.
- **`sshd` was running on port 8022**, as that uid, started by a boot hook with no adb
  involvement (`5790 u0_a108 sshd`).
- **The access stack was Termux:Boot hooks** under `~/.termux/boot/`, enumerated on-device:
  `00-restore-access`, `01-gapps`, `02-termux-wakelock`, `50-display-timeout-guard`,
  `70-sshd-watchdog` (later `40/52/55/60/65`).
- **ADB over TCP was part of it too** — `persist.adb.tcp.port=5555` is first dated to the
  2026-09-13 session, and `00-restore-access` sets `service.adb.tcp.port 5555` and calls
  `ctl.restart adbd`.

**Now verified, from the 2026-09-13 session log.** The route was **not** Aurora Store:

1. A **UniFi gateway local-DNS A record** pointed `thermatouch.tsolup.com` at a VPS the
   operator controls (`104.168.102.110`, host `zeal`).
2. A plain `python3 http.server` there served a hand-written `index.json` / `index-10.json`
   listing Termux, plus the APK at `/tmp/paneldata/termux.apk` (from F-Droid, 114,920,926 B).
3. The panel fetched both listings and then the APK, and **Termux installed from ThermaSol's own
   store screen** — operator: `it's installed`, then `i have a shell`.
4. `sshd` came up on 8022 from inside Termux.
5. **Termux:Boot was installed later over `adb`**, once that shell existed — it did not come
   through the store.

So the sequence is *DNS override → mirror → Termux → sshd → Termux:Boot via adb*, and it is
recorded step by step. The full recipe is in
[11-vendor-store-mirror.md](11-vendor-store-mirror.md) §"What was actually done".

**What is still unverified:** Aurora Store does appear as a launcher entry in the 2026-09-13 UI
dump, but there is no evidence it was the installation vehicle for anything above. It was
installed at some point by some route; that route is not recorded.

**Loose end:** no delete/revert of that DNS record appears in the log. It may still be live —
check the UniFi local-DNS table.

What *is* documented is that the panel was **rooted and reachable before any firmware was
ever touched**, using only apps the stock OS could install. That is the part that matters, and
it is repeated in [09-install-from-stock.md](09-install-from-stock.md) as a reproducible recipe.

> This is also why the access stack lives in `/data` and why flashing a new system image
> destroys it — see [04-android15-port.md](04-android15-port.md).

---

## Phase 1 — 2026-09-13: bricked, and recovered

An earlier attempt (a previous agent) left the panel unable to boot: stuck on the static
ThermaSol logo.

**Root cause:** `/data/system/packages.xml` carried the privileged private-flag
(`privateFlags="8"`) for `com.google.android.gms` against a privapp allowlist that only ever
existed inside a **bind mount** created by `gapps-bind.sh`. A reboot destroyed the mount and
the allowlist with it, so `PermissionManagerService.systemReady()` threw inside
`system_server` under `ro.control_privapp_permissions=enforce`, and `system_server` died.
Because `boot_completed` is never sent, the hook that would re-apply the overlay could never
run — deterministic and self-perpetuating.

**Fix, three steps** (step 2 alone was enough on 2026-09-13):

1. `rm -f /data/local/gapps-enable` and unmount any live overlay
   (`umount /system/priv-app /system/app /system/etc/permissions /system/etc/sysconfig`).
2. Move — **not delete** — `com.google.android.gms-*` and `com.android.vending-*` out of
   `/data/app` into a quarantine dir. This alone booted the panel immediately.
3. With the framework stopped, edit the GMS record in `/data/system/packages.xml`,
   `privateFlags="8"` → `"0"`. Verified byte-wise on the day: identical file size (533,432),
   one-line diff, 149 package tags before and after, owner/mode/SELinux label preserved.

**Why a partial overlay is fatal:** `gapps-bind.sh` binds priv-app *first* and the
permissions directory *third*. If priv-app binds and a later pair fails, GMS is privileged
with no allowlist — and `01-gapps` still fires `setprop ctl.restart zygote`.

**Residual after the repair:** the framework restart leaves the shower kiosk down, because
`service touchsteam` is `class core`, `disabled`, `oneshot` and nothing restarts it.
`su 0 setprop ctl.start touchsteam` brings it back.

Never recreate the bind mount, and never recreate `/data/local/gapps-enable`.

**Lesson recorded that day:** the stationary ThermaSol logo is
`/system/media/bootanimation.zip` — a single frame looping forever. `bootanim` starts only
*after* `/data` mounts, so the logo proves the `fs` stage completed and the failure is at
`system_server`. Silence on the wire does **not** mean the boot stopped before `netd`.

---

## Phase 2 — 2026-09-28: total loss of access

The panel stopped answering ICMP, ARP, and TCP. A read-only watch polled it every 2 s for
days.

The forensic work from this period (`session-20260928/ROOT-CAUSE-BRIEF.md`, 67 KB) is
worth reading in full if you ever lose this panel. Its durable conclusions:

- **Every carrier was closed.** Normal-boot `adbd`/`sshd` need `boot_completed`; recovery
  `adbd`, `fastbootd` and NXP SDP are USB-only; the U-Boot console and `tftpboot` need UART;
  a `/misc` BCB write needs root; no physical entry is documented.
- **Recovery mode does give `adbd`** (its `init.rc` has no `configfs` gate) — but recovery's
  `init.rc` brings up **loopback only**, with no `netd` and no DHCP, and its `adbd` is bound
  to USB functionfs. With USB excluded, that route is unreachable however you enter it.
- The deployed system image at that time was identified by hash and proven deployed from the
  previous transcript — not merely built.

That brief contains **nine retracted hypotheses**, kept deliberately as a record of what was
argued and why it was wrong. The ones worth knowing, because each looked obvious at the time:

| Retracted | Killed by |
|---|---|
| "`/data/local.prop` is a mechanism on Android 10" | the string table of the shipped `init` |
| "`ALLOW_LOCAL_PROP_OVERRIDE` makes the file inert" | the target property is defined nowhere, so the write-once rule never applies |
| "`service adbd` is not in the deployed config" | it is — in `/system/init.usb.rc`, which had not been looked in |
| "`adbd` starts automatically on every boot" | `/vendor/etc/init/hw/init.freescale.usb.rc` sets `sys.usb.configfs 2`, and no deployed action handles it |
| "a non-Termux adb path exists" | wrong inference from a true premise; access converges on Termux after all |
| "**silence on the wire proves the boot stopped before `netd`**" | `netd` is native and starts at `zygote-start`; `eth0`'s address is configured by the *framework* |
| "the logo on screen proves the failure is before Android" | the logo is `bootanimation.zip` — but `bootanim` has **two** possible starters, `init` **and** SurfaceFlinger, so the logo proves only that `bootanim` is running |

The access investigation also retracted, in its own revision table: "U-Boot netconsole is
output-only" (false), "fastboot in 2019.04 is USB-only" (false), and "`avc: granted` proves
permissive" (invalid reasoning — the conclusion survives on `getenforce` instead). One more:
a claimed `adbd` USB-or-TCP control flow was "string proximity presented as control flow",
and the 'durability fix' built on it was withdrawn.

That habit — keeping the retraction rather than deleting it — is why this repo exists in this
form.

---

## Milestone timeline (verified)

Dates and numbers pulled from the artifacts, not recalled.

| When | What |
|---|---|
| 2026-09-13 01:14 | `01-gapps` hook on disk (51 lines, 1,585 B) |
| 2026-09-13 01:30 | `/data/local/gapps-enable` created, 0 bytes |
| 2026-09-13 02:49 | `getenforce` → `0` (permissive) |
| 2026-09-13 04:09:03Z | `persist.adb.tcp.port=5555` first set |
| 2026-09-13 18:33–18:57 | `system_fec.img` written over U-Boot TFTP, 28 × 64 MiB chunks, each read back and compared |
| 2026-09-28 14:38:27 | `local.prop` written (824 B), reboot issued — **panel never answers again** |
| 2026-09-28 → 10-11 | Forensics; no transport to the panel exists |
| 2026-10-11 13:36 | adbd cgroup root cause proven: loops in `cpuacct:/uid_0/pid_<adbd>`; moving to `/acct/cgroup.procs` restores ADB in ~9 s |
| 2026-10-11 20:21 | First `saveenv` persisting the CMA change: `CmaTotal=327680 kB` (320 M) |
| 2026-10-11 21:13 | Pre-seal verify PASSED: ADB +45 s, SSH +81 s, slot `_a` green, `vbmeta_a` hash exact |
| **2026-10-11 22:08** | **Panel sealed into the wall (owner)** |
| 2026-10-12 | DT diff: 250 nodes / 1,377 properties; A15 BSP 357 MB, sha256 `b1b2abc7…` |
| 2026-10-12 | Rev-1→rev-2 DT corrections: `fec1grp` 1 pin → 16 pins; `atmel,panel-coords` `0 0 4131 1433` → `0 0 1023 599`; brightness levels 0–255 → 0–100 |
| 2026-10-15 → 10-18 | Android 15 port, flash, and the hardware defect tail |
| 2026-10-20 | Speaker audio killed by my own CAN experiments, then restored |

Bootloader identity, for reference: `U-Boot 2019.04-41468-ge20d4ecd9f (May 31 2022)`,
resolving to commit `e20d4ecd9f` — the Variscite ADIN1300 PHY fix. That is also the build
that has `CONFIG_CMD_NET` + `CONFIG_CMD_TFTPBOOT`, which is what makes network flashing
possible at all.

## Phase 3 — 2026-10-11 → 10-14: UART, root, and a supervision stack

Access was re-established physically, the panel was opened, and a rebuild of the access
stack began.

**Transport discovered:**

| Path | Status |
|---|---|
| UART console (host `/dev/cu.usbserial-A10OOP3V`, 115200 8N1) | works — but no adapter is attached as of 2026-10 |
| ADB over TCP 5555 (`<panel-ip>:5555`) | works, root |
| SSH 8022 (Termux `sshd`) | works |
| U-Boot console (interrupt autoboot) | works |
| USB / fastboot / SDP | **unavailable** — no USB on this panel |

**Flashing transport:** no USB, so all image writes are **U-Boot + TFTP** (`tftpboot` into
RAM, `mmc write`, then `mmc read` + `cmp` to verify every chunk). Proven on 2026-09-13 with a
28 × 64 MiB system image write, each chunk read back and compared.

**What was built (all in `/data`, all lost on a reformat):** a Termux-based stack of boot
hooks — panel healer, display-timeout guard, swipe-home detector, idle shutdown,
sshd watchdog, config snapshot. It was self-supervising and it is what kept the panel
reachable while experiments went wrong.

Two hard-won facts from this phase:

- **The panel is NOT PoE-powered.** A remote power cycle is impossible; it needs a breaker.
- **A Termux `adb` *server* on the panel is mutually exclusive with `adbd`.** It holds the
  smartsocket listener, so every `adbd` start aborts with
  `Could not install *smartsocket* listener: Address already in use`; init then latches
  `ro.init.updatable_crashing=1` and stops restarting `adbd` for the whole boot. That
  presents as a permanent loss of ADB.

---

## Phase 4 — 2026-10-15 → 10-18: the Android 15 port

Built from Variscite's `imx-android-15.0.0_1.2.0` BSP (`variscite-bsp-platform`, branch
`imx-android-15-var01`).

Headline findings:

- **The shower/CAN layer needed zero porting.** `mcp251xfd`, `can0_osc`, `pwm-backlight`,
  `wm8904`, `gpio-keys` are all already in the vendor tree. An earlier claim that "the
  shower dies without vendor drivers" was an unverified assumption and was withdrawn.
- Only four ThermaSol-specific devices had to be carried over: `atmel,maxtouch`,
  `ti,sn65dsi83`, `isil,isl12057/8`, `brcm,bcm4329-fmac`.
- Display timings were captured **verbatim from the running panel**, not guessed:
  clock 51.2 MHz, hactive 1024, vactive 600, hback 160, hfront 24, hsync 136, vback 29,
  vfront 3, vsync 6.

Then a long tail of defects — display, touch, audio, Bluetooth — each of which is
documented in [05-fixes.md](05-fixes.md).

---

## Phase 5 — 2026-10-18 → 10-20: behaviour

With the OS working, the remaining work was making it behave like a shower panel rather than
a tablet:

- A **volume curve** the operator could actually use (10 display steps, the top step being
  the accepted maximum, bottom still audible).
- **Fullscreen media** (Plex/Netflix/YouTube at 1024×600) with the volume overlay hidden
  and a notification tap to recall it.
- **Navigation inside ThermaSol** — the vendor app hid the Android bar and made its own
  controls unreachable.
- **Quiet idle** — no media, no touch for 5 minutes → backlight 0, lights off, speaker
  standby, but *never* deep suspend.
- **Unresolved:** the ceiling speaker hisses. See [07-open-issues.md](07-open-issues.md).
