# 05 — Defects and fixes

Each entry: the symptom, the actual root cause, the fix, and how it was proven. Where a fix
is a patch to the vendor APK, the technique is described in [06-procedures.md](06-procedures.md).

---

## 1. Blank / black display on Android 15

**Symptom.** Panel boots, backlight comes up, screen is black.

**Not the cause (all checked and eliminated).** CMA exhaustion — CMA was fine. The
`dma_heap` names were right. The panel cable was fine.

**Root cause.** A **heap name mismatch**: the device tree supplies a CMA heap named
`linux,cma`, but NXP's gralloc hard-codes `reserved` / `reserved-uncached`. The allocator was
never asked for the heap that existed. `galcore` only uses ~12 MiB, so capacity was never the
issue.

**Fix.** Rename the FDT node so the name gralloc looks for exists — one node rename,
properties unchanged.

**Trap found on the way:** the very dark panel at one point was a **stale `out/dtbo.img`**
being flashed, not a code problem.

**Also learned:** `can0` is brought up by the *host* timer, and the CAN client runs as a
`system_app` — neither is a display problem, but both were mistaken for one.

---

## 2. Touch does not work (the long one)

**Symptom.** Panel displays fine, touch does nothing. Or touch works briefly, then wedges.

**Root cause, in layers.**

1. The kernel's maXTouch driver is **interrupt-driven**, and the interrupt does not fire
   reliably on this board.
2. The stock Android 10 vendor driver **polls** instead.
3. A userspace workaround that polled was tried and **made things worse** — it duplicates the
   driver's own accounting and fights it.

**Fix.** Driver-owned polling: `vendor.tt.touch_driver=tt_mxt_polled`. The driver polls; no
userspace loop.

**Second, independent defect: stylus/finger stream confusion.** The Atmel controller
registers as a stylus-capable device. A same-device `STYLUS → finger` `ACTION_DOWN` was being
merged into the existing memento instead of cancelling it, so a finger press after a stylus
contact produced a corrupt stream (missing DOWN, or a stuck pointer). Fixed in
`InputState`, six lines: in the same-device branch, when a new `ACTION_DOWN` arrives with a
different tool type, return true to cancel the old stream before tracking the new pointer.

**Proven with.** A 27-check on-device regression harness covering same-id stylus→finger
CANCEL, different-device cancel, stray UP without DOWN, pointer-down edge cases.

**Vendor behaviour worth knowing.** The ThermaSol service *suppresses* stuck-touch IRQ
detection. That is intentional vendor behaviour, not a bug you should "fix".

---

## 3. Audio: silent, or wrong speed

**Symptom.** Playback runs, no sound. Or sound is present but pitched down / slow.

**Root cause.** **SDMA firmware not loaded.** The audio DMA engine needs its firmware; without
it the DMA path does not run correctly.

**Fix.** Load the SDMA firmware. After that, real PCM reaches the codec.

**Then, separately: too quiet.** The operator's own listening test set the accepted maximum:
WM8904 `Headphone Volume` **63/63** (+6 dB codec), which is +18 dB over the shipped 45/45,
with `Digital Playback Volume` 96/96 unchanged. The 63 is persisted via
`wm8904_config.json` `init_ctl`, so it survives reboot.

**Debugging trap that cost hours.** `dapm/bias_level` reads `Off`, and regmap `06`/`0c` read
`0000`, **during perfectly normal playback.** Do not use these as evidence that the codec is
unpowered.

---

## 4. Bluetooth missing entirely (no `hci0`)

**Symptom.** Android Bluetooth starts, crashes, aborts 6× at startup. No `hci0` device.

**Root cause.** The board integration was never done on this BSP. The HAL waited forever on
`/sys/class/bluetooth` before ever falling back to the UART path. The live device tree had the
radio disabled and inherited the console UART.

**Fix, in layers.**

- UART2 pinmux to the **stock four-wire** assignment (RX/TX/CTS/RTS, with `uart-has-rtscts`).
- Broadcom serdev child on UART2 with `shutdown-gpios` on GPIO2_IO6 and the correct supplies.
- Free the `BT_RX` pad by disabling the inherited `sec_rstn` GPIO4 hog.
- Load `btbcm`, `btqca`, `hci_uart` explicitly from `/vendor/lib/modules` in `early.init.cfg`
  (the system `modprobe` path is SELinux-denied; the vendor file path is already allowed).

**Actual chip is BCM4335C0**, not the BCM43430 the stock boot args suggested. The kernel
auto-selects `brcm/BCM4335C0.hcd` (build 0809).

**UART stays at 115200.** That is enough to connect, **not** enough for audio streaming. A
higher baud is a separate, unstarted piece of work.

---

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

**Proven with.** Real view-bounds assertions after a cold boot (content ends above the footer;
start strip and clock do not overlap) plus an actual on-screen Home press and return.

---

## 7. Volume range unusable

**Symptom.** Native media volume 0–15; below ~10 nothing is audible over running steam.

**Fix.** Native `STREAM_MUSIC` max raised to 18, floor kept at 0, and the floating UI maps ten
display steps onto raw 9–18. Anchors were checked against `AudioManager.getStreamVolumeDb`,
not assumed: old 10/15 = −14.45 dB equals new 12/18 = −14.45 dB, and old 15/15 = 0 dB equals
new 18/18 = 0 dB.

---

## 8. Fullscreen media leaves a stuck volume overlay

**Fix.** A small overlay app: a circular speaker bubble that hides itself when both status and
nav bars are absent, and a foreground-service notification whose explicit `SHOW` action recalls
the controls for 6 s. Uses `TYPE_APPLICATION_OVERLAY`, not focusable, not touch-modal.

---

## 9. Quiet idle does not silence things

**Symptom.** No media, no touch — display stays awake and the speaker keeps making noise.

**Fix.** An idle supervisor with three rules: 300 s of no touch and no media → backlight 0,
lights off, speaker standby; media playing → never dim; unknown state → fail safe (don't dim).
A `SCREEN_BRIGHT` wake lock is held so the panel dims without ever entering deep suspend.

**Hard rule:** the idle action sends only finite, known CAN frames (mute, light off, standby).
It never calls `Utils.ShutdownAll` (that stops steam) and never suspends.

---

## 10. Google: Play Store "device isn't certified", native YouTube blocked

Long chain, mostly account/registration work rather than code:

- Confirmed the device's actual GMS registration ID against `gservices.db` and `Checkin.xml`.
- Store and Services storage reset, then a **normal** account remove/re-add with the saved
  password and TOTP *(not* a spoofing or attestation workaround).
- After that, native Play Store installs worked (VLC, Calculator) and native YouTube played
  real video across reboots.

`gservices uncertified_status=1` persisted while everything worked. **That flag is not an
acceptance oracle.** No fingerprint, attestation, or ID spoofing was ever done.

---

## 11. The unresolved one: ceiling speaker hiss

Investigated to conclusion but **unresolved** — see
[07-open-issues.md](07-open-issues.md). Listed here only so the numbering is complete.
