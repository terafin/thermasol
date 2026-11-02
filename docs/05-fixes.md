# 05 — Defects and fixes

Each entry: the symptom, the actual root cause, the fix, and how it was proven. Where a fix
is a patch to the vendor APK, the technique is described in [06-procedures.md](06-procedures.md).

---

## 1. Blank / black display on Android 15

Two separate faults, in sequence.

### 1a. The allocator could not find its heap

**Symptom.** Backlight comes up, screen is black. Log:

```
E DMABUFHEAPS: No ion heap of name reserved-uncached exists
E DMABUFHEAPS: No ion heap of name reserved-uncached exists
E NxpGralloc: allocator_allocate: libdmabufheap allocation failed for reserved-uncached heap
```

**Root cause.** A **heap-name mismatch.** The device tree declares the reserved pool as
`linux,cma` (`OF: reserved mem: initialized node linux,cma, compatible id shared-dma-pool`,
327,680 KiB), but NXP's gralloc asks for a heap named **`reserved-uncached`**. The allocator
was never asked for the heap that existed. It was never a capacity problem — `galcore` uses
about 12 MiB, not the whole 320 MiB.

**Fix.** Rename the FDT node so the name gralloc looks for exists, properties unchanged.

**Trap found on the way:** a very dark panel at one point was a **stale `out/dtbo.img`**
being flashed, not a code problem.

### 1b. The LVDS colour mapping

**Symptom.** The panel displays, but colours are wrong — reported physically as "the colours
on the bottom bar are all messed up, green and random crap".

**Root cause.** The panel's device tree declared `data-mapping = "jeida-24"`; this panel is
**VESA-24**.

**Fix.** One semantic value in the `panel-lvds` node: `jeida-24` → `vesa-24`. The dtbo was
repacked and re-signed with the same key and salt (public key sha1 `2597c218…`, identical to
baseline) into a 4,194,304-byte slot. Baseline dtb 68,820 B → fixed dtb 68,816 B.

**Verified** by physical operator acceptance — the sharpness and colour complaints both
cleared after this and the resolution fix landed.

## 2. Touch does not work (the long one)

Three distinct faults, each with its own fix.

### 2a. The hardware interrupt never fires

**Symptom.** Touch does nothing. Controller is perfectly healthy over I²C.

**Diagnosis.** The maXTouch itself is fine — bus 2, address `0x4b`,
`Family: 164 Variant: 3 Firmware V2.0.AA Objects: 41`, `Touchscreen size X4095 Y4095`.
But `/proc/interrupts` shows **zero hardware IRQs** on the CHG line while messages queue:

```
24: 0 49486 236240 0 gpio-mxc 2 Edge maxtouch
```

The artifact's own sentence: *"The CHG line on this panel (gpio1 io2, EDGE_FALLING) no longer
delivers usable edges, so the threaded handler never runs though the controller is fully
functional over I2C."*

**Fix.** A small driver module, `tt_mxt_polled`, derived from the stock
`atmel_mxt_ts.c`. It exposes `module_param(poll_interval_ms, uint, 0644)`, default `0`,
clamped `5..100`. With polling on, the IRQ stays requested but disabled
(`IRQF_NO_AUTOEN`; `enable_irq` is never called) and `mxt_interrupt()` is invoked from a
`delayed_work` under a lock. **With `poll_interval_ms == 0` the module is bit-for-bit stock
behaviour.** Deployed with 20 ms.

**What was tried and did NOT fix the interrupt** — recorded so nobody repeats it:

- ALT0 + SION runtime with falling and level-low triggers: input stays HIGH.
- The exact stock driver ported to A15: hardware IRQ still fails.
- T18 MODE/RETRIGEN/forced-level: no sampled GPIO response at all.
- **A GPIO pull-down test is what caused a board reset.** Never drive the presumed CHG pin as
  an output, and never do raw MMIO on a runtime-suspended GPIO bank.

The old vendor workaround (`irq65` always returning `IRQ_HANDLED`, idle IRQ rate 389–538/s)
is *"an intentional workaround, not proof of a valid CHG route."*

### 2b. A finger is dropped after a stylus contact

**Symptom.** After using a stylus, finger input stops working — reported as the UI freezing in
ThermaSol and Plex.

**Root cause.** In framework `InputState`, `trackMotion`'s stylus-priority pre-check dropped
finger DOWN/MOVE/UP permanently for that connection, and
`shouldCancelPreviousStream`'s same-device branch returned false without inspecting the
pointer tools.

