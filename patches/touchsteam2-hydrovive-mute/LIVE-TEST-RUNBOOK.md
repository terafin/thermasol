# Live test runbook — patched touchsteam2

Everything below is a device action and needs the operator's explicit approval.
State recorded 2026-11-06 before the run.

## Starting state (observed, not assumed)

* RAM-trial daemon is bind-mounted: mountinfo root `/local/tmp/tt_idle_dim_new`
  over `/vendor/bin/tt_idle_dim`
* `init.svc.tt-idle-dim` = running
* status: `state=dim`, `hv_mutes=6`, `hv_unmutes=5` → **one mute outstanding, so
  the ceiling unit is muted right now**
* gain `Headphone Volume 63 63`; backlight restore value 71, dim target 0

## Why roll back first

The trial daemon mutes on every display dim and unmutes on wake. If it is live
during the APK test, a buzz that stops cannot be attributed to the app patch —
the daemon could have done it. Worse, a clean `stop` while `state=dim` runs the
daemon's own shutdown path, which **unmutes** (`hv: panel restored -> B5 unmute
sent`). That is expected; it is not a failure.

## Step 0 — roll back the daemon (expect an unmute)

```
stop tt-idle-dim
umount /vendor/bin/tt_idle_dim
start tt-idle-dim
```
Expected: child log shows `RESTORE 71` then `hv: panel restored -> B5 unmute sent`
then `exiting`; the backlight returns to 71 and the buzz returns. After restart
the log carries **no** `hv:` lines (stock daemon has no B5 coupling).

## Step 1 — install the patched APK

```
adb push touchsteam2-patched-v3.apk /data/local/tmp/
adb shell su 0 sh -c "pm install --no-incremental -r /data/local/tmp/touchsteam2-patched-v3.apk"
```
Expect `Success`. A platform-key mismatch would fail with
`INSTALL_FAILED_UPDATE_INCOMPATIBLE` — the signer was verified to match.

Confirm the running package is the new one:
```
pm path com.thermasol.touchsteam2      # new base.apk path
sha256sum <that path>/base.apk         # 4096849d...a5f6c8
```

## Step 2 — power off (operator listens)

Start `tcpdump -i can0 -tttt -n` first, then press power-off.

Expect on the bus: **three** `131#A5B57B01` mutes and **no** `A5B57B00`,
**no** `A5B67B8F`.
Expect audibly: the buzz stops and **stays** stopped.

Failure signatures:
* `B5 00` present → the `unmute()` guard did not hold
* `B6` present → the `setMasterVolume` guard did not hold
* buzz returns ~1 s later → a path we have not found

## Step 3 — resume audio (operator listens)

Tap a music/source control (the path `MusicController` and `MenusMgr` take), or
start playback. Expect `B5 00` and a `B6` frame on the bus, and audio returns at
the stored volume.

Repeat with the user-profile screen if you want the second resume path covered
(`loadUserSettings`); both must restore audio. That is the cell the rejected
latch design failed.

## Rollback of the APK

Reinstall the pre-patch APK pulled from the device
`scratch/apkbuild/installed-base.apk` (sha256 `8ad27395b106aaf3…`):
```
pm install --no-incremental -r /data/local/tmp/installed-base.apk
```

## Superseded artifact

`touchsteam2-patched-v2.apk` must NOT be installed. It carries an earlier design
whose latch stranded audio on the music-resume path, and it additionally
compressed `resources.arsc` (targetSdk 30 requires it stored) and contained a
stray `work/classes2.dex` entry. v3 fixes all three; it is built by replacing
only the `classes2.dex` entry of the installed APK, so all 869 other entries are
byte-identical to what is on the panel.

## Step 4 covers only audio-shaped resumes

Step 3 tests a music control. Starting a shower or steam does not call
`unmute()`/`setMasterVolume()`, so the speaker stays muted on that path (see
README "Known gap"). If the operator wants that case changed, it is a separate
decision, not a failed test.

## What this runbook does NOT establish

Nothing here has been executed. The expected frame lists are predictions from
the decompiled source and the model tests, not observations.
