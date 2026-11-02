# AGENTS.md

Guidance for AI agents working in this repo. Read this first, then
[`docs/00-overview.md`](docs/00-overview.md).

## What this repo is

Field notes from converting **one** physical ThermaSol ThermaTouch TT10V2 shower panel from
its shipped Android 10 to Android 15. It is **not a library**, not a buildable project, and
not a supported distribution. It is a record of what was done, what was verified, and what
is still broken — written so the next person (or agent) does not repeat the mistakes.

The device is **sealed into a bathroom wall**. There is no USB, no reset button, and no
documented recovery. Consequences below are not stylistic preferences.

---

## Orient in 60 seconds

| Question | Read |
|---|---|
| What is the device? | [`docs/00-overview.md`](docs/00-overview.md) |
| How did we get here, chronologically? | [`docs/01-history.md`](docs/01-history.md) |
| How do I get a shell on it? | [`docs/02-access.md`](docs/02-access.md) |
| What hardware am I talking to? | [`docs/03-hardware.md`](docs/03-hardware.md) |
| How is the image built and flashed? | [`docs/04-android15-port.md`](docs/04-android15-port.md), [`build/README.md`](build/README.md) |
| Why does X behave like that? | [`docs/05-fixes.md`](docs/05-fixes.md) |
| I need to do a procedure | [`docs/06-procedures.md`](docs/06-procedures.md) |
| What is still broken? | **[the issue tracker](https://github.com/terafin/thermasol/issues)** — index at [`docs/07-open-issues.md`](docs/07-open-issues.md) |
| Apps, audio control, adb UI recipes | [`docs/12-apps-and-control.md`](docs/12-apps-and-control.md) |
| Serving an app store / installing Termux on stock | [`docs/11-vendor-store-mirror.md`](docs/11-vendor-store-mirror.md) |
| I have a stock panel to convert | [`docs/09-install-from-stock.md`](docs/09-install-from-stock.md) |
| What should I avoid? | [`docs/10-known-pitfalls.md`](docs/10-known-pitfalls.md) |
| How was this written / what went wrong | [`docs/08-lessons.md`](docs/08-lessons.md) |

---

## Working the open issues

**The GitHub issue tracker is canonical** — <https://github.com/terafin/thermasol/issues>.
`docs/07-open-issues.md` is a human-readable index of it; if they disagree, the tracker wins.

Labels mean what they say: `needs-operator` means a human has to be physically present — do not
"close" one from a successful adb command. `unverified` means written down but not proven.

The acceptance blockers, in order: speaker hiss (#1), physical certification (#8), and an
untested rollback path (#9). Everything else is a real defect that does not block accepting the
panel. **Only the operator declares the project complete.**

When you fix something, close the issue with the evidence — the command, the output, the
artifact — not with "done". This repo has been burned repeatedly by claims that had no artifact
behind them; see [`docs/08-lessons.md`](docs/08-lessons.md).

## Hard rules — these are not negotiable

Each of these is here because **something actually broke** when it was ignored. Details and
evidence are in [`docs/10-known-pitfalls.md`](docs/10-known-pitfalls.md).

### Never do these to the device

1. **Never suspend the panel** (`echo mem > /sys/power/state`). It does not wake. There is no
   RTC/alarm wake source, and the touch IRQ does not bring the SoC out. **Recovery is the
   mains breaker.**
2. **Never write the running A/B slot.** Write the inactive slot only, and verify you read
   the slot correctly immediately before the write.
3. **Never chain `boot` in vbmeta.** A chain descriptor parks the slot in fastboot
   permanently — an AVB I/O error skips the tries decrement, so no reboot can drain it.
4. **Never send guessed CAN frames** to the shower peripherals. Doing so destroyed working
   audio and took hours to diagnose. Capture what the vendor app emits and mirror it.
5. **Never call `Utils.ShutdownAll` as an idle action** — it stops steam and runs a water
   flush. Do not launch `PowerFlushActivity` or `FirmwareUpdateActivity` to "look".
6. **Never pull the touch CHG pin low, and never do raw MMIO on a suspended GPIO bank.**
   It caused a board reset.
7. **Never enable Wi-Fi or "fix" it.** It is physically destroyed. Setting `force_wifi true`
   takes `eth0` down at startup.

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

1. **Read [`docs/07-open-issues.md`](docs/07-open-issues.md) first.** Much of what looks
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

## If you are asked about the ceiling speaker hiss

It is **unresolved**. Read [`docs/07-open-issues.md`](docs/07-open-issues.md) §1 before
proposing anything: nine distinct controls were tried and verified on the bus, and the noise
survived even a full SoC suspend. The remaining evidence points at the ceiling unit itself.
Do not restart the investigation from the beginning.

## If you are asked to publish the images

The images live in the GitHub **release**, not in git (4.4 GB). `product.img` contains Google
proprietary apps and `vendor.img` is NXP/Variscite content; they are published as a device
backup for owners of this hardware. They are signed with the BSP's **public** stock test key
(`device/nxp/common/security/testkey_rsa4096.pem`) — the images are *not* device-locked, and
an earlier version of these docs wrongly said they were.

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