**Fix.** Six lines in `libinput.so`: on a same-device `ACTION_DOWN` where the previous stream
was a stylus and the new pointer is not, return true so the old stream is cancelled before the
new finger is tracked. Only `InputState.o` changed.

**Verified.** Baseline replay `failures=4` (no CANCEL, no finger events); patched `failures=0`;
device-level **27 checks pass on two boots**; Activity replay 5/5 showing the exact sequence
`STYLUS DOWN, STYLUS MOVE, ACTION_CANCEL, FINGER DOWN, FINGER MOVE, FINGER UP`.
Deployed library sha256 `ad906bbd…`.

**A rejected attempt, kept in the record:** the first candidate put the same-device predicate
*after* the same-device early return, making the cancellation unreachable — it masked the
finger-drop but produced no CANCEL and failed on the device. Rejected.

**Limit:** the original physical first-stylus packet was never captured, so the exact
real-world trigger is not attributed — only that the sequence above reproduces it.

## 3. Audio: three separate faults

### 3a. Playback "succeeds" but nothing comes out

**Symptom.** `tinyplay` exits **0** while printing `Error playing sample`. Even an all-zero
3-second 48 kHz stereo PCM does not play. Kernel: `SAI5 soc_component_trigger -12`, and the
`SDMA 302c0000` interrupt count stays at **0**.

> Do not trust `tinyplay`'s exit code. It returns 0 on failure — check stderr and the DMA IRQ
> count.

**Root cause.** The combined boot ramdisk ships `imx-sdma.ko` but **not its firmware**,
`imx/sdma/sdma-imx7d.bin`. The product rule
(`device/variscite/imx8m/dart_mx8mm/dart_mx8mm.mk:122`) targets
`TARGET_COPY_OUT_VENDOR_RAMDISK`, and this legacy-boot assembly omits `vendor_ramdisk`
entirely. The kernel requests the firmware at early module probe — before `/vendor` mounts — so
both attempts return `ENOENT`. On this non-runtime-PM SoC variant the missing-firmware callback
never calls `sdma_runtime_resume`, so `is_on` stays false, the config write is rejected, cyclic
prep returns NULL, and the generic PCM path reports **`-ENOMEM(-12)`**.

**Fix.** Put the existing **3,202-byte** NXP `sdma-imx7d.bin` at
`/lib/firmware/imx/sdma/sdma-imx7d.bin` inside the combined early ramdisk. All **580**
pre-existing CPIO entries byte-identical, kernel bytes unchanged, boot params unchanged, boot
re-signed with the same key and salt, five vbmeta descriptors, flags 0, no chain.

**Verified.** Kernel: `imx-sdma 302c0000.dma-controller: loaded firmware 4.6`, all engines.
Then real playback: an active AudioFlinger track of **824,320 frames**, SAI5 DMA IRQ advanced
**931**, no trigger error, and two frame captures 4 s apart differ.

**A rejected theory worth naming:** an earlier agent claimed the driver lacked ROM script
addresses. It does not — the driver carries them; the fault was the missing
`sdma_runtime_resume`.

### 3b. Audio plays at the wrong speed

**Symptom.** Plex audio audible but *"VERY slow LOW voice"*. Measured, not guessed: a 3-second
48 kHz PCM took **6.24 s** of wall time, repeatably.

**Root cause.** Wrong clock parent on the WM8904 node — the codec was clocked from SAI3 instead
of SAI5.

**Fix.** One DT cell: `clocks = <&clks 0xb4>` → `<&clks 0xb8>`. That is **one byte at offset
32,927**; all other 68,771 bytes of the DTB are identical, kernel unchanged, AVB five-partition
verify passes. Written only to the inactive slot.

### 3c. Too quiet

The operator's own listening test set the accepted maximum: WM8904 `Headphone Volume` **63/63**
(+6 dB codec), which is +18 dB over the shipped 45/45, with `Digital Playback Volume` 96/96
unchanged. The value is persisted in `/vendor/etc/configs/audio/wm8904_config.json` `init_ctl`,
so it survives reboot — one added property, nothing else changed.

**Debugging trap that cost hours.** `dapm/bias_level` reads `Off`, and regmap `06`/`0c` read
`0000`, **during perfectly normal playback**. Do not use these as evidence that the codec is
unpowered.

## 4. Bluetooth missing entirely (no `hci0`)

**Symptom.** The Android BT stack SIGABRTs:

```
Abort message: 'system/gd/stack_manager.cc:57 StartUp: Can't start stack, last instance: starting HciHal'
```

