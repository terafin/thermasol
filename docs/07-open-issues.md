# 07 — Open issues

**The live list is the GitHub issue tracker:**
<https://github.com/terafin/thermasol/issues?q=is%3Aissue+is%3Aopen>

Only **work items** live there — things someone could actually do. Constraints, known-limitation
notes and "we decided not to" belong in this file, not in the tracker.

There are two open items.

| # | Work item | Who |
|---|---|---|
| [1](https://github.com/terafin/thermasol/issues/1) | **Ceiling speaker hiss** — power-cycle the speaker's own supply and listen | operator |
| [22](https://github.com/terafin/thermasol/issues/22) | **Re-test the store mirror on A15** — the original success was on Android 10 | operator |

**Everything else physical is confirmed working** on the device: speaker, light, touch,
steam, tap-to-wake, navigation and the seal.

**The hiss, in one paragraph.** Nine distinct CAN controls, the whole Android audio chain idle,
Android Bluetooth off, ~40 s of total host CAN silence, and finally **full SoC suspend** — the hiss
survived all of it. The panel emits nothing, so the noise is generated inside the ceiling unit.
`slsr_is_active = 0`: the legacy SLSR device is absent and every `slsr_*` command is a no-op. The
live device is HVLSR (firmware 7), and the only published firmware image is from 2021 and already
installed.

---

## Constraints and known limitations — deliberately *not* issues

These are facts about this panel. None of them is going to be worked on, and filing them as
issues just creates chores that never close.

| Thing | Reality |
|---|---|
| **Deep suspend** | Never wakes. No RTC or alarm wake source; the touch IRQ does not bring the SoC out. Recovery is the mains breaker. Never use `echo mem`. |
| **Power cycling** | The panel is not PoE. The only remote power action is a breaker trip, i.e. a human. |
| **Rollback** | Both slots hold A15, and switching has been proven before the wall closed. The **idle slot's current bootability** is a hash comparison, not a recent boot. See `docs/04-android15-port.md` §Rolling back. |
| **Bluetooth audio** | Bring-up baud is 115200 — enough to connect, not enough for A2DP. Not being chased. Pairing, range and accessory audio need a real peer and have not been tested. |
| **WebView** | Chromium 74 (2019); modern web UIs fail. Mitigated with native apps and Chrome's own engine. Not replacing the WebView provider on a sealed panel. |
| **Home Assistant dashboard** | ~82% of the SoC. That is a **dashboard** problem, not a panel defect — a lighter dashboard is the fix, and it belongs in the HA repo. |
| **Apple TV** | Deferred by the operator. Not work until they say it is. |
| **Heavy adb probes** | `dumpsys SurfaceFlinger`, `dumpsys window`, `logcat -d`, `ps -A --sort=-RSS`, repeated `screencap` each cost ~70 s of dead adb. An operating rule, not a bug to fix. |
| **ThermaSol approval** | None. The vendor app has two UI-only methods patched, the HAL binary was replaced, and the device tree was changed. Warranty service would find a non-stock device. |
