# 10 — Known pitfalls

A flat list of "do not do this". Everything here is recorded from something that actually went
wrong, or from an artifact that proves it would.

## Panel state

| Do not | Because |
|---|---|
| **Suspend the panel** (`echo mem`) | It never wakes. No RTC/alarm source; the touch IRQ is registered as a wake source but does not bring the SoC out. Recovery is the mains breaker. |
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
| Reuse old hardcoded flash scripts | Two inherited scripts were recorded as defective (`deploy-slot-a.sh` writes a **0-byte** blob; a handoff wrapped an ELF as a shell script). |

## Tooling and diagnosis

| Do not | Because |
|---|---|
| Use bare `grep` / `find` here | They are shell **functions** and fail quietly. Use `command grep` / `command find`, or Python. A silent zero-result has produced false conclusions. |
| Treat a model's review as artifact proof | One whole review was adjudicated as decoding errors; several claims were literally misread hex. |
| Believe "the tests never compiled" from an empty log | Check the deployed artifact and run it. |
| Count a killed run as a RED | Only a controlled assertion failure is a RED. |
| Trust a chip identity from a bootarg or DT string | The kernel probe decided BCM4335C0, not the BCM43430 bootarg. |
| Assume `adb root` is safe | With a Termux adb **server** running, it kills `adbd` for the whole boot (`Address already in use`, then `ro.init.updatable_crashing=1`). |