Six attempts. The HAL process is registered and running, but its thread sits in
`wchan = do_sys_poll`. `/sys/class/bluetooth` and `/sys/class/rfkill` are **empty**:
`live_hci_controllers: 0`, `live_rfkill_nodes: 0`.

**Root cause.** *"Missing A15 board transport integration; hardware health not proven."*

Concretely: `BluetoothHci::initialize` → `NetBluetoothMgmt::openHci()` →
`waitHciDev(0)` polls the Linux mgmt socket **forever** and never returns an error, so the UART
fallback below it is unreachable. And there was nothing to find, because the live DT had the
Broadcom node **disabled under uart4** — which is the kernel console `ttymxc3`, not the BT UART.
Only `bluetooth` and `rfkill` modules loaded; `hci_uart`, `btbcm` and `btnxpuart` did not, and
`init-insmod-sh` was denied on `/system/lib/modules/rfkill.ko`.

Stock A10 had used `androidboot.bt_uart=/dev/ttymxc1`, `bt_firmware=BCM43430A1.hcd`,
`bt_sdio_id=0xa9a6` — none of which exists on A15.

**Fix, and deliberately narrow** — DTBO and vendor only, **zero core-partition change**:

- UART2 with the stock four pads (SAI3 RX/TX/CTS/RTS) and `uart-has-rtscts`.
- A `brcm,bcm43430a1-bt` serdev child, `shutdown-gpios` on **GPIO2_IO6**, pinctrl `btengrp`,
  `vbat` from `WIFI_PWR_3V3`, `vddio` from `WIFI_PWR_1V8`, max speed 115200.
- **Disable the inherited `sec_rstn` GPIO4_IO31 hog** and drop gpio4's `pinctrl-0` to free the
  BT_RX pad (stock SAI3_TXFS).
- uart4/console untouched. Wi-Fi SDIO untouched.
- Vendor: append **three direct `insmod` lines** to `etc/early.init.cfg` after the existing
  modprobe. No SELinux relaxation — the `vendor_file` label is already allowed to
  `init-insmod-sh`. 999 vendor inodes and their metadata preserved.

Kernel, HAL, boot, system and product unchanged.

**The actual chip is BCM4335C0, not BCM43430.** The kernel probe says chip id **86**,
`BCM4335C0 (003.001.009)`, and the kernel auto-selects `brcm/BCM4335C0.hcd` build **0809**.
The A10 bootarg `BCM43430A1` was *"not valid actual chip identification proof; it was a
fallback/config value."* The DT compatible string was kept anyway — it binds the generic BCM
driver with no quirks and no `.data`, so relabelling it would churn a working binding for
nothing.

**Verified.** Host tests 10 pass against a real baseline that fails 4; `hci0_registered: true`;
Android **ON** with zero aborts for 300 s, then **5 min 40 s** on the first boot, and zero
aborts after a normal automatic reboot with no manual enable and no module load.

**Review claims that were false, and how they died** — worth keeping, because each looked
plausible:

| Claim | Reality |
|---|---|
| "BT and Wi-Fi collide on a GPIO" | BT `<0x33,6,0>` vs Wi-Fi `<0x33,10,1>` — hex `0x0a` is decimal **10**, not 6 |
| "the deployed image is missing the compatible/loader" | both are in the signed artifact; six-partition read-back proves it |
| "remove the original generic modprobe" | that would regress unrelated module loading |
| "the compatible's quirk is missing" | the `bcm4335a0` entry has no `.data` |
| "`sec_rstn` gpio 31 dangles at a clock phandle" | gpio-hog children use controller-local `<offset,flags>` |
| "pad `0xb8` maps GPIO2_IO4" | the actual imx8mm pinfunc says **GPIO2_IO6** |
| "9 tests" | read from a stale artifact; the current suite reports 10 |

**Recorded limits:** discovery returns `HCI_SUCCESS` with **0 devices**; no peer was paired;
RF range and accessory audio are unverified; 115200 is bring-up speed, not accepted audio
throughput.

## 5. Bluetooth dies after the second OFF/ON cycle

**Symptom.** Toggle Bluetooth off and on twice; the second `HCI RESET` times out and the
controller aborts.

**Root cause.** **HCI command truncation on close.** The HAL closed the user-channel socket
without waiting for outstanding commands to complete. The last command on the wire was a
245-byte Write Extended Inquiry Response (`0x0c52`); closing mid-frame left the controller's
UART parser holding a partial packet, so the next `RESET` was never parsed.

Proven with an isolated native probe: send the 245-byte command and close immediately →
reopen fails **2 of 3** runs. Wait for Command Complete before close → passes **3 of 3**.

