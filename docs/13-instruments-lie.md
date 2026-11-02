# 13 — Your instruments lie

The single most expensive lesson in this project: **most of the time lost went to measurement,
not to hardware.** Weeks of work produced dozens of cases where a tool returned a clean, confident,
wrong answer. They all look identical — an empty result, a zero, a pass.

This is the catalogue, so you recognise the shape instead of re-deriving it.

---

## 1. Absence is not evidence

Five distinct mechanisms produced "nothing found" on things that were there.

| Mechanism | What you see | How to catch it |
|---|---|---|
| `grep`/`find` are **shell functions** here wrapping ugrep | `error: unknown option '-G'`, rc=1, or silent zero. Also **honours `.gitignore`** | `type grep`; use `command grep` |
| `grep` over a **raw EROFS image** | reports present services as missing — blocks are compressed | `fsck.erofs --extract`, or mount it |
| `grep` over a file containing a **NUL byte** | "binary file matches", then silent truncation at that point | `grep -a` |
| **Mis-cased symbol** | searching `MCP251XFD` when the config is `CAN_MCP251XFD` → "24 missing drivers" (real answer: 5) | search a shorter substring, then confirm |
| **Loose regex** | `allowxperm` matched by a search for `allowx` → "1 match" when an anchored search gives 0 | anchor it: `^…$` |

The rule: **a zero needs a positive control.** Before believing "nothing there", prove the same
mechanism finds something you know exists in the same file.

## 2. A pass that measured the wrong artifact

`CONTENT-GATES` reported **ALL PASS** while reading `out/…/recovery/`. The file actually on the
wire was a stale `/tmp/ubflash/boot.img` carrying four stale `.ko`. Two more stale-artifact
incidents followed in the same session.

Three separate "successful builds" assembled `boot.img` from a **six-hour-old kernel** because
`./imx-make.sh … 2>&1 | tail -12` hid a parse-time failure — a pipeline's exit status is the
last command's.

And `make bootimage` **never reaches the kernel**; only `imx-make.sh kernel` does.

**Check**: hash the artifact you are about to write, not the one you just built. Compare it to
the hash on the device after writing.

## 3. A gate that says FAIL when the thing is fine

As corrosive as a false pass, because it teaches you to ignore the gate. Nine were found in one
night:

- `strings | grep -q` under `pipefail` → two false FAILs
- `.config` treated as a source file
- `cmp` count units are **longs**, not bytes
- `cmp` mismatch output matches no failure word, so a mismatch reads as success
- a `hash` step that computed but never compared
- a nested heredoc `SyntaxError` that left the flasher broken
- a harness whose scratch directory was deleted → three false FAIL counts
- `mkbootimg.py` forcing `second_addr = 0` unless `--second` is non-empty
- a chunker that matched `.ko` against a list of `.o`

## 4. The instrument killed the patient

Three separate incidents where the *probe* took the panel off the network, then the outage was
diagnosed as a hardware fault:

- `dumpsys SurfaceFlinger`, `dumpsys window`, `logcat -d`, `ps -A --sort=-RSS`, repeated
  `screencap` — each followed within 50–70 s by load 19–22 and ~70 s of dead adb
- a 60-second health timer using `ps --sort=-RSS` **was** the load spike it reported
- a `sysrq-trigger` panic test finished the job

A fourth: **`settings put system screen_brightness 102`** killed `system_server` and dropped the
panel off the network. Not a reboot, not a driver — a brightness write.

**Rule**: before diagnosing instability, stop your own sampling and see if it stops.

## 5. Two instrumented opens on one port

A serial helper opened the UART twice (`3u` + `15u`) and produced ~45 minutes of phantom
`[confirm] 0 bytes`, from which a wrong "console is suspended" conclusion was drawn. Two flashers
on the serial port faked a read-back failure.

**Rule**: exactly one process on the console, ever.

## 6. More than one boot in a capture

Two milestones were built on **concatenated logs** from different boots. On-device clocks also
drift — this panel's RTC is dead, so timestamps oscillate between dates mid-file, and host vs
device clocks differed by ~7 h.

**Rule**: every milestone starts by recording `boot_id`, `slot_suffix` and `vbmeta.digest`, and
every capture is bounded by a known `boot_id`.

## 7. Config that is not what it says

- **`# CONFIG_X …` in a Kconfig fragment is a directive**, not prose. A comment written to
  *explain* the clock fix **disabled** it.
- A `#` inside a backslash-continued make list silently truncated `modules.load` from ~70
  entries to **2**.
- `BOARD_KERNEL_CMDLINE` is **inert** on this platform — the effective cmdline is
  `CONFIG_CMDLINE` plus U-Boot's `bootargs`.
- `setenv bootargs` is RAM-only; `reset` reloads env from eMMC and discards it. Use `run bootcmd`.
- `/delete-node/` and `/delete-property/` in a compiled `.dtso` are **silently dropped**.
- A Kconfig symbol compiled out (`# CONFIG_WATCHDOG_SYSFS is not set`) makes the sysfs class
  directory empty — which was read as "no driver", and a **correct** prior note was "corrected"
  away on that basis. The watchdog was bound the whole time.

## 8. The constraint nobody wrote

An agent enforced "never write slot A" for hours. A filtered scan of all six transcripts found
**7 genuine owner turns mentioning slot A — all authorising, none forbidding. The rule was the
agent's own sentence**, and it had been quoting itself.

The same thing happened with "no permanent polling", which blocked the correct driver-owned
polling fix until the transcript was searched.

**Rule**: quote the owner's words, with a call number, or mark the constraint as your own
inference. A rule with no author is not a rule.

## 9. Debug output that hides the failure

- Without `printk.devkmsg=on`, init's module lines stop at **exactly 10 per 5 s**. Every capture
  showed 10 `init: Loading module` lines and looked like a hang.
- `CONFIG_CMDLINE="console=ttynull"` with `CMDLINE_EXTEND=y` put `ttynull` first, overriding the
  DT's `stdout-path`. **A healthy boot and a hang were indistinguishable by construction.**
- `console=ttymxc3` sits ahead of ramoops in the console list, so a stuck UART write wedges
  `console_flush_on_panic`. A dead console proves nothing about CPU state.
- `pstore` mounted ≠ functional: no `ramoops` DT node means no `/dev/pmsg0`.
- `tinyplay` exits **0** while printing `Error playing sample`. Check the SDMA IRQ delta.

## 10. The device is not the only thing that lies

- `dapm/bias_level` reads `Off` and regmap `06`/`0c` read `0000` **during normal working
  playback**.
- `CmaFree` is **not** the CMA free bitmap.
- `ERROR-ACTIVE` on `can0` with all-zero RX/TX counters proves nothing.
- `sys.usb.state` empty with `adbd` running is normal on this build.
- An empty watchdog class dir does not mean no watchdog.

---

## The habit

Every entry above was caught the same way: **by noticing the result had an impossible shape**,
not by the result announcing a problem.

So: when a measurement agrees with what you expected, that is the moment to check it a second
way. This project's worst errors were all *agreeable* results.
