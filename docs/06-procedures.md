# 06 — Procedures

Runbooks, in the order you would need them.

---

## A. Before you touch anything

```sh
A=adb
$A -P 5038 connect <panel-ip>:5555
$A -P 5038 -s <panel-ip>:5555 shell 'su 0 sh -c "
  cat /proc/sys/kernel/random/boot_id
  getprop ro.boot.slot_suffix
  getprop ro.boot.vbmeta.digest
  cat /sys/kernel/random/boot_id 2>/dev/null
  getprop sys.boot_completed
  test ! -e /metadata/tt/pending-deploy; echo no_pending_arm=\$?
  cat /data/local/tmp/tt-idle-dim.status | command grep -E \"state=|playback=\"
"'
```

Record the **boot UUID** and **slot** in your notes. Every gate below compares against a
*just-read* value, never a remembered one.

---

## B. Verify the panel is healthy (do this before and after any change)

| Check | Healthy value |
|---|---|
| Shower controller | `controller-keeper-status.json` → `"state": "connected"` |
| Controller errors | `psb_get_errors` = 0, `psb_get_state` = 255 (standby) |
| Touch | `getprop vendor.tt.touch_driver` = `success:tt_mxt_polled` |
| Audio gain | `tinymix -D 0 "Headphone Volume"` → `63 63` |
| Media volume | `cmd media_session volume --stream 3 --get` → raw 12 (`4/10`) |
| CAN errors | `cat /sys/class/net/can0/statistics/{tx,rx}_errors` → `0 0` |
| Ethernet | `cat /sys/class/net/eth0/carrier_changes` → 1 per boot, no errors |
| Idle | `tt-idle-dim.status` → `input_open=1` |
| Crash log | `logcat -b crash -d` — no fresh entries |

A read-only shower-controller probe (`net.example.ttstatus`) can refresh all 17
getters without changing hardware.

---

## C. Write an inactive slot (the only safe way to change firmware)

1. **Re-read** boot UUID, slot, and vbmeta digest. Abort if they differ from your record.
2. Confirm no pending deploy arm exists.
3. Confirm the target is the **inactive** slot.
4. Push the image; verify its SHA on the host **and** on the device.
5. `dd ... conv=notrunc,fsync` gated on `[ slot == expected ] && [ boot_id == expected ]`.
6. `blockdev --flushbufs` the partition.
7. Read the **whole partition** back and compare SHA.
8. Arm the trial.
9. Reboot.

On the new boot: run section B, then write the current-boot approval **and remove the arm
atomically**. A stale arm can promote an unproven image.

**Never** chain `boot` in vbmeta (see [04-android15-port.md](04-android15-port.md)).

---

## D. Roll back

**On this panel, "set the slot back to A" is not a working rollback.** Both slots hold
Android 15; stock A10 exists only as host-side backups, and when A10 was last booted here it
came up with no ethernet carrier at all (`eth_phy_pwr: disabling` at 3.554 s — the A10 overlay's
`regulator-eth-phy` lacks `regulator-always-on`/`boot-on`). That is a dark panel with no
network and no way in.

**The real rollback is to the previous A15 slot.**

1. Read which slot is running:

   ```sh
   adb shell getprop ro.boot.slot_suffix      # _a or _b
   ```

2. Read the A/B metadata from `misc` at `0x800` (32 bytes: magic `\0AB0`, version, then a
   CRC32 of the first 28 bytes stored big-endian at offset 28).
3. Confirm the **other** slot is the good A15 — not an unverified write, and not A10.
4. Only then switch.

**Before you switch, know how you get back.** A bad rollback on a sealed panel has no recovery
except UART (wall open) or the watchdog. See [04-android15-port.md](04-android15-port.md)
§"Rolling back".

**The switch itself has never been performed on this panel.** The wall is closed and the panel
works; nobody is going to run a deliberate slot-switch experiment on it. The other slot's image is
verified by hash only — not by booting it. Treat "roll back to the other slot" as a plan, not a
proven safety net.