**Fix.** A bounded command drain in the AIDL HAL close path — track submitted opcodes,
reconcile Command Complete/Status, wait up to 1 s with the reader still alive, then close.
Plus: reject new writes once `CLOSING`, and propagate `H4Protocol::Send` failures instead of
silently claiming success.

**Proven with.** 20 real AIDL close/reopen cycles (close drains in 23–25 ms), then 20 real
Android OFF/ON cycles with zero new crashes. Deployed to the inactive slot, boot-verified,
then a normal reboot.

**Build trap found here.** `llvm-ar crsP` on an *existing* archive appends duplicate members
and the linker then picks stale code. The build must remove its own archive first, and assert
the member list is exactly the expected two objects.

---

## 6. The Android navigation bar is unusable inside the ThermaSol app

**Symptom.** In the ThermaSol app the Android bar is gone and swiping up does not reveal it —
you cannot leave the app.

**Root cause.** The vendor app sets `SYSTEM_UI_FLAG_IMMERSIVE_STICKY | FULLSCREEN |
HIDE_NAVIGATION` (`0x1006`) in `Utils.applyFullscreenOptions`, re-applied on resume and on a
periodic refresh. `policy_control` does not work on this A15 build — AOSP's `PolicyControl`
parser is not present, and the CarSystemUI implementation is not built in.

**Fix.** One instruction in the vendor APK: `0x1006` → `0x4`. Status bar stays hidden,
navigation bar is not requested hidden, no immersive sticky. Global
`nav_bar_force_visible` goes back to `0`, so Plex/Netflix keep real fullscreen.

**Second defect exposed by the fix.** With the bar visible, the app's own footer overlapped:
the content area was sized once from display height and the clock collided with the start
strip. Fixed by constraining the fragment container between the vendor's top and bottom bars
(`MATCH_PARENT` + `layout_above` the bottom bar) rather than computing a height from metrics.

**Proven with.** Real view-bounds assertions from a **1024×600** view hierarchy:

| | before v2 | after v2 |
|---|---|---|
| content `mainFrame` | 64..**558** (overlaps footer) | 64..**494** |
| vendor footer | 494..558 | 494..558 |
| start strip | 504..537 | 440..473 |
| clock | 507..544 | 507..544 |

Then, after a cold boot: nav visible with `nav_bar_force_visible=0`, actual Home exits,
actual Back returns from Settings, Plex still fullscreen, and the shower hardware service
pid **1859** survived the whole APK swap without restarting.

One probe failure kept in the record: the first Back tap targeted y=579 and missed, because
the Settings taskbar controls sit at y=548 — re-targeted against an actual screenshot, it
passed.

---

## 7. Volume range unusable

**Symptom.** Native media volume 0–15; below ~10 nothing is audible over running steam.

**Fix.** Native `STREAM_MUSIC` max raised 0..15 → 0..18, and the floating UI maps ten display
steps onto raw 9–18 as a pure offset: `display = raw − 8` (raw 9→1 … 18→10), clamping at both
ends, with **no mute step**.

Anchors were checked with `AudioManager.getStreamVolumeDb`, not assumed — and they hold for
both the speaker and wired-headphone stream types:

| | old | new |
|---|---|---|
| former minimum | raw 10/15 = **−14.45 dB** | raw 12/18 = **−14.45 dB** |
| accepted maximum | raw 15/15 = **0.0 dB** | raw 18/18 = **0.0 dB** |

All ten new levels are distinct in dB (−16.575 at raw 11 through 0.0 at raw 18). A real
hardware-button sweep confirmed the clamps: 11,10,9,**9** then 10…18,**18**.

Codec gain 63/63 is persisted as one added property in the WM8904 config
(`{"name":"Headphone Volume","type":"int","val":63}`), applied by the HAL at boot.

Tests: 50 legacy `VolumePolicy` assertions, 43 `TenStepVolume`, 5 + 6 Python suites, the DEX
startup verifier, 27 device `InputState` checks.

---

## 8. Fullscreen media leaves a stuck volume overlay

**Fix.** `net.example.ttvolume` / `.VolumeService` — a circular speaker bubble that
hides itself when **both** status and navigation insets are absent, and becomes
non-touchable at the same time (so it cannot swallow a tap meant for the player).

Recall path: the foreground-service notification (id **1726**, channel `shower_volume`,
ONGOING) carries an **immutable** `PendingIntent` that opens the strip for **6 seconds**, then
it auto-rehides. `POST_NOTIFICATIONS` is declared and granted, and survives reboot.

