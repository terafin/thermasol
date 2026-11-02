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

Stock has a Play Store. It also has a vendor browser and side-loading enabled. The route
that worked was:

1. Install **Aurora Store** (an open-source Play Store proxy client) to download and
   install **Termux** and **Termux:Boot** without a Google account on the panel.
2. In Termux, install `openssh`, push an `authorized_keys`, run `sshd` on **port 8022**.
3. Install the `00-restore-access` Termux:Boot hook so `adbd` and `sshd` come back after
   every boot.
4. From there, `su 0` gives root (this is a userdebug build).

That is the whole trick. Everything else in this project descends from it: **the panel was
rooted and reachable before any firmware was ever touched**, using nothing but apps the
stock OS could install.

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

**Fix:** quarantine GMS from `/data/app` and clear `privateFlags` `8`→`0` on its record with
the framework stopped. Never recreate the bind mount, never recreate
`/data/local/gapps-enable`.

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

That brief also contains several **retracted** hypotheses, kept deliberately as a record of
what was argued and why it was wrong. That habit is why this repo exists in this form.

---

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