The "one variable, no writes" rule is still correct when you set up a fresh port:
[09-install-from-stock.md](09-install-from-stock.md) keeps a slot untouched for exactly that.
It stopped being true here once both slots were converted.

---

## E. If ADB is gone but the panel is up

Order of attempts:

1. **SSH 8022** — independent of `adbd`. Use it to fix `adbd`.
2. **Check for `adb root` poisoning.** `adb root` sets `service.adb.root=1`, and on this build
   `adbd` then aborts on every start: nothing on 5555, `[init.svc.adbd]: [restarting]`. Fix it
   from SSH or Termux — **no root needed**:

   ```sh
   setprop service.adb.root ""
   setprop ctl.restart adbd
   ```

3. Check for a Termux adb server holding the smarthocket (a different failure, same symptom):
   `command ps -A | command grep 'adb -L tcp:5037'`. If present:
   `su 0 kill -9 <pid>` then `setprop ctl.restart adbd`.
4. IPv6 link-local ADB: `$A connect '[fe80::...%ens160]:5555'`.
5. UART.

`ro.init.updatable_crashing=1` means init has latched and stopped restarting `adbd` for this
boot. It clears on reboot — but only reboot if you have a second way back.

---

## F. If the panel is dark and unresponsive

- **First: do not suspend. Never suspend.** If someone did, the only recovery is the breaker.
- Try a soft restart from Ethernet if ADB/SSH answer.
- Otherwise: breaker for ~10 s. This is the only power control that exists.

---

## G. Patching a vendor APK (the technique used three times)

The vendor APKs are installed on `/data`, platform-signed, and can be safely re-signed with
the platform key already in the tree (`device/nxp/common/security/`).

1. **Pull the exact installed APK** and hash it. Do not work from a build directory — the
   installed file is frequently *not* the one you think it is.
2. Disassemble the relevant DEX with baksmali.
3. Change **one** thing.
4. Reassemble, rebuild the APK excluding `META-INF/`, `zipalign -p 4`, sign with
   `--v1/--v2/--v3`.
5. **Verify the scope**: re-disassemble the *candidate*, and assert that exactly the intended
   method(s) changed and every other class, method and resource is byte-identical.
6. Install with `install --no-incremental -r` (incremental install fails on this device).
7. Confirm the running process's `/proc/<pid>/exe` hash equals the new APK.

A write-up of one such patch is in [05-fixes.md](05-fixes.md) §6.

---

## H. Sending CAN frames safely

**Never guess opcodes at live hardware.** The rule, after breaking audio doing exactly that:

1. Record the current state.
2. Start a passive capture.
3. **Operate the vendor app's own UI control.**
4. Mirror the exact frames it emitted.

```sh
# passive capture
/data/local/tmp/passive_can 10
```

Frame shape is `A5 <opcode> 7B <payload>` on `0x131`. See
[03-hardware.md](03-hardware.md) for the verified table.

---

## I. Rebuilding the access stack after a flash

A system flash wipes `/data` and with it everything that makes the panel reachable. After
flashing:

1. Reinstall Termux + Termux:Boot — from the vendor store mirror
   ([11-vendor-store-mirror.md](11-vendor-store-mirror.md)) or sideload the APKs.
2. Restore `~/.ssh/authorized_keys`; start `sshd` on 8022.
3. Reinstall the boot hooks (below) so `adbd`/`sshd` return after each boot.
4. **Do not** start a Termux adb *server* — it races `adbd` and wedges it.
5. Re-verify section B.

Until step 3 is done, the panel has **no** recovery path once the wall is closed.

### I.1 Every supervised loop must escape adbd's cgroup

`adbd` runs in `cpuacct:/uid_0/pid_<adbd>`. **`init` SIGKILLs that entire cgroup when `adbd` is
stopped or restarted**, taking with it anything the hook tree spawned — including the `sshd`
the watchdog just restarted. A boot hook that does `ctl.restart adbd` therefore wipes the safety
net it was meant to protect.