Verified: Plex, Netflix and YouTube players all measure **1024×600** with `hidden=true` and
`windowTouchable=false`; notification recall and re-hide happen for real; the process is
`START_STICKY` and restored itself in 7.98 s mid-fullscreen.

**Explicit non-promise:** the bottom swipe reveals only the transient 3-button bar, *not* the
volume bubble — InsetsPolicy filters that visibility. The notification is the reliable path.

---

## 9. Quiet idle does not silence things

**Symptom.** No media, no touch — display stays awake and the speaker keeps making noise.

**Fix.** An idle supervisor, **300 s** of no physical touch *and* no media, then lights off,
speaker mute and backlight 0.

Three rules that matter:

- **Anything with `PLAYER_STATE_STARTED` holds it off** — including muted video. Verified over
  19 observations across 366.4 s of real Plex playback with the display held at 71.
- **Unknown media state fails safe** — it inhibits dimming rather than guessing.
- **A tap restores only the display.** The ceiling light is not auto-relit; the mute is undone
  when media starts again.

**Why a `SCREEN_BRIGHT` wake lock:** the vendor app writes `screen_off_timeout=300000` in
`MainControl.selectTopMenuFromDeviceConfig`, so the framework would dim on its own schedule.
Holding `SCREEN_BRIGHT_WAKE_LOCK 'TTIdleDim'` for the supervisor's lifetime keeps
`mStayOn=true` and leaves dimming entirely to the controlled native child. That is also why
the panel never enters deep suspend.

**The CAN allowlist is exactly four frames** — mute `A5 B5 7B 01 …`, light-off
`A5 B4 7B 00 …`, standby `A5 5F 7B FF`, and unmute `A5 B5 7B 00 …` which is only sent if this
coordinator owns the current mute. Anything heat/water/flush/radio/BT-power related is
forbidden by construction.

**Related defect found here:** the bind-only `HardwareService` died when the last UI went
away → native cache OOM → LMKD kill → CAN heartbeat stopped → the generator reported
`CANCommunicationError`. Mitigated with a small foreground-service binding keeper.

**Hard rule:** the idle action sends only finite, known CAN frames (mute, light off, standby).
It never calls `Utils.ShutdownAll` (that stops steam) and never suspends.

---

## 10. Google: Play Store "device isn't certified", native YouTube blocked

Long chain, mostly account/registration work rather than code.

**Registration ID: 3466599662105785551**, confirmed against `gservices.db` and `Checkin.xml`,
and **unchanged** across the storage reset, the account remove/re-add and the final repair.

**What was reset** — narrowly, after a verified backup (3,510 entries, 0600, SHA-checked):
`pm clear` on `com.android.vending` and `com.google.android.gms` **only**. `com.google.android.gsf`,
YouTube, Plex, Netflix, 1Password, Home Assistant and the ThermaSol app were explicitly not
touched (`other_app_data_cleared: false`, `GSF_cleared: false`).

**What else was done**, all normal/supported operations: cloud backup off; Store
system-update uninstall (which returned exit 1 while the package path *did* change — recorded
as-is, not claimed clean); a normal account remove and re-add with the saved password and
current TOTP; cache-only clears; and a free VLC install as a proof probe.

**What was NOT done** — and this is the line that matters: no Google APK patched or
re-signed (installed YouTube's sha256 still matches the pre-investigation copy), no
certification component disabled, no verdict payload or compliance flag edited, no SSAID /
GSF ID / fingerprint / attestation change. Decompilation was read-only on a host copy.

**On the certification flag:** `gservices uncertified_status = 1` persisted — before the
repair, after it, and after the Services reset — **while native media played**. The flag is
not an access oracle, and a successful check-in does not make the device certified. The cached
signed verdict decoded to `DO_NOT_ENFORCE`; that means "not being forced", which is not the
same as "certified".

**Acceptance evidence:** after a normal reboot, an authenticated Play Store app detail page,
and native YouTube advancing 0:23 → 0:35 → 0:44 → 0:54 → 1:05 over 67 s with no sign-in error.
Two successive boots passed.

**Not isolated:** the exact single causal action was never proven, and two theories were
explicitly rejected — a 30-minute negative-verdict throttle (the class involved is a DroidGuard
error-report throttle) and a clock/NTP problem (the issued bounds fit the boot clock, so there
was nothing to fix).

---

## 11. The unresolved one: ceiling speaker hiss

Investigated to conclusion but **unresolved** — see
[07-open-issues.md](07-open-issues.md). Listed here only so the numbering is complete.
