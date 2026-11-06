# Live test runbook — touchsteam2 v4

Everything below is a device action and needs the operator's explicit approval.
Nothing here has been executed.

## Artifacts

| | path | sha256 |
|---|---|---|
| candidate | `scratch/apkbuild/touchsteam2-patched-v4.apk` | `341e68be0ca6280f92a008d29e309dd90aa341e25aa83c43256ee5a4e0ee0bfe` |
| original (pulled from the panel) | `scratch/apkbuild/installed-base.apk` | `8ad27395b106aaf37ade580b374680338fbf8f40b5509b16b16db33652698a19` |

`scratch` = `/home/terafin/.local/state/issue-thermasol-vendor-a`. The candidate
is the installed APK with **only `classes2.dex` replaced**; the other 868 entries
are byte-identical, and both files carry signer `7fbae817…a4d6d804`.

## State of the panel right now

Do not read speaker state off the daemon counters. They record how many frames
the trial daemon sent, not what the unit is doing, and they are stale the moment
they are written.

What is known:

* `/vendor/bin/tt_idle_dim` currently has the HV build bind-mounted over it from
  `/data/local/tmp/tt_idle_dim_new` (`83e2bbe1…c1ef7`), and the service is running
* the last status read in this session reported `state=dim` with one mute
  outstanding — read at a specific time, and **not** a statement about the
  speaker now
* `com.thermasol.touchsteam2` is the stock 10.1.9

The speaker's actual state is unknown until observed, and the only observation
that counts is listening.

## Rollback — what it does and does not restore

There are three separate things, and they must not be conflated.

1. **The app package.** `pm install --no-incremental -r installed-base.apk`
   restores the original APK byte-for-byte. That is all it does.
2. **What it does not restore.** It does not un-send a mute. It does not revert
   preferences the patched app may have written (`musicVolumeUser*`,
   `musicSourceUser*`, `showerState`). If the unit was left muted, reinstalling
   the original APK leaves it muted — the original app does not push a mute
   state on launch either.
3. **The daemon rollback is itself a state change.** Stopping the trial daemon
   while it is in `dim` runs its restore path and sends one `B5 00`. That
   unmute is applied to the ceiling unit and is *not* undone by the APK rollback.

So after a full rollback the software is back to stock but the speaker may be
live; the only way to know is to observe it. Plan for that rather than assuming
either way.

## Step 0 — roll back the daemon (expect one unmute)

```
stop tt-idle-dim
umount /vendor/bin/tt_idle_dim
start tt-idle-dim
```
Expected: the child log shows `RESTORE 71` then `hv: panel restored -> B5 unmute
sent`, the backlight returns to 71, and the buzz returns. After restart the log
carries no `hv:` lines — the stock daemon has no B5 coupling.

This also removes the idle-mute half of the fix for the duration of the test.
Only the power-off half is under test below.

## Step 1 — install v4

```
adb push touchsteam2-patched-v4.apk /data/local/tmp/
adb shell su 0 sh -c "pm install --no-incremental -r /data/local/tmp/touchsteam2-patched-v4.apk"
```
Expect `Success`, then locate the installed package and hash it:

```
pm path com.thermasol.touchsteam2
sha256sum <path>/base.apk        # 341e68be…ee0bfe for the APK file
```
The install replaces `base.apk`; ART recompiles `classes2.dex`, so the first
launch is slow and the UI restarts.

## Step 2 — power off, from the idle screen (operator listens)

Start `tcpdump -i can0 -tttt -n` first, then press power off.

Expected on the bus: **three** `131#A5B57B01`, **no** `A5B57B00`, **no**
`A5B67B8F`.
Expected audibly: the buzz stops and **stays** stopped.

This is the only step that tests the shutdown suppression. If a `B5 00` or a
`B6` appears, the guard did not hold.

## Step 3 — start a shower from that muted state (operator listens)

Do this **before touching any music control**. Starting the shower turns on real
water/steam.

Expected on the bus: one `131#A5B57B00` (from `esv_turn_on`), and **no** `B6`.
Expected audibly: audio is live again — you can hear the unit.

This is the behaviour v4 adds. v3 had no unmute here and would stay silent, so
this step distinguishes the two candidates. If no `B5 00` appears, or the unit
stays dead, the session-start hook is wrong and the patch is not ready.

Judge the buzz by ear at this point. Audio live during a session means the unit
is out of mute; whether the idle hiss is audible over a running shower is your
call, and it is the known trade for restoring audio at session start.

## Step 4 — music control, tested separately (operator listens)

Now tap a music/source control.

Expected on the bus: `A5B57B00` plus an `A5B67B0F`-style volume frame.
Expected audibly: audio at the stored volume.

Kept separate from step 3 so a failure can be attributed: step 3 exercises
`esv_turn_on` only, step 4 exercises `toggleMusicAndSource`.

## Step 5 — power off again

Expected: three mutes again, no unmute, no `B6`. This checks the guards hold on
a second cycle rather than only the first after install.

## Step 6 — display-idle baseline (not the HV behaviour)

Leave the panel untouched past the 300 s timeout, then touch it.

With the stock daemon restored, expect **no** `B5` frame on dim or on wake — the
deployed daemon has no HV coupling. This step only establishes that baseline. The
HV daemon's idle mute/unmute is **not** under test here; it needs to be
re-staged, which is a separate approval.

## What is tested and what is only predicted

Tested by these steps: the installed code is the candidate; the power-off frame
list; the session-start frame; the music-resume frame; a second power-off cycle;
and the stock daemon's silence on dim.

Only predicted: that no unexamined path sends `B6` after power-off; that the
thread-timing guard behaves under real concurrency; that the added static fields
do not disturb Kotlin metadata at runtime; and that the ceiling unit actually
receives any of it — the protocol has no ACK.

## Rollback

```
pm install --no-incremental -r /data/local/tmp/installed-base.apk
```
Restores the package. See "Rollback — what it does and does not restore" above:
it does not undo mute state, preferences, or the daemon rollback's unmute.
