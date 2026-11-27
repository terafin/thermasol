# AGENTS.md

Guidance for AI agents working in this repo. Read this first, then
[`docs/00-overview.md`](docs/00-overview.md).

## What this repo is

Converting the ThermaSol ThermaTouch TT10V2 shower panel from its shipped Android 10 to
Android 15, with every Sonos player as a native Android audio output. Two parts:

- **[`scripts/panel/`](scripts/panel/README.md) — the pipeline.** Builds, flashes, tests, backs
  up, restores and recovers the panel. Every change to a panel goes through these scripts.
- **`docs/` — the record.** What was done, what was verified, what is still broken, written so
  the next person (or agent) does not repeat the mistakes.

The device is **sealed into a bathroom wall**. There is no USB and no reset button. Recovery is
over the network only (U-Boot TFTP hook), and a damaged bootloader means opening the wall.
Consequences below are not stylistic preferences.

---

## Orient in 60 seconds

| Question | Read |
|---|---|
| **Build, flash, test, back up, restore, recover** | **[`scripts/panel/README.md`](scripts/panel/README.md)** |
| What is the device? | [`docs/00-overview.md`](docs/00-overview.md) |
| Why does the panel behave this way? | [`docs/01-mechanisms.md`](docs/01-mechanisms.md) |
| How do I get a shell on it? | [`docs/02-access.md`](docs/02-access.md) |
| What hardware am I talking to? | [`docs/03-hardware.md`](docs/03-hardware.md) |
| How was the port done (history, BSP build) | [`docs/04-android15-port.md`](docs/04-android15-port.md), [`build/README.md`](build/README.md) |
| Why does X behave like that? | [`docs/05-fixes.md`](docs/05-fixes.md) |
| I need to do a procedure | [`docs/06-procedures.md`](docs/06-procedures.md) |
| What is still broken? | **[the issue tracker](https://github.com/terafin/thermasol/issues)** |
| Apps, audio control, adb UI recipes | [`docs/12-apps-and-control.md`](docs/12-apps-and-control.md) |
| Serving an app store / installing Termux on stock | [`docs/11-vendor-store-mirror.md`](docs/11-vendor-store-mirror.md) |
| I have a stock panel to convert | [`docs/09-install-from-stock.md`](docs/09-install-from-stock.md) |
| What should I avoid? | [`docs/10-known-pitfalls.md`](docs/10-known-pitfalls.md) |
| How was this written / what went wrong | [`docs/08-lessons.md`](docs/08-lessons.md) |
| The HydroVive amp and why it is silent | [`docs/14-hydrovive-recovery.md`](docs/14-hydrovive-recovery.md) |
| The panel will not boot | `scripts/panel/recover.sh <slot>`, or `restore.sh latest <slot> --uboot`; background in [`docs/16-network-recovery-hook.md`](docs/16-network-recovery-hook.md) |

---

## Working the open issues

**The GitHub issue tracker is the only list of what is still broken** — <https://github.com/terafin/thermasol/issues>.
Do not mirror it in a doc. Known constraints that are deliberately not issues are in
[`docs/10-known-pitfalls.md`](docs/10-known-pitfalls.md).

Labels mean what they say: `needs-operator` means a human has to be physically present — do not
"close" one from a successful adb command. `unverified` means written down but not proven.

The acceptance blockers, in order: speaker hiss (#1) and physical certification (#8). Rollback,
network recovery and restore-from-backup were rehearsed on the panel on 2026-11-27 (see
`scripts/panel/README.md`). Everything else is a real defect that does not block accepting the
panel. **Only the operator declares the project complete.**

When you fix something, close the issue with the evidence — the command, the output, the
artifact — not with "done". This repo has been burned repeatedly by claims that had no artifact
behind them; see [`docs/08-lessons.md`](docs/08-lessons.md).

## Hard rules — these are not negotiable

Each of these is here because **something actually broke** when it was ignored. Details and
evidence are in [`docs/10-known-pitfalls.md`](docs/10-known-pitfalls.md).

### Never do these to the device

0. **Never change a panel by hand.** No hand-run `dd`, `avbtool`, misc/A-B writes, `setenforce`,
   `chcon` or property edits. Use `scripts/panel/`; if a script cannot do something, fix the
   script. Run `backup.sh` before any write you have not rehearsed. Site settings (panel address,
   power switch, token command) live only in the git-ignored `scripts/panel/local.env` — never in
   a committed file.
1. **Never suspend the panel** (`echo mem > /sys/power/state`). It does not wake. There is no
   RTC/alarm wake source, and the touch IRQ does not bring the SoC out.

   If one is already suspended, **wait ~90 s before power cycling**: the i.MX2 watchdog resets
   the panel unattended (measured: uptime 30,628 → 106, new `boot_id`).
2. **Write the inactive A/B slot, never the running one.** Verify you read `ro.boot.slot_suffix`
   correctly and re-check it inside every write.

   This rule previously also read "never write slot A". **That was wrong and unauthored.** A
   transcript scan of all six sessions found 7 owner turns mentioning slot A — all authorising,
   none forbidding. Slot A was written and booted repeatedly. What matters is *inactive*, not
   *which*.

3. **Never chain `boot` in vbmeta.** A chain descriptor parks the slot in fastboot
   permanently — an AVB I/O error skips the tries decrement, so no reboot can drain it.
4. **Never write the bootloader, the GPT or the U-Boot environment** (the first 8 MB of the eMMC
   user area, and boot0/boot1). `lib.sh` refuses raw eMMC writes; do not bypass it. The chip's
   write-protect granularity (8 MB) would lock the recovery hook too, so it is not used.
   **Never write the U-Boot environment without keeping `run tt_nethook;` first in `bootcmd`**,
   and never use `env default -a`. The hook is the only way in when Android does not boot
   ([`docs/16`](docs/16-network-recovery-hook.md)); the panel was dark for a week on 2026-11-17
   because a saved environment dropped the Android command line.
5. **Never send `A5 BC 7B 01` (or `BD 01`) to any ThermaSol peripheral.** It toggles the MCU's BFB2
   option bit; the ST ROM then rejects ThermaSol's own images (stack pointer `0x20020000`) and the unit
   drops into the system bootloader, unreachable over CAN. This is how the HydroVive was lost on
   2026-11-16 ([`docs/14`](docs/14-hydrovive-recovery.md)). The DSV-4000 generator has the same handler.
6. **Never send guessed CAN frames** to the shower peripherals. Doing so destroyed working
   audio and took hours to diagnose. Capture what the vendor app emits and mirror it.
7. **Never call `Utils.ShutdownAll` as an idle action** — it stops steam and runs a water
   flush. Do not launch `PowerFlushActivity` or `FirmwareUpdateActivity` to "look".
8. **Never pull the touch CHG pin low, and never do raw MMIO on a suspended GPIO bank.**
   It caused a board reset.
9. **Never set `force_wifi true`.** The vendor `MainControl` takes `eth0` **down** at startup
   when it is set. The panel runs on Ethernet.

### Never do these in the scripts

- **Never use `adb exec-in` to write data.** It returned the right size with wrong content in 1 of
  3 tests. Write partitions with `lib.sh`'s `write_part_verified` (chunks pushed as files,
  sha-checked on the panel, whole-partition readback).
- **`lib.sh` runs `set -euo pipefail`.** A `grep -c`/`grep -q` that can match nothing inside a
  loop or `$( )` must tolerate it (`|| true`), or the script exits silently and its EXIT trap
  fires — this deleted a restore's chunks mid-transfer twice.
- **Never build an `rm -rf` target from variables** on the build host; use literal paths.

### Never do these in the build

8. **Do not `llvm-ar crs` onto an existing archive** — it appends duplicate members and the
   linker silently picks stale code. Delete the archive, then assert the member list.
9. **Do not re-derive AVB salt, props or partition size.** Copy them from `info_image` on the
   baseline, or the root digest changes silently.
10. **Do not trust "build completed successfully".** Verify by timestamp and hash that
    `boot.img` and `Image` were rebuilt.

### Never do these when reasoning

11. **Do not carry an agent's report as artifact proof.** A whole review was adjudicated as
    decoding errors, including a hex `0x0a` read as 6 instead of 10.
12. **Do not infer device state from WM8904 `dapm/bias_level` or regmap `06`/`0c`.** They read
    `Off` / `0000` during normal working playback.
13. **Do not treat a killed or crashed test run as a RED.** Only a controlled assertion
    failure is a RED.
14. **Do not quote numbers from prose.** Every figure in these docs has an artifact behind it;
    if you need a new one, measure it.
15. **Do not launder an inference into a requirement.** If it was not said in the transcript,
    label it as inference. Two of these had to be formally withdrawn (see
    [`docs/08-lessons.md`](docs/08-lessons.md)).

---

## Commands that work here

```sh
# the pipeline (needs scripts/panel/local.env; see scripts/panel/README.md)
scripts/panel/backup.sh                     # full read-only backup, checked against the panel
scripts/panel/test.sh                       # read-only health + silent playback test
scripts/panel/swap.sh _a|_b                 # change slot, keep the other as fallback
scripts/panel/recover.sh _a|_b              # panel won't boot: U-Boot sets the slot over TFTP
scripts/panel/restore.sh latest _a|_b       # put a slot back from the backup (adb)
scripts/panel/restore.sh latest _b --uboot  # same, with Android down (U-Boot over TFTP)

# panel access (see docs/02-access.md for finding the IP)
adb -P 5038 connect <panel-ip>:5555
ssh -p 8022 <panel-ip>

# read-only health snapshot
./scripts/panel-status.sh

# passive CAN capture — use this BEFORE changing anything
./scripts/can-capture.sh 10

# pull the APK that is ACTUALLY installed (not the build artifact)
./scripts/pull-installed-apk.sh com.thermasol.touchsteam2
```

Shell hygiene: `grep` and `find` are **shell functions** in some environments and fail
quietly. Use `command grep` / `command find`, or do it in Python. A silent zero-result has
produced false conclusions here.

---

## If you are asked to change something

1. **Read [the open issues](https://github.com/terafin/thermasol/issues) first.** Much of what looks
   unfixed was investigated to a hard stop — do not redo it.
2. **Read [`docs/10-known-pitfalls.md`](docs/10-known-pitfalls.md).** If the thing you are
   about to try is listed, do not try it.
3. **Record current state before touching it** — slot, boot id, vbmeta digest, and for
   peripherals the current settings.
4. **Prefer the vendor app's own controls** over hand-rolled commands, and capture what it
   emits.
5. **Verify against an artifact**, not against a status line. Hash the binary that is
   actually running (`/proc/<pid>/exe`), not the one you built.
6. **Scope your claim to the gate you actually passed.** "Booted twice" is not "Bluetooth
   works".

## If you are asked about the ceiling amp

The HydroVive has been unresponsive since the 2026-11-16 update command, and the board is out for repair (see [issue #1](https://github.com/terafin/thermasol/issues/1) and `docs/14-hydrovive-recovery.md`). Do not send CAN frames to it or restart the old hiss investigation.

## If you are asked to publish the images

The images live in the GitHub **release**, not in git (4.4 GB). `product.img` contains Google
proprietary apps and `vendor.img` is NXP/Variscite content; they are published as a device
backup for owners of this hardware. They are signed with the BSP's **public** stock test key
(`device/nxp/common/security/testkey_rsa4096.pem`) — the images are *not* device-locked, and
that is not what this build does.

---

## Editing these docs

- **Current truth only.** If something was retracted, remove it — but keep the retraction in
  [`docs/08-lessons.md`](docs/08-lessons.md), because that is the thing that stops a repeat.
- **Every claim needs a source.** If you cannot point at an artifact, mark it `UNVERIFIED`
  rather than asserting it.
- **Distinguish "verified", "not attempted" and "ruled out".** They are different, and
  conflating them is how the hiss investigation lost a day.
- Commit style: plain imperative subject, body explaining what changed and why. This is a
  public repo under a personal identity — no internal references, no credentials, no
  absolute home paths.
