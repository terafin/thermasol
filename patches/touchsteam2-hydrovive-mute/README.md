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

The chain is confirmed against the **installed** `classes2.dex` (the copy pulled
off the panel, not a recovery-tree copy): `ShutdownAll` calls `mute`, `mute`,
`PersistPauseAndKillBluetooth`, and `mute`; `PersistPauseAndKillBluetooth` calls
`KillBluetooth`; `KillBluetooth` calls `toggleMusicAndSource`; and
`toggleMusicAndSource` is the one that does `mute → unmute → delayMusicVolume`.

## The fix

Two static fields on `OverheadLight`, both written only by `Utils.ShutdownAll`:

| field        | meaning                                                        |
|--------------|----------------------------------------------------------------|
| `sInShutdown`| true **only** for the span of `PersistPauseAndKillBluetooth()` |
| `sAudioGen`  | bumped once per power-off; invalidates timers already queued   |

* `OverheadLight.unmute()` and `OverheadLight.setMasterVolume()` return early
  while `sInShutdown`.
* `Utils.delayMusicVolume()` does not spawn while `sInShutdown`, and stamps the
  thread it does spawn with the current `sAudioGen`.
* `lambda$delayMusicVolume$1` drops itself if `sAudioGen` moved while it slept.

Guarding at the two send sites rather than only reordering matters: the volume
restore is **delayed** (`delayMusicVolume`, up to 2 s), so a trailing mute alone
could be undone by a B6 that fires afterwards.

Nothing is latched. `sInShutdown` is false again as soon as the bluetooth
teardown returns, so the user's next audio action restores sound normally.

### Why not a flag cleared on resume (the rejected first design)

The first candidate used one `sShutdownMuted` flag, set by `ShutdownAll` and
cleared by `Utils.loadUserSettings()`. It silences the power-off, but it is
wrong for the panel:

`loadUserSettings` is reachable only from the two user-profile buttons in
`UserFragment` and from `handleExternalLogin` (dead: `EXTERNAL_LOGIN_KEY` is only
written by the MQTT service and was `-1`). It is **not** the resume path. The
real resume paths — `MusicController`, `MenusMgr`, the external-app launcher and
the external-app teardown — all go through `toggleMusicAndSource()`, and the
latch made every one of them silent. A user who powered off mid-shower and then
pressed play would have got nothing back until they opened the user screen.

`tests/test_shutdown_mute_model.py` keeps the latch in the model and asserts
that it strands audio on that path, so a regression back to it fails loudly.

## What is not changed

Playback (the daemon's playback lease and `--playback-stdin`), the 300 s idle
timeout, `--dim 0`, shower/steam/light controls, and the WM8904 gain 63.

## Verification

`tests/test_shutdown_mute_model.py` replays the recovered call order under three
implementations — the installed app, the rejected latch, and the shipped design:

* baseline reproduces the capture exactly — 3 mutes, 1 unmute, B6 `0F`
* shipped power-off: **no unmute, no B6, ends muted**, last frame is a mute
* shipped resume via `toggleMusicAndSource` (music controller) and via
  `loadUserSettings` (user select): both send the unmute and end audible
* an ordinary mute/unmute and an ordinary volume change are unaffected
* three shutdown/resume cycles do not latch

`tests/test_delayed_volume_race.py` covers the two timer windows: a timer
scheduled before power-off, and a timer woken while the panel is off.

## Starting a shower does not restore audio -- and why nothing is lost

Shower and steam start make no audio call at all. Checked in the installed dex:

* `DigitalShowerScreenFragment.handleTap` -> `esv_turn_on()` -- no audio call
* `SteamFragment.onSlide` -> `Utils.TurnOnSteam` -> `toggleSteam` +
  `resetLightSettings` -- no audio call
* `DateTimeFragment.onSlide` -> `login()` -- lock pattern only

That looks like a hole in "restore audio when the user starts it", but it is
not, because **no audio source survives a power-off**. `ShutdownAll` ends with
`PersistPauseAndKillBluetooth`, which persists bluetooth off, sends an AVRCP
pause and calls `KillBluetooth`; `KillBluetooth` takes the non-Android-BT
branch on this panel and calls `powerOffBluetooth`. After that there is nothing
playing to restore.

Every path that can re-establish a source unmutes:

| resume action | path |
|---|---|
| music button | `MusicController.hardwareStartBluetooth` -> `Utils.StartBluetooth` -> `toggleMusicAndSource(2)` |
| source change | `MusicController.hardwareSourceChange` -> `toggleMusicAndSource` |
| external app | `ExternalAppsScreenFragment` / app launch -> `toggleMusicAndSource` |
| guest button | `MenusMgr.handleGuestButton` -> `toggleMusicAndSource` |
| profile select | `loadUserSettings` -> `toggleMusicAndSource` |

So by the time a shower can have music, the user has already taken an action
that unmuted the unit. Starting the shower alone has nothing to restore.

Deliberately not unmuting on shower start: it would unmute with no source
playing and, since the unit buzzes whenever it is unmuted and idle, put the
buzz back for the whole shower.

Residual risk: a source path that does not go through `toggleMusicAndSource`
would stay silent. Every caller in the installed dex was enumerated; none does.

## Remaining uncertainty

The model is a faithful replay of the decompiled call order, not a run of the
app. Not yet verified on the panel; that needs an install and a
power-off/listen cycle.
