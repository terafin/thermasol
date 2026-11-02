# 07 — Open issues

**The live list is the GitHub issue tracker:**
<https://github.com/terafin/thermasol/issues?q=is%3Aissue+is%3Aopen>

Issues are the place to argue, claim, and close things. This page is the human-readable
summary — what is broken, how badly, and what "fixed" would mean. If the two ever disagree,
**the tracker wins**, and the discrepancy is a bug in this file.

Labels: `bug` · `audio` · `hardware` · `performance` · `drm` · `documentation` ·
`needs-operator` (someone has to physically be there) · `unverified` (written down, not proven).

---

## Unmet acceptance criteria

These are the reason the project is not finished. Everything else is a real defect that does
not block accepting the panel.

| # | Issue | Why it blocks acceptance |
|---|---|---|
| 1 | [Ceiling speaker hiss cannot be silenced](https://github.com/terafin/thermasol/issues/1) | Audible from the bedroom. Operator reported stock silenced it at sleep. |
| 8 | [Physical behaviours uncertified](https://github.com/terafin/thermasol/issues/8) | Speaker silence, light output and full-panel touch are **commands sent**, never observed by a human. Only the operator can close this. |
| 9 | [Rollback story is stale](https://github.com/terafin/thermasol/issues/9) | Following the docs' own recovery path would strand a sealed panel. Needs fixing before the wall closes. |

**The hiss in one paragraph.** Nine distinct CAN controls, the whole Android audio chain idle,
Android Bluetooth off, ~40 s of total host CAN silence, and finally **full SoC suspend** — the
hiss survived all of it. The panel emits nothing, so the noise is generated inside the ceiling
unit. `slsr_is_active = 0`: the legacy SLSR device is absent and every `slsr_*` command is a
no-op. The live device is HVLSR (firmware 7), and the vendor publishes exactly one 2021
firmware image, already installed. Next step is a power cycle of the speaker's **own** supply.

## Known defects, not acceptance blockers

| # | Issue | One line |
|---|---|---|
| 14 | [CAN sepolicy grant](https://github.com/terafin/thermasol/issues/14) | A15 grants `can_socket` only to `hal_can_socketcan`; the vendor service is `system_app`. Fixed on the device, undocumented. |
| 15 | [`adb root` crash-loops adbd](https://github.com/terafin/thermasol/issues/15) | Plus: from Termux, `su` is a stub that does nothing. |
| 16 | [Memory-pressure model](https://github.com/terafin/thermasol/issues/16) | Judge by `CmaFree`, never `MemAvailable`. Reversible debloat exists. |
| 17 | [Boot-hook supervision](https://github.com/terafin/thermasol/issues/17) | **An unpetted watchdogd resets the panel in ~60 s.** Live hazard. |
| 18 | [UI recipes / wrong `input tap` claim](https://github.com/terafin/thermasol/issues/18) | The doc says `input` is unreliable; it was used hundreds of times successfully. |
| 19 | [`ttaudiosource` interface](https://github.com/terafin/thermasol/issues/19) | The actual lever used in the hiss work is undocumented. |
| 20 | [App workstream](https://github.com/terafin/thermasol/issues/20) | `ttvolume`, app entry points, screencap — no home in the doc set. |
| 21 | [Image content gates](https://github.com/terafin/thermasol/issues/21) | Integrity passed while the image was content-wrong. |
| 23 | [Writing the running slot](https://github.com/terafin/thermasol/issues/23) | The rule is absolute; the repair that worked was a bounded exception. |

## Won't fix, or needs hardware

| # | Issue | Position |
|---|---|---|
| 2 | [Deep suspend never wakes](https://github.com/terafin/thermasol/issues/2) | Not fixable without a real wake source. Never try it. Breaker recovery only. |
| 3 | [Wi-Fi physically destroyed](https://github.com/terafin/thermasol/issues/3) | `wontfix`. Ethernet only. No more soldering is sanctioned. |
| 4 | [Bluetooth audio throughput](https://github.com/terafin/thermasol/issues/4) | 115200 connects but cannot carry A2DP. Needs a higher baud, and a real peer. |
| 5 | [Home Assistant is heavy](https://github.com/terafin/thermasol/issues/5) | ~82% of four cores. A lighter dashboard beats any code change. |
| 6 | [WebView is Chromium 74](https://github.com/terafin/thermasol/issues/6) | Modern web UIs fail. Mitigated with native apps. |
| 7 | [Apple TV sign-in](https://github.com/terafin/thermasol/issues/7) | Deferred by the operator. |
| 10 | [Heavy adb probes kill the panel](https://github.com/terafin/thermasol/issues/10) | ~70 s of dead adb. Single spaced reads only. |
| 11 | [TFTP chunk loop corrupts partitions](https://github.com/terafin/thermasol/issues/11) | Documented shape is missing the per-partition sector counts. |
| 12 | [U-Boot console mechanics](https://github.com/terafin/thermasol/issues/12) | `mmc dev 1 1` destroys the bootloader. `reset` discards `setenv`. |
| 13 | [Boot-debug methodology](https://github.com/terafin/thermasol/issues/13) | U-Boot ignores the boot.img cmdline. A dead console proves nothing. |
| 22 | [Store mirror untested on device](https://github.com/terafin/thermasol/issues/22) | Server tested locally; the panel's real APK request line is unknown. |

## Not a software issue

**Nothing here is ThermaSol-approved.** The vendor app has two UI-only methods patched, the HAL
binary was replaced, and the device tree was changed. ThermaSol has not been asked and would not
bless it. Warranty service would find a non-stock device.
