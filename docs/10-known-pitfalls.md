# 10 — Known pitfalls

A flat list of "do not do this". Everything here is recorded from something that actually went
wrong, or from an artifact that proves it would.

## Panel state

| Do not | Because |
|---|---|
| **Suspend the panel** (`echo mem`) | No RTC/alarm wake source; touch IRQ does not bring the SoC out. **The i.MX2 watchdog does reset it** (measured, unattended), and one accidental suspend healed in ~74 s — so it is not necessarily fatal, but it is not a sleep policy either. |
| Set `force_wifi true` | The vendor `MainControl` takes `eth0` **down** at startup. |
| Use `Utils.ShutdownAll` as an idle action | It stops steam and runs a water flush. |
| Start `PowerFlushActivity` or `FirmwareUpdateActivity` to "look" | Both act on real hardware in `onCreate`. |
| Pull the presumed CHG pin low as a test | **This caused a board reset.** Never drive it as an output, and never do raw MMIO on a runtime-suspended GPIO bank. |
| Trust `tinyplay`'s exit code | It returns **0** while printing `Error playing sample`. Check stderr and the SDMA IRQ count. |
| Read WM8904 `dapm/bias_level` / regmap `06`,`0c` as a power indicator | They read `Off` and `0000` during **normal, working playback**. |
| Send guessed CAN frames to the ceiling unit | Doing this **destroyed working audio** and it took hours to find. Capture the vendor app's own frames first. |
| Assume `slsr_*` commands work | `slsr_is_active = 0` on this unit — the legacy SLSR device **is not present**. The live device is HVLSR. |
| `avbab status` / `avbab show` | Those subcommands **do not exist** here. Read `misc` at `0x800` directly (32 bytes). |
| Run `avbab revert-a` casually | It **disables the other slot**. Read the running slot, boot id and CRC first. |
| Chain `boot` in vbmeta | `get_margin_pos` bug → the slot parks in fastboot **forever**; an AVB I/O error skips the tries decrement. |
| Count on the boot guard to roll back on its own | It does not reboot by itself. A bad trial needs a deliberate return. |
| Let a second reboot inherit a first boot's approval | That is the stale-approval bug; approval content is a **boot id**. |

## Build

| Do not | Because |
|---|---|
| Run `llvm-ar crs` on an existing archive | It appends **duplicate members**; the linker then picks stale code, and a green build lies. Delete the archive and assert the member list. |
| Trust "build completed successfully" | Verify by timestamp **and** hash that `boot.img`/`Image` were rebuilt. |
| Hand-pick `llvm-strip` flags | Use Soong's `strip.sh --keep-mini-debug-info` so the binary matches platform convention. |
| Use the host default JDK for the APK patch build | D8 rejects the class version; pin `--release 11`. |
| Re-derive AVB salt/props/size | Copy them out of `info_image` on the baseline, or the root digest changes silently. |
| Pack with `mkfs.erofs` without an empty-root `fs_config` entry | The pack fails. |
| "Fix" `--follow_chain_partitions` on `verify_image` | It is only meaningful when a chain exists — and the assertion right above it forbids one. |
| Write the running slot | Write the **inactive** one. ("Never write slot A" was an unauthored rule — see [AGENTS.md](../AGENTS.md) rule 2.) |
| Trust a `mmc dev 1 1` habit | `mmc dev` takes **exactly one argument**; `mmc dev 1 1` selects the boot0 hardware partition and **destroys the bootloader**. |
| Retype the decimal `mmc read` echo | `mmc part` prints hex with no `0x`; `mmc read` parses hex but **echoes decimal**. `738004` echoes as `block # 7569412`. |
| `reset` after `setenv` to "apply" it | `reset` reloads U-Boot's environment from eMMC and **discards the RAM change**. Use `run bootcmd`. |
| Assume the boot.img cmdline reaches the kernel | This U-Boot **ignores it**. Diagnostic flags only work via U-Boot `bootargs`. |
| Read a dead console as evidence the CPU is dead | `console=ttymxc3` precedes ramoops in the console list, so a stuck UART write wedges `console_flush_on_panic`. |
| Advance a TFTP chunk loop by a fixed `0x20000` | It pushes `dtbo_b` 60 MiB into `boot_a` and `boot_b` 16 MiB into `system_a`, **silently**. Compute sectors per partition from the panel's own GPT and assert `lba + sectors - 1 <= partition_end`. |
| Reuse old hardcoded flash scripts | Two inherited scripts were recorded as defective (`deploy-slot-a.sh` writes a **0-byte** blob; a handoff wrapped an ELF as a shell script). |

## Tooling and diagnosis

| Do not | Because |
|---|---|
| Use bare `grep` / `find` here | They are shell **functions** and fail quietly. Use `command grep` / `command find`, or Python. A silent zero-result has produced false conclusions. |
| Treat a model's review as artifact proof | One whole review was adjudicated as decoding errors; several claims were literally misread hex. |
| Believe "the tests never compiled" from an empty log | Check the deployed artifact and run it. |
| Count a killed run as a RED | Only a controlled assertion failure is a RED. |
| Trust a chip identity from a bootarg or DT string | The kernel probe decided BCM4335C0, not the BCM43430 bootarg. |
| Assume `adb root` is safe | Two separate failures. (a) A Termux adb **server** collides: `Address already in use`, then `ro.init.updatable_crashing=1`. (b) `adb root` itself sets `service.adb.root=1`, after which `adbd` **aborts on every start** and crash-loops with nothing on 5555. Recover without root: `setprop service.adb.root ""; setprop ctl.restart adbd`. |
| Trust `su` inside Termux or an app context | It resolves to **Termux's own stub** ("Termux does not supply tools for rooting", non-zero exit). Every `su 0 …` in a Termux-spawned hook is dead. `init` cannot exec `su` directly either (policy denial, `-92`). Use an `init → shell → su` route. |
| Run `dumpsys SurfaceFlinger`, `dumpsys window`, `logcat -d`, `ps -A --sort=-RSS`, or repeated `screencap` | Each is followed within ~50–70 s by load 19–22 and ~70 s of dead adb — twice needing a power cycle. Single spaced reads only; sample `/proc/pressure/memory` instead of `ps`. |
| Use `on_input`/injected swipes near ThermaSol's power control | An injected swipe hit the vendor power button, which called `killExternalApps` and left owner apps disabled. The panel healer re-enables them every 20 s for this reason. |
| Let `watchdogd` go unpetted | `/system/bin/watchdogd 10 50` must stay alive; **an unpetted WDT resets the panel ~60 s later.** |
