# touchsteam2: keep the HydroVive muted through shower shutdown

## The defect

Powering the panel off leaves the ceiling speaker **buzzing**, and silences it
only for about one second. The cause is in the installed UI app
(`com.thermasol.touchsteam2`), not in the daemon.

`Utils.ShutdownAll()` ends with `PersistPauseAndKillBluetooth()` →
`KillBluetooth()` → `toggleMusicAndSource()`, and that last call is a **start-up
action running inside a shutdown**: it mutes, then unmutes, then restores the
volume. Both the explicit unmute and the B6 volume frame unmute the ceiling unit
(the DSP's `0x173c` calls the mute primitive with 0 *before* writing gain).

Captured on 2026-11-06, id `0x131`:

```
55.679  A5 B5 7B 01   mute        <- ShutdownAll #1
55.921  A5 B5 7B 01   mute        <- ShutdownAll #2
56.142  A5 B5 7B 01   mute        <- toggleMusicAndSource
56.343  A5 B5 7B 00   UNMUTE      <- the buzz returns here
56.354  A5 B6 7B 8F   volume 15   <- and B6 unmutes again 11 ms later
```

First mute to unmute is 1.03 s, which is the dip the operator hears.

## The fix

A single flag, `OverheadLight.sShutdownMuted`:

* set at the top of `ShutdownAll()`
* checked in `OverheadLight.unmute()` and `OverheadLight.setMasterVolume()` —
  both become no-ops while it is set
* cleared at the top of `Utils.loadUserSettings()`, which is what a user tap on
  the user-select screen runs, so normal audio restoration is untouched
* `ShutdownAll()` mutes once more as its final statement

Guarding at the two send sites rather than only reordering matters: the volume
restore is **delayed** (`delayMusicVolume`), so a trailing mute alone could be
undone by a B6 that fires afterwards.

## What is not changed

Playback (the daemon's playback lease and `--playback-stdin`), the 300 s idle
timeout, `--dim 0`, shower/steam/light controls, and the WM8904 gain 63.

## Verification

`tests/test_shutdown_mute_model.py` replays the recovered call order with and
without the patch:

* baseline reproduces the capture exactly — 3 mutes, 1 unmute, B6 `0F`
* patched power-off: **no unmute, no B6, ends muted**, last frame is a mute
* patched resume: unmute/volume sent, ends audible, volume 15 restored
* an ordinary mute/unmute is unaffected
* three shutdown/resume cycles do not latch the flag

## Remaining uncertainty

The model is a faithful replay of the decompiled call order, not a run of the
app. Not yet verified on the panel; that needs a build, an install and a
power-off/listen cycle.