Every long-lived process must self-escape at start:

```sh
echo $$ > /acct/cgroup.procs
```

Verify with `ctl.restart adbd` (adb returns in ~9 s) and `ctl.stop adbd` (the healer restarts it
in ~15 s), then confirm after a reboot that the loops are outside adbd's cgroup from boot.

### I.2 What each hook does

| Hook | Role |
|---|---|
| `00-restore-access` | brings `adbd` and `sshd` up at boot |
| `01-gapps` | GMS bring-up |
| `02-termux-wakelock` | keeps the panel awake while a session is expected |
| `40-panel-healer` | the watchdog supervisor — see the hazard below |
| `50-display-timeout-guard` | keeps the vendor app from forcing the screen back on |
| `52-vm-tuning` | memory paremeters |
| `55-config-snapshot` | records boot config; carries a tripwire on the `vbmeta_a` hash |
| `65-idle-shutdown` | idle policy |
| `70-sshd-watchdog` | supervises `sshd` and `50` |

Structure: `--bootstrap` (Termux uid) → `su 0 --start` → `--loop`. Supervision is **mutual** —
`65` restarts `40`, and `70` also supervises `50`. Two independent supervisors; an apparent
"second PID" is a pipeline subshell, not a duplicate.

**Reboot cap:** 3 per 6 hours, epochs recorded in a state file.

**Thrash rule:** refault rate > 20,000/s **and** io PSI `avg10` > 40 for 9 consecutive 20 s
windows → `am kill-all`, then reboot. A `test-thrash` switch file forces this for testing.

**Hazard — step 0 of `40-panel-healer` must not be removed.** It keeps
`/system/bin/watchdogd 10 50` alive. **An unpetted watchdog resets the panel about 60 s later.**

**Step 5b** re-enables owner apps every 20 s. This exists because an injected swipe landed on
ThermaSol's power control, which called `killExternalApps` and left apps like Netflix disabled.

---

## J. The bounded exception to "never write the running slot"

Section C and [10-known-pitfalls.md](10-known-pitfalls.md) say never write the running slot. The
repair that actually worked took a deliberate, bounded exception, and a future reader needs the
conditions rather than a rule that forbids the only thing that worked.

**Both must hold, or do not write:**

1. **The other slot is a known-good, bootable image.** Worst case is then a dark panel that can
   be switched back — not a brick.
2. **The AVB descriptor set is verified before writing** (five descriptors, `flags=0`, no
   `boot` chain).

With those, writing `dtbo`, `vbmeta` and `vendor` on a *non-running* slot while the other boots
is the normal path; writing the **running** slot is only ever justified when the change cannot
be staged — and the risk accepted is "dark panel, recoverable by slot switch."

**Never** bundle a running-slot write with anything else. One variable.

See issue [#23](https://github.com/terafin/thermasol/issues/23).

---

## K. First contact with a returned panel

After the panel has been out of reach, **one light probe and then stop**:

- `uptime`
- `/proc/sys/kernel/random/boot_id`
- `getprop ro.boot.bootreason`
- `getprop ro.boot.slot_suffix`
- `cat /proc/loadavg`
- five lines of `/proc/meminfo`
- `ip -br a show can0` and `eth0`
- the two service processes
- the watchdog state
- `misc` at `0x800`

`boot_id` equality is what distinguishes **"never rebooted, userspace died"** from **"it reset
itself"**. `ro.boot.bootreason` distinguishes a human power cycle from a watchdog reset.

**Single-operator discipline:** one driver with adb access at a time. Stop any host-side timer
helper (one existed that sent `input keyevent 4` + `am start` every 45 s) before any `dd`.

**Do not** follow a light probe with `dumpsys`, `logcat -d` or `ps -A` — see
[10-known-pitfalls.md](10-known-pitfalls.md).
