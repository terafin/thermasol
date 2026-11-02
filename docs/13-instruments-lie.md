# 13 — Gotchas: tools and traps that waste your time

What does not work, and what it looks like when it doesn't. Each entry is a mechanism, not a story.
Read this before trusting any empty result.

---

## Searches that find nothing

| Trap | What you see | Fix |
|---|---|---|
| `grep`/`find` are **shell functions** wrapping ugrep | `error: unknown option '-G'`, rc=1, or a silent zero; also honours `.gitignore` | `type grep`; use `command grep` |
| `grep` over a **raw EROFS image** | reports present services as missing — blocks are compressed | `fsck.erofs --extract`, or mount it |
| `grep` on a file containing a **NUL byte** | "binary file matches", then silent truncation at that byte | `grep -a` |
| **Wrong case in a symbol** | searching `MCP251XFD` when the config is `CAN_MCP251XFD` → "24 drivers missing" (real: 5) | search a short substring, then confirm |
| **Unanchored regex** | `allowxperm` matched by `allowx` → "1 match" where an anchored search gives 0 | anchor it |
| Matching `.ko` against a list of `.o` | "nothing shipped" when everything shipped | match like against like |

**Every zero needs a positive control.** Prove the same mechanism finds something you know exists
in the same file before believing "nothing there".

## Builds and gates that pass the wrong thing

- `./imx-make.sh … 2>&1 | tail -12` **hides a parse-time failure**. A pipeline's exit status is
  the last command's. `boot.img` gets rebuilt from a stale kernel and reports success.
- **`make bootimage` never reaches the kernel.** Only `imx-make.sh kernel` does.
- A gate can pass while reading a different directory than the file you are about to write. Hash
  the artifact you are writing, and compare it to the device after writing.
- `# CONFIG_X …` in a Kconfig fragment is a **directive, not a comment**. Writing one to explain a
  fix disables it.
- A `#` inside a backslash-continued make list silently truncates `modules.load` (70 entries → 2).
- A Kconfig symbol compiled out makes its sysfs class directory **empty**, which reads as "no
  driver". Check the process, not the directory.

Gates that fail when the thing is fine are equally bad — they teach you to ignore the gate.
Common causes: `strings | grep -q` under `pipefail`; `cmp` count units are **longs**; `cmp`
mismatch output matching no failure word.

## Config that is not what it says

| Assumption | Reality |
|---|---|
| `BOARD_KERNEL_CMDLINE` reaches the kernel | **inert** on this platform — the effective cmdline is `CONFIG_CMDLINE` plus U-Boot's `bootargs` |
| `setenv bootargs` then `reset` | `reset` reloads env from eMMC and **discards it**. Use `run bootcmd` |
| `/delete-node/` and `/delete-property/` in an overlay | **silently dropped** by the overlay compiler |
| `CONFIG_CMDLINE` is empty by default | `gki_defconfig` sets `console=ttynull` with `CMDLINE_EXTEND=y`, so it wins over the DT's `stdout-path` |
| `avbab` / `avbctl` / `set_active` exist on stock A10 | they do not. `set_active` is a fastboot protocol command |
| The AOSP `bootloader_control` struct describes this slot record | it does not. This panel uses libavb_ab `AvbABData` (`\0AB0`) |

## Probes that break the thing you are measuring

- `dumpsys SurfaceFlinger`, `dumpsys window`, `logcat -d`, `ps -A --sort=-RSS`, repeated
  `screencap`: each is followed within 50–70 s by load 19–22 and ~70 s of dead adb. Use single
  spaced reads and `/proc/pressure/memory`.
- `settings put system screen_brightness 102` kills `system_server` and drops the panel off the
  network.
- Raw MMIO on a runtime-suspended GPIO bank, or a weak **input pull-down** on `GPIO1_IO02`, resets
  the board.
- Pulling the presumed CHG pin low as a test causes a board reset.
- Two processes on the serial port: one fakes a read-back failure, the other produces ~45 minutes
  of phantom `0 bytes`.

## Output that hides the failure

- Without `printk.devkmsg=on`, init's module lines stop at **exactly 10 per 5 s**. It looks like a
  hang.
- `console=ttymxc3` precedes ramoops, so a stuck UART write wedges `console_flush_on_panic`. A dead
  console says nothing about the CPU.
- `pstore` mounted ≠ functional: no `ramoops` DT node means no `/dev/pmsg0`.
- `tinyplay` exits **0** while printing `Error playing sample`.
- `dapm/bias_level` reads `Off` and regmap `06`/`0c` read `0000` **during normal playback**.
- `CmaFree` is not the CMA free bitmap. A healthy boot shows it at 12 MB with zero allocation
  failures.
- `ERROR-ACTIVE` on `can0` with all-zero RX/TX counters proves nothing.
- Two boots concatenated in one capture — bound every capture by a known `boot_id`.

## Privilege and access

- `setprop ctl.start adbd` / `ctl.restart adbd` is received by init and **5555 stays closed**.
- `stop adbd` / `start adbd` from Termux: `must be root`.
- `sys.usb.config=adb` on A10 crash-loops adbd (signal 6).
- `adb push` / `adb pull` cannot create or read `/data/local/*` — adbd runs as shell. Write as root,
  read with `exec-out`.
- `su` takes a **uid** here: `su 0 sh -c '…'`, never `su 0 -c`.
- `su` inside Termux or an app context is Termux's own stub — every `su 0 …` there is dead.
- `am force-stop com.termux` puts Termux:Boot in the stopped state and suppresses `BOOT_COMPLETED`.
- A freshly installed Termux:Boot never runs until the package has been launched once.

## Things that look like a defect and are not

- An empty watchdog class directory with the driver bound and running.
- `sys.usb.state` empty while `adbd` runs normally.
- A `vbmeta` read-back "mismatch" when you hash the whole partition against a shorter file.
- `No ion heap of name reserved-uncached exists` is a **heap name** mismatch, not memory
  exhaustion.

---

## The rule

When a measurement agrees with what you expected, check it a second way. The expensive errors in
this project were all agreeable results.
