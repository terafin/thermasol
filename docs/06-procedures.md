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

A read-only shower-controller probe (`net.siliconspirit.ttstatus`) can refresh all 17
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

In U-Boot, set the active slot back to A. One variable, no writes. Slot A was kept bootable
for exactly this.

---

## E. If ADB is gone but the panel is up

Order of attempts:

1. **SSH 8022** — independent of `adbd`. Use it to fix `adbd`.
2. Check for a Termux adb server holding the smarthocket:
   `ps -A | command grep 'adb -L tcp:5037'`. If present:
   `su 0 kill -9 <pid>` then `setprop ctl.restart adbd`.
3. IPv6 link-local ADB: `$A connect '[fe80::...%ens160]:5555'`.
4. UART.

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

1. Reinstall Termux + Termux:Boot (Aurora Store, or sideload the APKs).
2. Restore `~/.ssh/authorized_keys`; start `sshd` on 8022.
3. Reinstall the `00-restore-access` boot hook so `adbd`/`sshd` return after each boot.
4. **Do not** start a Termux adb *server* — it will race `adbd` and wedge it.
5. Re-verify section B.

Until step 3 is done, the panel has **no** recovery path once the wall is closed.
